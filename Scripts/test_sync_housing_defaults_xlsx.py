#!/usr/bin/env python3
"""Tests for housing-defaults Excel sync."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import sync_housing_defaults_xlsx as sync


def minimal_sources() -> dict:
    countries = {}
    for country in sorted(sync.EXPECTED_COUNTRIES):
        countries[country] = {
            "propertyTaxRate": 0.01,
            "buyingCostRate": 0.03,
            "sellingCostRate": 0.04,
            "priceToRentYears": 20,
            "verifiedAt": "2026-09-30",
            "sources": [{"name": "Example", "url": "https://example.com"}],
            "loanYears": 30,
            "pmiRate": 0.0,
            "maintenanceRate": 0.01,
            "insuranceRate": 0.005,
            "housingDefaults": {
                "apartment": {"homePrice": 100_000.0, "monthlyHOA": 50.0},
                "townhouse": {"homePrice": 120_000.0, "monthlyHOA": 20.0},
                "detached": {"homePrice": 150_000.0, "monthlyHOA": 0.0},
            },
        }
    countries["unitedStates"]["pmiRate"] = 0.005
    countries["unitedStates"]["housingDefaults"]["apartment"] = {
        "homePrice": 325_000.0,
        "monthlyHOA": 330.0,
    }
    return {
        "schemaVersion": 1,
        "methodology": "Test methodology for housing defaults spreadsheet sync.",
        "countries": countries,
    }


class SyncHousingDefaultsXlsxTests(unittest.TestCase):
    def test_export_import_roundtrip_preserves_sources(self) -> None:
        sources = minimal_sources()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            sources_path = root / "sources.json"
            xlsx_path = root / "housing-defaults.xlsx"
            sync.write_json(sources_path, sources)
            sync.export_xlsx(sources, xlsx_path)

            # Mutate one value in Excel through import path after editing JSON-equivalent row.
            rows = sync.read_defaults_sheet(xlsx_path)
            us = next(row for row in rows if row["country"] == "unitedStates")
            self.assertEqual(us["apartmentHomePrice"], 325_000)
            self.assertEqual(us["pmiPercent"], 0.5)
            self.assertEqual(us["propertyTaxPercent"], 1.0)

            # Direct import after export should preserve curated numbers and source metadata.
            updated = sync.import_xlsx(sources, xlsx_path)
            self.assertEqual(
                updated["countries"]["unitedStates"]["sources"],
                [{"name": "Example", "url": "https://example.com"}],
            )
            self.assertEqual(updated["countries"]["unitedStates"]["verifiedAt"], "2026-09-30")
            self.assertEqual(updated["methodology"], sources["methodology"])
            self.assertEqual(updated["countries"]["unitedStates"]["pmiRate"], 0.005)
            self.assertEqual(
                updated["countries"]["unitedStates"]["housingDefaults"]["apartment"]["homePrice"],
                325_000.0,
            )

    def test_import_applies_excel_edits(self) -> None:
        sources = minimal_sources()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            xlsx_path = root / "housing-defaults.xlsx"
            sync.export_xlsx(sources, xlsx_path)

            from openpyxl import load_workbook

            workbook = load_workbook(xlsx_path)
            sheet = workbook["defaults"]
            header = [cell.value for cell in sheet[1]]
            price_col = header.index("apartmentHomePrice") + 1
            tax_col = header.index("propertyTaxPercent") + 1
            country_col = header.index("country") + 1
            for row_index in range(2, sheet.max_row + 1):
                if sheet.cell(row_index, country_col).value == "unitedStates":
                    sheet.cell(row_index, price_col).value = 400_000
                    sheet.cell(row_index, tax_col).value = 1.25
                    break
            workbook.save(xlsx_path)

            updated = sync.import_xlsx(sources, xlsx_path)
            us = updated["countries"]["unitedStates"]
            self.assertEqual(us["housingDefaults"]["apartment"]["homePrice"], 400_000)
            self.assertEqual(us["propertyTaxRate"], 0.0125)
            self.assertEqual(us["sources"][0]["name"], "Example")

    def test_rejects_missing_country(self) -> None:
        sources = minimal_sources()
        with tempfile.TemporaryDirectory() as directory:
            xlsx_path = Path(directory) / "housing-defaults.xlsx"
            sync.export_xlsx(sources, xlsx_path)
            from openpyxl import load_workbook

            workbook = load_workbook(xlsx_path)
            sheet = workbook["defaults"]
            sheet.delete_rows(2)
            workbook.save(xlsx_path)
            with self.assertRaises(ValueError):
                sync.import_xlsx(sources, xlsx_path)

    def test_cli_export_and_import(self) -> None:
        sources = minimal_sources()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            sources_path = root / "sources.json"
            xlsx_path = root / "housing-defaults.xlsx"
            sync.write_json(sources_path, sources)
            self.assertEqual(
                sync.main(
                    [
                        "export",
                        "--sources",
                        str(sources_path),
                        "--xlsx",
                        str(xlsx_path),
                    ]
                ),
                0,
            )
            self.assertTrue(xlsx_path.exists())
            self.assertEqual(
                sync.main(
                    [
                        "import",
                        "--sources",
                        str(sources_path),
                        "--xlsx",
                        str(xlsx_path),
                    ]
                ),
                0,
            )
            loaded = json.loads(sources_path.read_text(encoding="utf-8"))
            self.assertEqual(loaded["countries"]["canada"]["loanYears"], 30)


if __name__ == "__main__":
    unittest.main()
