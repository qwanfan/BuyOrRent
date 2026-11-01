#!/usr/bin/env python3
"""Build and validate the public owner-occupied property-cost catalog."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any

_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))
import equity_index_returns
import market_series

EXPECTED_COUNTRIES = {
    "chinaMainland",
    "hongKong",
    "unitedStates",
    "canada",
    "singapore",
    "australia",
    "japan",
    "unitedKingdom",
    "germany",
    "france",
    "netherlands",
    "spain",
    "italy",
    "switzerland",
}

RATE_BOUNDS = {
    "propertyTaxRate": (0.0, 0.06),
    "buyingCostRate": (0.0, 0.80),
    "sellingCostRate": (0.0, 0.30),
}

MAX_DELTAS = {
    "propertyTaxRate": 0.01,
    "buyingCostRate": 0.10,
    "sellingCostRate": 0.10,
}

REVIEW_DAYS = 31
PRICE_TO_RENT_BOUNDS = (5.0, 80.0)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--sources",
        type=Path,
        default=Path("Data/property-cost-sources.json"),
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("public/v1/property-costs.json"),
    )
    parser.add_argument(
        "--previous",
        type=Path,
        default=Path("public/v1/property-costs.json"),
    )
    parser.add_argument(
        "--history-dir",
        type=Path,
        default=Path("public/v1/history"),
    )
    parser.add_argument(
        "--latest",
        type=Path,
        default=Path("public/v1/latest.json"),
    )
    parser.add_argument(
        "--check-urls",
        action="store_true",
        help="Require every official source URL to answer successfully.",
    )
    parser.add_argument(
        "--market-json",
        type=Path,
        help="Use a local mortgage, rent-growth, and appreciation JSON instead of downloading.",
    )
    parser.add_argument(
        "--equity-output",
        type=Path,
        default=Path("public/v1/equity-index-returns.json"),
        help="Where to write the equity-index return catalog.",
    )
    parser.add_argument(
        "--equity-previous",
        type=Path,
        default=Path("public/v1/equity-index-returns.json"),
        help="Previous equity-index catalog used when a Yahoo fetch fails.",
    )
    parser.add_argument(
        "--equity-json",
        type=Path,
        help="Use a local equity-index JSON instead of downloading Yahoo charts.",
    )
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def validate_sources(document: dict[str, Any]) -> None:
    if document.get("schemaVersion") != 1:
        raise ValueError("source schemaVersion must be 1")
    methodology = document.get("methodology")
    if not isinstance(methodology, str) or len(methodology) < 20:
        raise ValueError("methodology is missing")

    countries = document.get("countries")
    if not isinstance(countries, dict):
        raise ValueError("countries must be an object")
    keys = set(countries)
    if keys != EXPECTED_COUNTRIES:
        raise ValueError(
            f"country coverage mismatch; missing={sorted(EXPECTED_COUNTRIES - keys)}, "
            f"unexpected={sorted(keys - EXPECTED_COUNTRIES)}"
        )

    today = date.today()
    for country, record in countries.items():
        if not isinstance(record, dict):
            raise ValueError(f"{country} must be an object")
        for field, (minimum, maximum) in RATE_BOUNDS.items():
            value = record.get(field)
            if not isinstance(value, (int, float)) or isinstance(value, bool):
                raise ValueError(f"{country}.{field} must be a number")
            if not minimum <= float(value) <= maximum:
                raise ValueError(f"{country}.{field} is outside {minimum}...{maximum}")

        years = record.get("priceToRentYears")
        if not isinstance(years, (int, float)) or isinstance(years, bool):
            raise ValueError(f"{country}.priceToRentYears must be a number")
        minimum_years, maximum_years = PRICE_TO_RENT_BOUNDS
        if not minimum_years <= float(years) <= maximum_years:
            raise ValueError(
                f"{country}.priceToRentYears is outside {minimum_years}...{maximum_years}"
            )

        verified_at = date.fromisoformat(record["verifiedAt"])
        if verified_at > today + timedelta(days=1):
            raise ValueError(f"{country}.verifiedAt is in the future")

        sources = record.get("sources")
        if not isinstance(sources, list) or not sources:
            raise ValueError(f"{country}.sources must not be empty")
        for source in sources:
            if not isinstance(source, dict) or not source.get("name"):
                raise ValueError(f"{country} has an invalid source")
            url = source.get("url")
            if not isinstance(url, str) or not url.startswith("https://"):
                raise ValueError(f"{country} source must use HTTPS: {url}")


def source_urls(document: dict[str, Any]) -> list[str]:
    return sorted(
        {
            source["url"]
            for record in document["countries"].values()
            for source in record["sources"]
            if source.get("availabilityCheck", True)
        }
    )


def check_url(url: str) -> None:
    result = subprocess.run(
        [
            "curl",
            "--location",
            "--retry",
            "2",
            "--max-time",
            "30",
            "--silent",
            "--show-error",
            "--output",
            "/dev/null",
            "--write-out",
            "%{http_code}",
            "--user-agent",
            "BuyOrRentDataBot/1.0 (+https://github.com/qwanfan/BuyOrRent)",
            url,
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    try:
        status = int(result.stdout[-3:])
    except ValueError as error:
        raise ValueError(f"source unavailable: {url}: {result.stderr.strip()}") from error
    if not 200 <= status < 500:
        raise ValueError(f"source unavailable: {url}: HTTP {status}")


def comparable_payload(document: dict[str, Any]) -> dict[str, Any]:
    return {
        "methodology": document["methodology"],
        "countries": public_countries(document["countries"]),
    }


def payload_digest(document: dict[str, Any]) -> str:
    encoded = json.dumps(
        comparable_payload(document),
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def validate_delta(
    previous: dict[str, Any] | None,
    current_sources: dict[str, Any],
) -> None:
    if not previous:
        return
    previous_countries = previous.get("countries")
    if not isinstance(previous_countries, dict):
        return
    for country, current in current_sources["countries"].items():
        old = previous_countries.get(country)
        if not isinstance(old, dict):
            continue
        for field, maximum_delta in MAX_DELTAS.items():
            delta = abs(float(current[field]) - float(old.get(field, current[field])))
            if delta > maximum_delta:
                raise ValueError(
                    f"{country}.{field} changed by {delta:.4f}; "
                    f"manual review threshold is {maximum_delta:.4f}"
                )


def version_for_today(previous_version: str | None) -> str:
    prefix = date.today().strftime("%Y.%m.%d")
    if not previous_version or not previous_version.startswith(prefix):
        return prefix
    pieces = previous_version.split(".")
    suffix = int(pieces[3]) + 1 if len(pieces) == 4 else 2
    return f"{prefix}.{suffix}"


def build_catalog(
    sources: dict[str, Any],
    previous: dict[str, Any] | None,
    market_series_by_country: dict[str, dict[str, Any]],
) -> tuple[dict[str, Any], bool]:
    countries = public_countries(sources["countries"])
    for country, blocks in market_series_by_country.items():
        countries[country].update(blocks)
    material = {
        "methodology": sources["methodology"],
        "countries": countries,
    }
    source_digest = payload_digest(material)
    now = datetime.now(timezone.utc).replace(microsecond=0)
    reviewed_on = (now.date() + timedelta(days=REVIEW_DAYS)).isoformat()
    if previous and previous.get("contentDigest") == source_digest:
        result = dict(previous)
        result["checkedAt"] = now.isoformat().replace("+00:00", "Z")
        result["nextReviewAt"] = reviewed_on
        return result, False

    previous_version = previous.get("datasetVersion") if previous else None
    result = {
        "schemaVersion": 1,
        "datasetVersion": version_for_today(previous_version),
        "publishedAt": now.isoformat().replace("+00:00", "Z"),
        "checkedAt": now.isoformat().replace("+00:00", "Z"),
        "nextReviewAt": reviewed_on,
        "methodology": sources["methodology"],
        "contentDigest": source_digest,
        "countries": countries,
    }
    return result, True


def public_countries(countries: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for country, record in countries.items():
        result[country] = {
            "propertyTaxRate": record["propertyTaxRate"],
            "buyingCostRate": record["buyingCostRate"],
            "sellingCostRate": record["sellingCostRate"],
            "priceToRentYears": record["priceToRentYears"],
            "verifiedAt": record["verifiedAt"],
            "sources": [
                {"name": source["name"], "url": source["url"]}
                for source in record["sources"]
            ],
        }
    return result


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    args = parse_args()
    try:
        sources = load_json(args.sources)
        validate_sources(sources)
        if args.check_urls:
            for url in source_urls(sources):
                check_url(url)

        previous = load_json(args.previous) if args.previous.exists() else None
        validate_delta(previous, sources)
        as_of = date.today()
        if args.market_json:
            fetched_market = market_series.load_market_json(
                args.market_json.read_text(encoding="utf-8"),
                as_of,
            )
        else:
            fetched_market = market_series.fetch_market_series(EXPECTED_COUNTRIES, as_of)
        market = market_series.assemble_market_series(
            fetched_market,
            previous,
            EXPECTED_COUNTRIES,
            as_of,
        )
        catalog, changed = build_catalog(
            sources,
            previous,
            market,
        )
        write_json(args.output, catalog)
        write_json(args.latest, catalog)

        history_path = args.history_dir / f"{catalog['datasetVersion']}.json"
        write_json(history_path, catalog)

        if args.equity_json:
            equity = equity_index_returns.load_equity_json(
                args.equity_json.read_text(encoding="utf-8")
            )
        else:
            equity_previous = (
                load_json(args.equity_previous) if args.equity_previous.exists() else None
            )
            equity = equity_index_returns.fetch_equity_index_returns(
                EXPECTED_COUNTRIES,
                as_of,
                equity_previous,
            )
        write_json(args.equity_output, equity)

        print(
            json.dumps(
                {
                    "changed": changed,
                    "datasetVersion": catalog["datasetVersion"],
                    "countries": len(catalog["countries"]),
                    "output": str(args.output),
                    "equityOutput": str(args.equity_output),
                    "equityCountries": len(equity.get("countries", {})),
                },
                ensure_ascii=False,
            )
        )
        return 0
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        print(f"validation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
