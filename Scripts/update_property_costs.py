#!/usr/bin/env python3
"""Build and validate the public owner-occupied property-cost catalog."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from html.parser import HTMLParser
from pathlib import Path
from typing import Any

_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))
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
SPX_CSV_URL = "https://fred.stlouisfed.org/graph/fredgraph.csv?id=SP500"
SPX_SOURCE_NAME = "FRED：S&P 500"
SPX_SOURCE_URL = "https://fred.stlouisfed.org/series/SP500"
NUMBEO_RANKINGS_URL = "https://www.numbeo.com/property-investment/rankings_by_country.jsp"
NUMBEO_SOURCE_NAME = "Numbeo"
NUMBEO_USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
)
PRICE_TO_RENT_MIN_YEARS = 5
PRICE_TO_RENT_MAX_YEARS = 80
PRICE_TO_RENT_MAX_DELTA_YEARS = 15
NUMBEO_COUNTRIES = {
    "China": "chinaMainland",
    "Hong Kong (China)": "hongKong",
    "United States": "unitedStates",
    "Canada": "canada",
    "Singapore": "singapore",
    "Australia": "australia",
    "Japan": "japan",
    "United Kingdom": "unitedKingdom",
    "Germany": "germany",
    "France": "france",
    "Netherlands": "netherlands",
    "Spain": "spain",
    "Italy": "italy",
    "Switzerland": "switzerland",
}
CITY_CENTRE_HEADER = "Price To Rent Ratio City Centre"
OUTSIDE_CENTRE_HEADER = "Price To Rent Ratio Outside Of City Centre"


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
        "--spx-csv",
        type=Path,
        help="Use a local S&P 500 CSV instead of downloading FRED.",
    )
    parser.add_argument(
        "--numbeo-html",
        type=Path,
        help="Use a local Numbeo rankings page instead of downloading it.",
    )
    parser.add_argument(
        "--market-json",
        type=Path,
        help="Use a local mortgage, rent-growth, and appreciation JSON instead of downloading.",
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

        verified_at = date.fromisoformat(record["verifiedAt"])
        if verified_at > today + timedelta(days=1):
            raise ValueError(f"{country}.verifiedAt is in the future")
        if record.get("confidence") not in {"high", "medium", "low"}:
            raise ValueError(f"{country}.confidence is invalid")
        if len(record.get("methodologyNote", "")) < 10:
            raise ValueError(f"{country}.methodologyNote is missing")

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


def subtract_years(value: date, years: int) -> date:
    try:
        return value.replace(year=value.year - years)
    except ValueError:
        return value.replace(year=value.year - years, day=28)


def parse_spx_csv(text: str) -> list[tuple[date, float]]:
    points: list[tuple[date, float]] = []
    for line in text.splitlines():
        pieces = [piece.strip() for piece in line.split(",")]
        if len(pieces) < 2:
            continue
        try:
            observed = date.fromisoformat(pieces[0])
            level = float(pieces[1])
        except ValueError:
            continue
        if level > 0:
            points.append((observed, level))
    if len(points) < 2:
        raise ValueError("SPX series must contain at least two prices")
    points.sort()
    return points


def download_spx_csv() -> str:
    result = subprocess.run(
        [
            "curl",
            "--location",
            "--retry",
            "2",
            "--max-time",
            "40",
            "--silent",
            "--show-error",
            "--fail-with-body",
            "--user-agent",
            "BuyOrRentDataBot/1.0 (+https://github.com/qwanfan/BuyOrRent)",
            SPX_CSV_URL,
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0 or not result.stdout:
        detail = result.stderr.strip() or f"exit {result.returncode}"
        raise ValueError(f"SPX download failed: {detail}")
    return result.stdout


def trailing_spx_return(points: list[tuple[date, float]], as_of: date | None = None) -> dict[str, Any]:
    as_of = as_of or date.today()
    eligible = [item for item in points if item[0] <= as_of]
    if not eligible:
        raise ValueError("SPX series has no price on or before the as-of date")
    end_date, end_level = eligible[-1]
    target = subtract_years(end_date, 10)
    before = [item for item in eligible if item[0] <= target]
    after = [item for item in eligible if item[0] >= target]
    if before and (target - before[-1][0]).days <= 10:
        start_date, start_level = before[-1]
    elif after and (after[0][0] - target).days <= 10:
        start_date, start_level = after[0]
    else:
        raise ValueError("SPX series does not cover the trailing 10 years")

    days = (end_date - start_date).days
    if not 3650 - 20 <= days <= 3650 + 20:
        raise ValueError(f"SPX window is {days} days")
    rate = round((end_level / start_level) ** (365.25 / days) - 1, 4)
    if not -0.5 <= rate <= 0.5:
        raise ValueError(f"SPX annualized return {rate} is outside -0.5...0.5")
    return {
        "rate": rate,
        "method": "spxPriceCagr10Y",
        "startDate": start_date.isoformat(),
        "endDate": end_date.isoformat(),
        "startLevel": round(start_level, 2),
        "endLevel": round(end_level, 2),
        "sourceName": SPX_SOURCE_NAME,
        "sourceUrl": SPX_SOURCE_URL,
    }


def load_investment_return(spx_csv: Path | None) -> dict[str, Any]:
    text = spx_csv.read_text(encoding="utf-8") if spx_csv else download_spx_csv()
    return trailing_spx_return(parse_spx_csv(text))


class _NumbeoTableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.in_table = False
        self.in_cell = False
        self.row: list[str] = []
        self.rows: list[list[str]] = []
        self.buffer: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = dict(attrs)
        if tag == "table" and attributes.get("id") == "t2":
            self.in_table = True
        if not self.in_table:
            return
        if tag == "tr":
            self.row = []
        if tag in {"td", "th"}:
            self.in_cell = True
            self.buffer = []

    def handle_endtag(self, tag: str) -> None:
        if not self.in_table:
            return
        if tag in {"td", "th"} and self.in_cell:
            self.row.append(re.sub(r"\s+", " ", "".join(self.buffer)).strip())
            self.in_cell = False
        if tag == "tr" and self.row:
            self.rows.append(self.row)
            self.row = []
        if tag == "table":
            self.in_table = False

    def handle_data(self, data: str) -> None:
        if self.in_cell:
            self.buffer.append(data)


def _period_label(html: str, fetched_on: date) -> str:
    match = re.search(r"<title>(.*?)</title>", html, flags=re.IGNORECASE | re.DOTALL)
    title = re.sub(r"\s+", " ", match.group(1)).strip() if match else ""
    period = re.search(r"(20\d{2}(?:\s+Mid-Year)?)", title)
    if period:
        return period.group(1)
    return f"{fetched_on.year:04d}-{fetched_on.month:02d}"


def _round_years(value: Decimal) -> float:
    rounded = value.quantize(Decimal("0.1"), rounding=ROUND_HALF_UP)
    return float(rounded)


def parse_numbeo_rankings(html: str, fetched_on: date | None = None) -> dict[str, Any]:
    """Average Numbeo's city-centre and outside-centre price-to-rent ratios."""
    fetched_on = fetched_on or date.today()
    parser = _NumbeoTableParser()
    parser.feed(html)
    if not parser.rows:
        raise ValueError("Numbeo rankings table was not found")
    header = parser.rows[0]
    try:
        country_index = header.index("Country")
        city_index = header.index(CITY_CENTRE_HEADER)
        outside_index = header.index(OUTSIDE_CENTRE_HEADER)
    except ValueError as error:
        raise ValueError("Numbeo rankings table is missing a price-to-rent column") from error

    found: dict[str, float] = {}
    for row in parser.rows[1:]:
        if len(row) <= max(country_index, city_index, outside_index):
            continue
        name = row[country_index]
        country = NUMBEO_COUNTRIES.get(name)
        if country is None:
            continue
        if country in found:
            raise ValueError(f"duplicate Numbeo country {name}")
        try:
            city = Decimal(row[city_index])
            outside = Decimal(row[outside_index])
        except Exception as error:
            raise ValueError(f"Numbeo price-to-rent for {name} is not a number") from error
        years = _round_years((city + outside) / 2)
        if not PRICE_TO_RENT_MIN_YEARS <= years <= PRICE_TO_RENT_MAX_YEARS:
            raise ValueError(
                f"Numbeo price-to-rent for {name} is {years:.1f} years, outside "
                f"{PRICE_TO_RENT_MIN_YEARS}...{PRICE_TO_RENT_MAX_YEARS}"
            )
        found[country] = years

    missing = sorted(EXPECTED_COUNTRIES - set(found))
    if missing:
        raise ValueError(f"Numbeo country coverage mismatch; missing={missing}")
    return {
        "sourceName": NUMBEO_SOURCE_NAME,
        "sourceUrl": NUMBEO_RANKINGS_URL,
        "periodLabel": _period_label(html, fetched_on),
        "years": {country: found[country] for country in sorted(EXPECTED_COUNTRIES)},
    }


