#!/usr/bin/env python3
"""Compute 10-year price CAGRs for each country's main equity index."""

from __future__ import annotations

import json
import math
import subprocess
import time
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any
from urllib.parse import quote

INDEX_SPECS: dict[str, dict[str, str]] = {
    "chinaMainland": {
        # Yahoo 不提供沪深 300 指数长历史，改用跟踪该指数的 510300 ETF 收盘价。
        "yahooSymbol": "510300.SS",
        "sourceName": "Yahoo Finance：沪深 300",
    },
    "hongKong": {
        "yahooSymbol": "^HSI",
        "sourceName": "Yahoo Finance：恒生指数",
    },
    "singapore": {
        "yahooSymbol": "^STI",
        "sourceName": "Yahoo Finance：海峡时报指数",
    },
    "japan": {
        "yahooSymbol": "^N225",
        "sourceName": "Yahoo Finance：日经 225",
    },
    "australia": {
        "yahooSymbol": "^AXJO",
        "sourceName": "Yahoo Finance：S&P/ASX 200",
    },
    "unitedKingdom": {
        "yahooSymbol": "^FTSE",
        "sourceName": "Yahoo Finance：FTSE 100",
    },
    "netherlands": {
        "yahooSymbol": "^AEX",
        "sourceName": "Yahoo Finance：AEX",
    },
    "france": {
        "yahooSymbol": "^FCHI",
        "sourceName": "Yahoo Finance：CAC 40",
    },
    "germany": {
        "yahooSymbol": "^GDAXI",
        "sourceName": "Yahoo Finance：DAX",
    },
    "spain": {
        "yahooSymbol": "^IBEX",
        "sourceName": "Yahoo Finance：IBEX 35",
    },
    "italy": {
        "yahooSymbol": "FTSEMIB.MI",
        "sourceName": "Yahoo Finance：FTSE MIB",
    },
    "switzerland": {
        "yahooSymbol": "^SSMI",
        "sourceName": "Yahoo Finance：SMI",
    },
    "unitedStates": {
        "yahooSymbol": "^GSPC",
        "sourceName": "Yahoo Finance：S&P 500",
    },
    "canada": {
        "yahooSymbol": "^GSPTSE",
        "sourceName": "Yahoo Finance：S&P/TSX",
    },
}


def subtract_years(value: date, years: int) -> date:
    try:
        return value.replace(year=value.year - years)
    except ValueError:
        return value.replace(year=value.year - years, day=28)


def chart_url(symbol: str) -> str:
    return (
        "https://query1.finance.yahoo.com/v8/finance/chart/"
        f"{quote(symbol, safe='')}?range=11y&interval=1d"
    )


