#!/usr/bin/env python3
"""Export/import curated housing defaults between Excel and property-cost-sources.json."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from openpyxl import Workbook, load_workbook

EXPECTED_COUNTRIES = {
    "unitedStates",
    "chinaMainland",
    "germany",
    "japan",
    "india",
    "unitedKingdom",
    "france",
    "italy",
    "russia",
    "canada",
    "brazil",
    "mexico",
    "southKorea",
    "spain",
    "australia",
    "netherlands",
    "saudiArabia",
    "turkey",
    "indonesia",
    "switzerland",
}

HOUSING_TYPES = ("apartment", "townhouse", "detached")

# Excel percent columns map to JSON fraction fields.
PERCENT_FIELDS = {
    "propertyTaxPercent": "propertyTaxRate",
    "buyingCostPercent": "buyingCostRate",
    "sellingCostPercent": "sellingCostRate",
    "pmiPercent": "pmiRate",
    "maintenancePercent": "maintenanceRate",
    "insurancePercent": "insuranceRate",
}

RATE_BOUNDS = {
    "propertyTaxRate": (0.0, 0.06),
    "buyingCostRate": (0.0, 0.80),
    "sellingCostRate": (0.0, 0.30),
    "pmiRate": (0.0, 0.05),
    "maintenanceRate": (0.0, 0.05),
    "insuranceRate": (0.0, 0.05),
}

PRICE_TO_RENT_BOUNDS = (5.0, 80.0)
LOAN_YEARS_BOUNDS = (5, 40)

COLUMNS = (
    "country",
    "apartmentHomePrice",
    "apartmentMonthlyHOA",
    "townhouseHomePrice",
    "townhouseMonthlyHOA",
    "detachedHomePrice",
    "detachedMonthlyHOA",
    "propertyTaxPercent",
    "buyingCostPercent",
    "sellingCostPercent",
    "priceToRentYears",
    "loanYears",
    "pmiPercent",
    "maintenancePercent",
    "insurancePercent",
)

README_ROWS = (
    ("column", "meaning", "unit"),
    ("country", "JSON country key; do not rename", "text"),
    ("*HomePrice", "Local-currency mid-market home price by dwelling type", "local currency"),
    ("*MonthlyHOA", "Monthly service charge / HOA by dwelling type", "local currency / month"),
    ("propertyTaxPercent", "Effective property tax on market value", "percent, e.g. 1.5 = 1.5%"),
    ("buyingCostPercent", "Buying transaction costs", "percent"),
    ("sellingCostPercent", "Selling transaction costs", "percent"),
    ("priceToRentYears", "Price-to-rent years", "years"),
    ("loanYears", "Default mortgage term", "years"),
    ("pmiPercent", "Mortgage insurance annual rate", "percent"),
    ("maintenancePercent", "Maintenance baseline annual rate", "percent"),
    ("insurancePercent", "Home insurance baseline annual rate", "percent"),
    ("", "", ""),
    ("workflow", "Edit defaults sheet → run import → commit/push sources JSON", ""),
    ("export", "python3 Scripts/sync_housing_defaults_xlsx.py export", ""),
    ("import", "python3 Scripts/sync_housing_defaults_xlsx.py import", ""),
)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sync curated housing defaults between Excel and property-cost-sources.json."
    )
    parser.add_argument("command", choices=("export", "import"))
    parser.add_argument(
        "--sources",
        type=Path,
        default=Path("Data/property-cost-sources.json"),
    )
    parser.add_argument(
        "--xlsx",
        type=Path,
        default=Path("Data/housing-defaults/housing-defaults.xlsx"),
    )
    return parser.parse_args(argv)


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=False) + "\n",
        encoding="utf-8",
    )


def _require_number(value: Any, label: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{label} must be a number")
    return float(value)


def country_to_row(country: str, record: dict[str, Any]) -> dict[str, Any]:
    housing = record["housingDefaults"]
    row: dict[str, Any] = {"country": country}
    for housing_type in HOUSING_TYPES:
        defaults = housing[housing_type]
        row[f"{housing_type}HomePrice"] = float(defaults["homePrice"])
        row[f"{housing_type}MonthlyHOA"] = float(defaults["monthlyHOA"])
    for percent_col, rate_field in PERCENT_FIELDS.items():
        row[percent_col] = round(float(record[rate_field]) * 100.0, 6)
    row["priceToRentYears"] = float(record["priceToRentYears"])
    row["loanYears"] = int(record["loanYears"])
    return row


def row_to_updates(row: dict[str, Any]) -> dict[str, Any]:
    country = row.get("country")
    if not isinstance(country, str) or not country:
        raise ValueError("each row needs a country key")

    housing: dict[str, Any] = {}
    for housing_type in HOUSING_TYPES:
        price = _require_number(row.get(f"{housing_type}HomePrice"), f"{country}.{housing_type}.homePrice")
        hoa = _require_number(row.get(f"{housing_type}MonthlyHOA"), f"{country}.{housing_type}.monthlyHOA")
        if price <= 0:
            raise ValueError(f"{country}.housingDefaults.{housing_type}.homePrice must be > 0")
        if hoa < 0:
            raise ValueError(f"{country}.housingDefaults.{housing_type}.monthlyHOA must be >= 0")
        housing[housing_type] = {"homePrice": price, "monthlyHOA": hoa}

    updates: dict[str, Any] = {"housingDefaults": housing}
    for percent_col, rate_field in PERCENT_FIELDS.items():
        percent = _require_number(row.get(percent_col), f"{country}.{percent_col}")
        rate = percent / 100.0
        minimum, maximum = RATE_BOUNDS[rate_field]
        if not minimum <= rate <= maximum:
            raise ValueError(f"{country}.{rate_field} is outside {minimum}...{maximum}")
        updates[rate_field] = round(rate, 10)

    years = _require_number(row.get("priceToRentYears"), f"{country}.priceToRentYears")
    minimum_years, maximum_years = PRICE_TO_RENT_BOUNDS
    if not minimum_years <= years <= maximum_years:
        raise ValueError(
            f"{country}.priceToRentYears is outside {minimum_years}...{maximum_years}"
        )
    updates["priceToRentYears"] = years

    loan_raw = row.get("loanYears")
    loan_years = int(_require_number(loan_raw, f"{country}.loanYears"))
    if float(loan_raw) != float(loan_years):
        raise ValueError(f"{country}.loanYears must be an integer")
    minimum_loan, maximum_loan = LOAN_YEARS_BOUNDS
    if not minimum_loan <= loan_years <= maximum_loan:
        raise ValueError(f"{country}.loanYears is outside {minimum_loan}...{maximum_loan}")
    updates["loanYears"] = loan_years
    return updates


def export_xlsx(sources: dict[str, Any], xlsx_path: Path) -> None:
    countries = sources.get("countries")
    if not isinstance(countries, dict):
        raise ValueError("sources.countries must be an object")
    keys = set(countries)
    if keys != EXPECTED_COUNTRIES:
        raise ValueError(
            f"country coverage mismatch; missing={sorted(EXPECTED_COUNTRIES - keys)}, "
            f"unexpected={sorted(keys - EXPECTED_COUNTRIES)}"
        )

    workbook = Workbook()
    defaults = workbook.active
    defaults.title = "defaults"
    defaults.append(list(COLUMNS))
    for country in sorted(EXPECTED_COUNTRIES):
        row = country_to_row(country, countries[country])
        defaults.append([row[column] for column in COLUMNS])

    readme = workbook.create_sheet("readme")
    for entry in README_ROWS:
        readme.append(list(entry))

    xlsx_path.parent.mkdir(parents=True, exist_ok=True)
    workbook.save(xlsx_path)


def read_defaults_sheet(xlsx_path: Path) -> list[dict[str, Any]]:
    workbook = load_workbook(xlsx_path, data_only=True)
    if "defaults" not in workbook.sheetnames:
        raise ValueError(f"{xlsx_path} is missing a defaults sheet")
    sheet = workbook["defaults"]
    rows = list(sheet.iter_rows(values_only=True))
    if not rows:
        raise ValueError("defaults sheet is empty")
    header = [str(cell).strip() if cell is not None else "" for cell in rows[0]]
    if tuple(header) != COLUMNS:
        raise ValueError(
            "defaults header mismatch; expected "
            + ", ".join(COLUMNS)
            + f"; got {', '.join(header)}"
        )

    result: list[dict[str, Any]] = []
    for index, values in enumerate(rows[1:], start=2):
        if values is None or all(cell is None or cell == "" for cell in values):
            continue
        if len(values) < len(COLUMNS):
            values = tuple(list(values) + [None] * (len(COLUMNS) - len(values)))
        row = {column: values[offset] for offset, column in enumerate(COLUMNS)}
        if not isinstance(row["country"], str) or not row["country"].strip():
            raise ValueError(f"defaults row {index} is missing country")
        row["country"] = row["country"].strip()
        result.append(row)
    return result


def import_xlsx(sources: dict[str, Any], xlsx_path: Path) -> dict[str, Any]:
    countries = sources.get("countries")
    if not isinstance(countries, dict):
        raise ValueError("sources.countries must be an object")

    rows = read_defaults_sheet(xlsx_path)
    seen = {row["country"] for row in rows}
    if seen != EXPECTED_COUNTRIES:
        raise ValueError(
            f"Excel country coverage mismatch; missing={sorted(EXPECTED_COUNTRIES - seen)}, "
            f"unexpected={sorted(seen - EXPECTED_COUNTRIES)}"
        )

    for row in rows:
        country = row["country"]
        if country not in countries or not isinstance(countries[country], dict):
            raise ValueError(f"{country} is missing from sources JSON")
        updates = row_to_updates(row)
        record = countries[country]
        record["housingDefaults"] = updates["housingDefaults"]
        for field in (
            "propertyTaxRate",
            "buyingCostRate",
            "sellingCostRate",
            "priceToRentYears",
            "loanYears",
            "pmiRate",
            "maintenanceRate",
            "insuranceRate",
        ):
            record[field] = updates[field]
        # Preserve sources / verifiedAt / any other keys untouched.
    return sources


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        sources = load_json(args.sources)
        if args.command == "export":
            export_xlsx(sources, args.xlsx)
            print(f"wrote {args.xlsx}")
        else:
            updated = import_xlsx(sources, args.xlsx)
            write_json(args.sources, updated)
            print(f"updated {args.sources} from {args.xlsx}")
        return 0
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