def download_numbeo_html() -> str:
    result = subprocess.run(
        [
            "curl",
            "--location",
            "--retry",
            "2",
            "--max-time",
            "40",
            "--silent",
            "--show-error",
            "--fail-with-body",
            "--user-agent",
            NUMBEO_USER_AGENT,
            NUMBEO_RANKINGS_URL,
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0 or not result.stdout:
        detail = result.stderr.strip() or f"exit {result.returncode}"
        raise ValueError(f"Numbeo download failed: {detail}")
    return result.stdout


def load_price_to_rent(numbeo_html: Path | None) -> dict[str, Any]:
    html = numbeo_html.read_text(encoding="utf-8") if numbeo_html else download_numbeo_html()
    return parse_numbeo_rankings(html)


def validate_price_to_rent_delta(
    previous: dict[str, Any] | None,
    years: dict[str, float],
) -> None:
    """Skip the jump check until a previous catalog actually has this block."""
    if not previous:
        return
    block = previous.get("priceToRent")
    if not isinstance(block, dict):
        return
    old_years = block.get("years")
    if not isinstance(old_years, dict):
        return
    for country, value in years.items():
        if country not in old_years:
            continue
        delta = abs(float(value) - float(old_years[country]))
        if delta > PRICE_TO_RENT_MAX_DELTA_YEARS:
            raise ValueError(
                f"{country} price-to-rent changed by {delta:.1f} years; "
                f"manual review threshold is {PRICE_TO_RENT_MAX_DELTA_YEARS}"
            )


def comparable_payload(document: dict[str, Any]) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "methodology": document["methodology"],
        "countries": public_countries(document["countries"]),
    }
    if "investmentReturn" in document:
        payload["investmentReturn"] = document["investmentReturn"]
    if "priceToRent" in document:
        payload["priceToRent"] = document["priceToRent"]
    return payload


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
    investment_return: dict[str, Any],
    price_to_rent: dict[str, Any],
    market_series_by_country: dict[str, dict[str, Any]],
) -> tuple[dict[str, Any], bool]:
    countries = public_countries(sources["countries"])
    for country, blocks in market_series_by_country.items():
        countries[country].update(blocks)
    material = {
        "methodology": sources["methodology"],
        "countries": countries,
        "investmentReturn": investment_return,
        "priceToRent": price_to_rent,
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
        "investmentReturn": investment_return,
        "priceToRent": price_to_rent,
        "countries": countries,
    }
    return result, True


def public_countries(countries: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for country, record in countries.items():
        public_record = dict(record)
        public_record["sources"] = [
            {"name": source["name"], "url": source["url"]}
            for source in record["sources"]
        ]
        result[country] = public_record
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
        investment_return = load_investment_return(args.spx_csv)
        price_to_rent = load_price_to_rent(args.numbeo_html)
        validate_price_to_rent_delta(previous, price_to_rent["years"])
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
        if args.check_urls:
            check_url(SPX_SOURCE_URL)
            check_url(NUMBEO_RANKINGS_URL)
        catalog, changed = build_catalog(
            sources,
            previous,
            investment_return,
            price_to_rent,
            market,
        )
        write_json(args.output, catalog)
        write_json(args.latest, catalog)

        history_path = args.history_dir / f"{catalog['datasetVersion']}.json"
        write_json(history_path, catalog)

        print(
            json.dumps(
                {
                    "changed": changed,
                    "datasetVersion": catalog["datasetVersion"],
                    "countries": len(catalog["countries"]),
                    "output": str(args.output),
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