def download_chart(symbol: str) -> dict[str, Any]:
    result = subprocess.run(
        [
            "curl",
            "--http1.1",
            "--location",
            "--retry",
            "2",
            "--max-time",
            "40",
            "--silent",
            "--show-error",
            "--fail-with-body",
            "--user-agent",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
            "(KHTML, like Gecko) Version/17.4 Safari/605.1.15",
            "--header",
            "Accept: application/json",
            chart_url(symbol),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0 or not result.stdout:
        detail = result.stderr.strip() or f"exit {result.returncode}"
        raise ValueError(f"Yahoo download failed for {symbol}: {detail}")
    payload = json.loads(result.stdout)
    if not isinstance(payload, dict):
        raise ValueError(f"Yahoo payload for {symbol} is not an object")
    return payload


def parse_chart_points(payload: dict[str, Any]) -> list[tuple[date, float]]:
    chart = payload.get("chart")
    if not isinstance(chart, dict):
        raise ValueError("chart missing")
    results = chart.get("result")
    if not isinstance(results, list) or not results:
        error = chart.get("error")
        raise ValueError(f"chart result missing: {error}")
    result = results[0]
    timestamps = result.get("timestamp")
    closes = (
        ((result.get("indicators") or {}).get("quote") or [{}])[0].get("close")
    )
    if not isinstance(timestamps, list) or not isinstance(closes, list):
        raise ValueError("timestamp/close missing")
    points: list[tuple[date, float]] = []
    for epoch, close in zip(timestamps, closes):
        if close is None:
            continue
        try:
            level = float(close)
            observed = datetime.fromtimestamp(float(epoch), tz=timezone.utc).date()
        except (TypeError, ValueError, OSError, OverflowError):
            continue
        if level > 0:
            points.append((observed, level))
    points.sort()
    if len(points) < 2:
        raise ValueError("not enough closes")
    return points


def trailing_return(
    points: list[tuple[date, float]],
    source_name: str,
    as_of: date | None = None,
) -> dict[str, Any]:
    as_of = as_of or date.today()
    eligible = [item for item in points if item[0] <= as_of]
    if not eligible:
        raise ValueError("no price on or before as-of date")
    end_date, end_level = eligible[-1]
    target = subtract_years(end_date, 10)
    before = [item for item in eligible if item[0] <= target]
    after = [item for item in eligible if item[0] >= target]
    if before and (target - before[-1][0]).days <= 10:
        start_date, start_level = before[-1]
    elif after and (after[0][0] - target).days <= 10:
        start_date, start_level = after[0]
    else:
        raise ValueError("series does not cover the trailing 10 years")

    days = (end_date - start_date).days
    if not 3650 - 20 <= days <= 3650 + 20:
        raise ValueError(f"window is {days} days")
    rate = round((end_level / start_level) ** (365.25 / days) - 1, 4)
    if not -0.5 <= rate <= 0.5:
        raise ValueError(f"annualized return {rate} is outside -0.5...0.5")
    return {
        "rate": rate,
        "startDate": start_date.isoformat(),
        "endDate": end_date.isoformat(),
        "sourceName": source_name,
    }


def load_equity_json(text: str) -> dict[str, Any]:
    document = json.loads(text)
    if not isinstance(document, dict):
        raise ValueError("equity index document must be an object")
    return document


def fetch_equity_index_returns(
    countries: set[str],
    as_of: date | None = None,
    previous: dict[str, Any] | None = None,
) -> dict[str, Any]:
    as_of = as_of or date.today()
    previous_countries = {}
    if isinstance(previous, dict):
        maybe = previous.get("countries")
        if isinstance(maybe, dict):
            previous_countries = maybe

    quotes: dict[str, Any] = {}
    for index, country in enumerate(sorted(countries)):
        if country not in INDEX_SPECS:
            raise ValueError(f"no equity index mapped for {country}")
        if index > 0:
            time.sleep(0.35)
        spec = INDEX_SPECS[country]
        try:
            payload = download_chart(spec["yahooSymbol"])
            points = parse_chart_points(payload)
            quotes[country] = trailing_return(points, spec["sourceName"], as_of)
        except (ValueError, TypeError, KeyError, json.JSONDecodeError) as error:
            old = previous_countries.get(country)
            if isinstance(old, dict) and "rate" in old:
                print(
                    f"warning: {country} equity index fetch failed: {error}; "
                    "kept the previous value",
                    flush=True,
                )
                quotes[country] = {
                    "rate": old["rate"],
                    "startDate": old["startDate"],
                    "endDate": old["endDate"],
                    "sourceName": old.get("sourceName", spec["sourceName"]),
                }
            else:
                raise ValueError(
                    f"{country} equity index unavailable and previous catalog has no value: {error}"
                ) from error

    now = datetime.now(timezone.utc).replace(microsecond=0)
    return {
        "schemaVersion": 1,
        "publishedAt": now.isoformat().replace("+00:00", "Z"),
        "fetchedOn": as_of.isoformat(),
        "methodology": (
            "Ten-year price CAGR for each country's main equity index, excluding dividends. "
            "Computed from Yahoo Finance daily closes. Mainland China uses the CSI 300 ETF "
            "510300.SS because Yahoo does not publish a long CSI 300 index history."
        ),
        "countries": quotes,
    }


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
