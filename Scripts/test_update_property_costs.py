from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "Scripts" / "update_property_costs.py"
SOURCES = ROOT / "Data" / "property-cost-sources.json"
NUMBEO_NAMES = {
    "chinaMainland": "China",
    "hongKong": "Hong Kong (China)",
    "unitedStates": "United States",
    "canada": "Canada",
    "singapore": "Singapore",
    "australia": "Australia",
    "japan": "Japan",
    "unitedKingdom": "United Kingdom",
    "germany": "Germany",
    "france": "France",
    "netherlands": "Netherlands",
    "spain": "Spain",
    "italy": "Italy",
    "switzerland": "Switzerland",
}


def load_generator():
    spec = importlib.util.spec_from_file_location("update_property_costs", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def sample_observation(rate: float, name: str) -> dict:
    return {
        "rate": rate,
        "periodLabel": "2026-06",
        "sourceName": name,
        "sourceUrl": "https://example.com/source",
    }


def sample_market() -> dict:
    return {
        country: {
            "mortgageRate": sample_observation(0.035, "Mortgage"),
            "rentGrowth": sample_observation(0.021, "Rent"),
            "appreciation": sample_observation(0.012, "Prices"),
        }
        for country in NUMBEO_NAMES
    }


def numbeo_html(
    ratios: dict[str, tuple[str, str]] | None = None,
    title: str = "Property Prices Index by Country 2026 Mid-Year",
) -> str:
    values = {
        country: ("20.0", "20.0")
        for country in NUMBEO_NAMES
    }
    values["hongKong"] = ("44.1", "40.6")
    if ratios:
        values.update(ratios)
    rows = []
    for country, (city, outside) in values.items():
        rows.append(
            "<tr>"
            f"<td class=\"cityOrCountryInIndicesTable\">{NUMBEO_NAMES[country]}</td>"
            f"<td>{city}</td><td>{outside}</td>"
            "</tr>"
        )
    body = "\n".join(rows)
    return f"""<!DOCTYPE html>
<html><head><title>{title}</title></head><body>
<table id="t2">
<thead><tr>
<th>Country</th>
<th>Price To Rent Ratio City Centre</th>
<th>Price To Rent Ratio Outside Of City Centre</th>
</tr></thead>
<tbody>
{body}
</tbody>
</table>
</body></html>
"""


class UpdatePropertyCostsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.generator = load_generator()

    def run_generator(
        self,
        source_data: dict,
        previous_data: dict | None = None,
        numbeo_page: str | None = None,
        market_data: dict | None = None,
    ) -> tuple[subprocess.CompletedProcess[str], Path, tempfile.TemporaryDirectory[str]]:
        temporary = tempfile.TemporaryDirectory()
        directory = Path(temporary.name)
        sources = directory / "sources.json"
        output = directory / "property-costs.json"
        previous = directory / "previous.json"
        spx_csv = directory / "spx.csv"
        numbeo = directory / "numbeo.html"
        market = directory / "market.json"
        sources.write_text(json.dumps(source_data), encoding="utf-8")
        spx_csv.write_text(
            "observation_date,SP500\n2016-10-28,2000\n2026-10-28,4000\n",
            encoding="utf-8",
        )
        numbeo.write_text(numbeo_page or numbeo_html(), encoding="utf-8")
        market.write_text(json.dumps(market_data or sample_market()), encoding="utf-8")
        if previous_data is not None:
            previous.write_text(json.dumps(previous_data), encoding="utf-8")

        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--sources",
                str(sources),
                "--output",
                str(output),
                "--latest",
                str(directory / "latest.json"),
                "--history-dir",
                str(directory / "history"),
                "--previous",
                str(previous),
                "--spx-csv",
                str(spx_csv),
                "--numbeo-html",
                str(numbeo),
                "--market-json",
                str(market),
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        return result, output, temporary

    def test_generates_all_countries(self) -> None:
        source_data = json.loads(SOURCES.read_text(encoding="utf-8"))
        result, output, temporary = self.run_generator(source_data)
        self.addCleanup(temporary.cleanup)

        self.assertEqual(result.returncode, 0, result.stderr)
        catalog = json.loads(output.read_text(encoding="utf-8"))
        self.assertEqual(catalog["schemaVersion"], 1)
        self.assertEqual(len(catalog["countries"]), 14)
        self.assertEqual(len(catalog["contentDigest"]), 64)
        days = (date(2026, 10, 28) - date(2016, 10, 28)).days
        expected_rate = round(2 ** (365.25 / days) - 1, 4)
        investment = catalog["investmentReturn"]
        self.assertEqual(investment["method"], "spxPriceCagr10Y")
        self.assertEqual(investment["rate"], expected_rate)
        self.assertEqual(investment["startLevel"], 2000)
        self.assertEqual(investment["endLevel"], 4000)
        self.assertTrue(investment["sourceUrl"].startswith("https://"))
        price_to_rent = catalog["priceToRent"]
        self.assertEqual(price_to_rent["sourceName"], "Numbeo")
        self.assertEqual(
            price_to_rent["sourceUrl"],
            "https://www.numbeo.com/property-investment/rankings_by_country.jsp",
        )
        self.assertEqual(price_to_rent["periodLabel"], "2026 Mid-Year")
        self.assertEqual(set(price_to_rent["years"]), set(NUMBEO_NAMES))
        self.assertAlmostEqual(price_to_rent["years"]["hongKong"], 42.4, places=1)
        self.assertAlmostEqual(price_to_rent["years"]["unitedStates"], 20.0, places=1)
        canada = catalog["countries"]["canada"]
        self.assertEqual(canada["mortgageRate"]["sourceName"], "Mortgage")
        self.assertEqual(canada["rentGrowth"]["rate"], 0.021)
        self.assertEqual(canada["appreciation"]["periodLabel"], "2026-06")
        self.assertEqual(canada["sources"][0]["name"], source_data["countries"]["canada"]["sources"][0]["name"])

    def test_rejects_missing_country(self) -> None:
        source_data = json.loads(SOURCES.read_text(encoding="utf-8"))
        del source_data["countries"]["italy"]
        result, _, temporary = self.run_generator(source_data)
        self.addCleanup(temporary.cleanup)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("country coverage mismatch", result.stderr)

    def test_rejects_large_unreviewed_delta(self) -> None:
        source_data = json.loads(SOURCES.read_text(encoding="utf-8"))
        initial_result, initial_output, first_temporary = self.run_generator(source_data)
        self.addCleanup(first_temporary.cleanup)
        self.assertEqual(initial_result.returncode, 0, initial_result.stderr)
        previous = json.loads(initial_output.read_text(encoding="utf-8"))

        source_data["countries"]["canada"]["buyingCostRate"] = 0.3
        result, _, second_temporary = self.run_generator(source_data, previous)
        self.addCleanup(second_temporary.cleanup)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("manual review threshold", result.stderr)

    def test_averages_city_and_outside_and_maps_hong_kong(self) -> None:
        parsed = self.generator.parse_numbeo_rankings(
            numbeo_html(),
            fetched_on=date(2026, 10, 31),
        )
        self.assertAlmostEqual(parsed["years"]["hongKong"], 42.4, places=1)
        self.assertEqual(parsed["periodLabel"], "2026 Mid-Year")

    def test_period_falls_back_to_fetch_month(self) -> None:
        parsed = self.generator.parse_numbeo_rankings(
            numbeo_html(title="Property Prices Index by Country"),
            fetched_on=date(2026, 10, 31),
        )
        self.assertEqual(parsed["periodLabel"], "2026-10")

    def test_rejects_missing_numbeo_country(self) -> None:
        page = numbeo_html()
        page = page.replace(
            "<td class=\"cityOrCountryInIndicesTable\">Italy</td><td>20.0</td><td>20.0</td>",
            "",
        )
        source_data = json.loads(SOURCES.read_text(encoding="utf-8"))
        result, _, temporary = self.run_generator(source_data, numbeo_page=page)
        self.addCleanup(temporary.cleanup)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Numbeo country coverage mismatch", result.stderr)
        self.assertIn("italy", result.stderr)

    def test_rejects_out_of_range_price_to_rent(self) -> None:
        source_data = json.loads(SOURCES.read_text(encoding="utf-8"))
        result, _, temporary = self.run_generator(
            source_data,
            numbeo_page=numbeo_html({"switzerland": ("100.0", "100.0")}),
        )
        self.addCleanup(temporary.cleanup)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("outside 5...80", result.stderr)

    def test_rejects_non_numeric_price_to_rent(self) -> None:
        source_data = json.loads(SOURCES.read_text(encoding="utf-8"))
        result, _, temporary = self.run_generator(
            source_data,
            numbeo_page=numbeo_html({"japan": ("n/a", "20.0")}),
        )
        self.addCleanup(temporary.cleanup)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("is not a number", result.stderr)

    def test_rejects_price_to_rent_jump_only_when_previous_has_field(self) -> None:
        source_data = json.loads(SOURCES.read_text(encoding="utf-8"))
        initial, output, first = self.run_generator(source_data)
        self.addCleanup(first.cleanup)
        self.assertEqual(initial.returncode, 0, initial.stderr)
        previous = json.loads(output.read_text(encoding="utf-8"))
        del previous["priceToRent"]

        jumped = numbeo_html({"unitedStates": ("40.0", "40.0")})
        without_field, _, second = self.run_generator(
            source_data,
            previous_data=previous,
            numbeo_page=jumped,
        )
        self.addCleanup(second.cleanup)
        self.assertEqual(without_field.returncode, 0, without_field.stderr)

        with_field, _, third = self.run_generator(
            source_data,
            previous_data=json.loads(output.read_text(encoding="utf-8")),
            numbeo_page=jumped,
        )
        self.addCleanup(third.cleanup)
        self.assertNotEqual(with_field.returncode, 0)
        self.assertIn("price-to-rent changed by", with_field.stderr)
        self.assertIn("manual review threshold is 15", with_field.stderr)

    def test_keeps_previous_market_series_when_one_fetch_is_missing(self) -> None:
        source_data = json.loads(SOURCES.read_text(encoding="utf-8"))
        initial, output, first = self.run_generator(source_data)
        self.addCleanup(first.cleanup)
        self.assertEqual(initial.returncode, 0, initial.stderr)
        previous = json.loads(output.read_text(encoding="utf-8"))
        market = sample_market()
        del market["italy"]["mortgageRate"]
        result, regenerated, second = self.run_generator(
            source_data,
            previous_data=previous,
            market_data=market,
        )
        self.addCleanup(second.cleanup)
        self.assertEqual(result.returncode, 0, result.stderr)
        catalog = json.loads(regenerated.read_text(encoding="utf-8"))
        self.assertEqual(catalog["countries"]["italy"]["mortgageRate"]["rate"], 0.035)

    def test_rejects_market_series_without_previous_value(self) -> None:
        source_data = json.loads(SOURCES.read_text(encoding="utf-8"))
        market = sample_market()
        del market["japan"]["appreciation"]
        result, _, temporary = self.run_generator(source_data, market_data=market)
        self.addCleanup(temporary.cleanup)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("previous catalog has no value", result.stderr)

    def test_rejects_large_mortgage_rate_jump(self) -> None:
        source_data = json.loads(SOURCES.read_text(encoding="utf-8"))
        initial, output, first = self.run_generator(source_data)
        self.addCleanup(first.cleanup)
        self.assertEqual(initial.returncode, 0, initial.stderr)
        market = sample_market()
        market["unitedStates"]["mortgageRate"]["rate"] = 0.06
        result, _, second = self.run_generator(
            source_data,
            previous_data=json.loads(output.read_text(encoding="utf-8")),
            market_data=market,
        )
        self.addCleanup(second.cleanup)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("mortgageRate changed by", result.stderr)
        self.assertIn("manual review threshold is 0.0200", result.stderr)


if __name__ == "__main__":
    unittest.main()
