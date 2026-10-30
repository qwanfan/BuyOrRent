"""Fetch mortgage rates, rent growth, and home appreciation for the cost catalog."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from calendar import monthrange
from datetime import date
from decimal import Decimal, ROUND_HALF_UP
from io import BytesIO
from typing import Any

USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
)
BOT_USER_AGENT = "BuyOrRentDataBot/1.0 (+https://github.com/qwanfan/BuyOrRent)"

FIELDS = ("mortgageRate", "rentGrowth", "appreciation")
MAX_DELTAS = {
    "mortgageRate": 0.02,
    "rentGrowth": 0.05,
    "appreciation": 0.10,
}
BOUNDS = {
    "mortgageRate": (0.0, 0.20, False),
    "rentGrowth": (-0.05, 0.15, True),
    "appreciation": (-0.20, 0.20, True),
}

MORTGAGE_SPREADS = {
    "hongKong": 0.013,
    "singapore": 0.010,
    "chinaMainland": 0.0,
}
MORTGAGE_NAMES = {
    "chinaMainland": "5 年期以上 LPR",
    "hongKong": "1 个月 HIBOR + 预设利差估算",
    "unitedStates": "Freddie Mac 30 年固定房贷利率",
    "canada": "加拿大央行 5 年期按揭挂牌利率",
    "singapore": "3 个月 SORA + 预设利差估算",
    "australia": "澳洲央行新发放自住房贷利率",
    "japan": "Flat 35 当月利率",
    "unitedKingdom": "英格兰银行房贷报价利率",
    "germany": "ECB 新发放住房贷款利率",
    "france": "ECB 新发放住房贷款利率",
    "netherlands": "ECB 新发放住房贷款利率",
    "spain": "ECB 新发放住房贷款利率",
    "italy": "ECB 新发放住房贷款利率",
    "switzerland": "瑞士央行公布的新业务房贷利率",
}
ECB_CODES = {
    "germany": "DE",
    "france": "FR",
    "netherlands": "NL",
    "spain": "ES",
    "italy": "IT",
}
OECD_CODES = {
    "australia": "AUS",
    "canada": "CAN",
    "switzerland": "CHE",
    "germany": "DEU",
    "spain": "ESP",
    "france": "FRA",
    "unitedKingdom": "GBR",
    "italy": "ITA",
    "netherlands": "NLD",
    "unitedStates": "USA",
}
BIS_CODES = {
    "chinaMainland": "CN",
    "hongKong": "HK",
    "unitedStates": "US",
    "canada": "CA",
    "singapore": "SG",
    "australia": "AU",
    "japan": "JP",
    "unitedKingdom": "GB",
    "germany": "DE",
    "france": "FR",
    "netherlands": "NL",
    "spain": "ES",
    "italy": "IT",
    "switzerland": "CH",
}
RENT_NAMES = {
    "oecd": "OECD 实际房租",
    "japan": "总务省民营房租",
    "chinaMainland": "国家统计局租赁房房租",
    "hongKong": "统计处私人住宅租金",
    "singapore": "市区重建局私人住宅租金指数",
}
APPRECIATION_NAME = "国际清算银行选定住宅房价"
BIS_SOURCE = "https://stats.bis.org/api/v1/data/WS_SPP"


def round_rate(value: float) -> float:
    rounded = Decimal(str(value)).quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
    return float(rounded)


def observation(rate: float, period_label: str, source_name: str, source_url: str) -> dict[str, Any]:
    return {
        "rate": round_rate(rate),
        "periodLabel": period_label,
        "sourceName": source_name,
        "sourceUrl": source_url,
    }


def period_date(label: str) -> date | None:
    text = label.strip()
    patterns = (
        ("%Y-%m-%d", 10),
        ("%Y-%m", 7),
        ("%d %b %Y", None),
        ("%b %Y", None),
        ("%d/%m/%Y", 10),
    )
    for pattern, size in patterns:
        sample = text if size is None else text[:size]
        try:
            parsed = date.fromisoformat(sample) if pattern == "%Y-%m-%d" else None
        except ValueError:
            parsed = None
        if pattern == "%Y-%m-%d" and parsed:
            return parsed
        if pattern == "%Y-%m" and len(text) >= 7:
            try:
                year, month = int(text[:4]), int(text[5:7])
                if 1 <= month <= 12:
                    return date(year, month, 1)
            except ValueError:
                pass
            continue
        try:
            from datetime import datetime
            return datetime.strptime(text, pattern).date()
        except ValueError:
            continue
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    if len(text) == 7 and text[:4].isdigit() and text[4:] in months:
        return date(int(text[:4]), months.index(text[4:]) + 1, 1)
    span = re.fullmatch(r"(20\d{2}-Q[1-4])[\u2013-](20\d{2}-Q[1-4])", text)
    if span:
        return period_date(span.group(2))
    quarter = re.fullmatch(r"(20\d{2})-Q([1-4])", text)
    if quarter:
        month = int(quarter.group(2)) * 3
        return date(int(quarter.group(1)), month, monthrange(int(quarter.group(1)), month)[1])
    if re.fullmatch(r"20\d{2}", text):
        return date(int(text), 12, 31)
    month_label = re.fullmatch(r"(20\d{2})-(\d{2})", text)
    if month_label:
        year, month = int(month_label.group(1)), int(month_label.group(2))
        if 1 <= month <= 12:
            return date(year, month, 1)
    return None


def _subtract_months(value: date, months: int) -> date:
    month_index = value.year * 12 + value.month - 1 - months
    year, month = divmod(month_index, 12)
    day = min(value.day, monthrange(year, month + 1)[1])
    return date(year, month + 1, day)


def validate_observation(record: dict[str, Any], field: str, as_of: date) -> None:
    minimum, maximum, allow_zero = BOUNDS[field]
    rate = float(record["rate"])
    if rate < minimum or rate > maximum or (not allow_zero and rate <= 0):
        raise ValueError(f"{field} rate {rate} is outside {minimum}...{maximum}")
    observed = period_date(str(record["periodLabel"]))
    if observed is None:
        raise ValueError(f"{field} period {record['periodLabel']} is not a date")
    if observed > as_of and (observed - as_of).days > 31:
        raise ValueError(f"{field} period {record['periodLabel']} is in the future")
    if observed < _subtract_months(as_of, 24):
        raise ValueError(f"{field} period {record['periodLabel']} is older than 24 months")
    if not str(record.get("sourceUrl", "")).startswith("https://"):
        raise ValueError(f"{field} source URL must use https")
    if len(str(record.get("sourceName", ""))) < 2:
        raise ValueError(f"{field} source name is missing")


def download(url: str, *, binary: bool = False, user_agent: str = USER_AGENT) -> str | bytes:
    try:
        return _download_once(url, binary=binary, user_agent=user_agent)
    except ValueError:
        if user_agent == BOT_USER_AGENT:
            raise
        return _download_once(url, binary=binary, user_agent=BOT_USER_AGENT)


def _download_once(url: str, *, binary: bool, user_agent: str) -> str | bytes:
    result = subprocess.run(
        [
            "curl", "--http1.1", "--location", "--retry", "2", "--max-time", "40",
            "--silent", "--show-error", "--fail-with-body",
            "--user-agent", user_agent, url,
        ],
        capture_output=True,
        check=False,
    )
    payload = result.stdout if binary else result.stdout.decode("utf-8", errors="replace")
    if result.returncode != 0 or not result.stdout:
        detail = result.stderr.decode("utf-8", errors="replace").strip() or f"exit {result.returncode}"
        raise ValueError(f"download failed: {url}: {detail}")
    return payload


def _csv_fields(line: str) -> list[str]:
    fields: list[str] = []
    current: list[str] = []
    quoted = False
    for character in line:
        if character == '"':
            quoted = not quoted
        elif character == "," and not quoted:
            fields.append("".join(current).strip())
            current = []
        else:
            current.append(character)
    fields.append("".join(current).strip())
    return fields


def parse_fred_csv(text: str, source_name: str, source_url: str) -> dict[str, Any]:
    for line in reversed(text.splitlines()):
        parts = [piece.strip() for piece in line.split(",")]
        if len(parts) < 2:
            continue
        try:
            percent = float(parts[1])
        except ValueError:
            continue
        if period_date(parts[0]) is None:
            continue
        return observation(percent / 100, parts[0], source_name, source_url)
    raise ValueError("FRED mortgage CSV has no rate")


def parse_boe_csv(text: str, source_name: str, source_url: str) -> dict[str, Any]:
    if "<html" in text.lower():
        raise ValueError("Bank of England response is HTML")
    for line in reversed(text.splitlines()):
        parts = _csv_fields(line)
        if len(parts) < 2 or period_date(parts[0]) is None:
            continue
        try:
            percent = float(parts[1])
        except ValueError:
            continue
        return observation(percent / 100, parts[0], source_name, source_url)
    raise ValueError("Bank of England CSV has no rate")


def parse_bank_of_canada(payload: dict[str, Any], source_name: str, source_url: str) -> dict[str, Any]:
    for observation_row in reversed(payload.get("observations") or []):
        label = observation_row.get("d")
        raw = (observation_row.get("V80691335") or {}).get("v")
        try:
            percent = float(raw)
        except (TypeError, ValueError):
            continue
        if not isinstance(label, str) or period_date(label) is None:
            continue
        return observation(percent / 100, label, source_name, source_url)
    raise ValueError("Bank of Canada JSON has no rate")


def parse_ecb_json(payload: dict[str, Any], source_name: str, source_url: str) -> dict[str, Any]:
    try:
        series = next(iter(payload["dataSets"][0]["series"].values()))
        observations_map = series["observations"]
        periods = next(
            item["values"]
            for item in payload["structure"]["dimensions"]["observation"]
            if item.get("id") == "TIME_PERIOD"
        )
    except (KeyError, IndexError, StopIteration, TypeError) as error:
        raise ValueError("ECB JSON has no series") from error
    best_index = -1
    percent = None
    for key, raw in observations_map.items():
        try:
            index = int(key)
            value = float(raw[0])
        except (TypeError, ValueError, IndexError):
            continue
        if index > best_index:
            best_index = index
            percent = value
    if percent is None or best_index >= len(periods):
        raise ValueError("ECB JSON has no observation")
    label = periods[best_index].get("id")
    if not isinstance(label, str) or period_date(label) is None:
        raise ValueError("ECB period is missing")
    return observation(percent / 100, label, source_name, source_url)


def parse_rba_csv(text: str, source_name: str, source_url: str) -> dict[str, Any]:
    if "<html" in text.lower():
        raise ValueError("RBA response is HTML")
    rows = [_csv_fields(line) for line in text.splitlines()]
    header_index = next((index for index, row in enumerate(rows) if row and row[0].strip() == "Series ID"), None)
    if header_index is None:
        raise ValueError("RBA CSV has no Series ID row")
    ids = rows[header_index]
    column = next((index for index, item in enumerate(ids) if item == "FLRHOFTA"), None)
    if column is None:
        column = next((index for index, item in enumerate(ids) if item.startswith("FLRHOO")), None)
    if column is None:
        column = next((index for index, item in enumerate(ids) if item.startswith("FLR")), None)
    if column is None or column == 0:
        raise ValueError("RBA CSV has no housing-loan column")
    for row in reversed(rows[header_index + 1:]):
        if len(row) <= column or period_date(row[0]) is None:
            continue
        try:
            percent = float(row[column])
        except ValueError:
            continue
        return observation(percent / 100, row[0], source_name, source_url)
    raise ValueError("RBA CSV has no rate")


def parse_snb_csv(text: str, source_name: str, source_url: str) -> dict[str, Any]:
    found = None
    for line in text.splitlines():
        fields = [piece.strip().strip('"') for piece in line.split(";")]
        if len(fields) < 4 or fields[2] != "MV" or period_date(fields[0]) is None:
            continue
        try:
            percent = float(fields[3])
        except ValueError:
            continue
        found = observation(percent / 100, fields[0], source_name, source_url)
    if found is None:
        raise ValueError("SNB CSV has no floating mortgage rate")
    return found


def parse_sora_json(payload: dict[str, Any], source_name: str, source_url: str) -> dict[str, Any]:
    records = (payload.get("result") or {}).get("records") or []
    record = next((item for item in records if "SORA) - 3 Month" in str(item.get("DataSeries", ""))), None)
    if record is None:
        raise ValueError("SORA record was not found")
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    best: tuple[int, str, float] | None = None
    for key, value in record.items():
        if not (isinstance(key, str) and len(key) == 7 and key[4:] in months and key[:4].isdigit()):
            continue
        try:
            percent = float(value)
        except (TypeError, ValueError):
            continue
        sort_key = int(key[:4]) * 100 + months.index(key[4:])
        if best is None or sort_key > best[0]:
            best = (sort_key, key, percent)
    if best is None:
        raise ValueError("SORA record has no month")
    return observation(best[2] / 100, best[1], source_name, source_url)


def parse_lpr_json(payload: dict[str, Any], source_name: str, source_url: str) -> dict[str, Any]:
    records = payload.get("records")
    if not isinstance(records, list):
        records = (payload.get("data") or {}).get("records")
    if not isinstance(records, list):
        raise ValueError("LPR JSON has no records")
    latest: tuple[date, str, float] | None = None
    for record in records:
        try:
            percent = float(record["5Y"])
        except (KeyError, TypeError, ValueError):
            continue
        label = record.get("showDateCN")
        observed = period_date(label) if isinstance(label, str) else None
        if observed is None or not isinstance(label, str):
            continue
        if latest is None or observed > latest[0]:
            latest = (observed, label, percent)
    if latest is None:
        raise ValueError("LPR JSON has no 5Y rate")
    return observation(latest[2] / 100, latest[1], source_name, source_url)


def parse_hibor_json(payload: dict[str, Any], source_name: str, source_url: str) -> dict[str, Any]:
    records = ((payload.get("result") or {}).get("records")) or []
    for record in records:
        label = record.get("end_of_day")
        try:
            percent = float(record["ir_1m"])
        except (KeyError, TypeError, ValueError):
            continue
        if not isinstance(label, str) or period_date(label) is None:
            continue
        return observation(percent / 100, label, source_name, source_url)
    raise ValueError("HIBOR JSON has no 1-month rate")


def parse_flat35_html(html: str, source_name: str, source_url: str) -> dict[str, Any]:
    text = re.sub(r"<[^>]+>", " ", html).replace("&nbsp;", " ")
    rate_match = re.search(r"21\s*年\s*[～~]\s*35\s*年\s*年\s*([\d.]+)\s*%", text)
    period_match = re.search(r"(\d{4})\s*年\s*(\d{1,2})\s*月現在", text)
    if not rate_match or not period_match:
        raise ValueError("Flat 35 page has no rate")
    label = f"{int(period_match.group(1)):04d}-{int(period_match.group(2)):02d}"
    return observation(float(rate_match.group(1)) / 100, label, source_name, source_url)


def apply_spread(record: dict[str, Any], spread: float, source_name: str) -> dict[str, Any]:
    updated = dict(record)
    updated["rate"] = round_rate(float(record["rate"]) + spread)
    updated["sourceName"] = source_name
    return updated


def parse_oecd_csv(text: str, area_code: str, source_name: str, source_url: str) -> dict[str, Any]:
    rows = [line.split(",") for line in text.splitlines()]
    if not rows:
        raise ValueError("OECD CSV is empty")
    header = [cell.strip() for cell in rows[0]]
    try:
        area_column = header.index("REF_AREA")
        period_column = header.index("TIME_PERIOD")
        value_column = header.index("OBS_VALUE")
    except ValueError as error:
        raise ValueError("OECD CSV is missing columns") from error
    best: tuple[int, float] | None = None
    for row in rows[1:]:
        cells = [cell.strip() for cell in row]
        if len(cells) <= max(area_column, period_column, value_column) or cells[area_column] != area_code:
            continue
        try:
            year = int(cells[period_column])
            percent = float(cells[value_column])
        except ValueError:
            continue
        if best is None or year > best[0]:
            best = (year, percent)
    if best is None:
        raise ValueError(f"OECD CSV has no rent growth for {area_code}")
    return observation(best[1] / 100, str(best[0]), source_name, source_url)


def parse_japan_cpi(text: str, source_name: str, source_url: str) -> dict[str, Any]:
    lines = text.splitlines()
    code_line = next((line for line in lines if "Group/Item code" in line or "品目符号" in line), None)
    if code_line is None:
        raise ValueError("Japan CPI has no item-code row")
    codes = [cell.strip() for cell in code_line.split(",")]
    if "3000" not in codes:
        raise ValueError("Japan CPI has no private-rent column")
    column = codes.index("3000")
    by_year: dict[int, list[float]] = {}
    for line in lines:
        fields = line.split(",")
        if len(fields) <= column or len(fields[0]) != 6 or not fields[0].isdigit():
            continue
        try:
            index = float(fields[column])
        except ValueError:
            continue
        by_year.setdefault(int(fields[0][:4]), []).append(index)
    complete = {year for year, values in by_year.items() if len(values) == 12}
    if not complete:
        raise ValueError("Japan CPI has no complete year")
    year = max(complete)
    if year - 1 not in complete:
        raise ValueError("Japan CPI is missing the prior year")
    current = sum(by_year[year]) / len(by_year[year])
    previous = sum(by_year[year - 1]) / len(by_year[year - 1])
    if previous == 0:
        raise ValueError("Japan CPI prior year is zero")
    return observation(current / previous - 1, str(year), source_name, source_url)


def china_release_url(html: str) -> str | None:
    patterns = (
        r"""href="(\./[^"]+)"[^>]*title='[^']*居民消费价格[^']*'""",
        r"""title='[^']*居民消费价格[^']*'[^>]*href="(\./[^"]+)""",
    )
    for pattern in patterns:
        match = re.search(pattern, html)
        if match:
            return "https://www.stats.gov.cn/sj/zxfb/" + match.group(1)[2:]
    return None


def parse_china_html(html: str, source_name: str, source_url: str) -> dict[str, Any]:
    text = re.sub(r"<[^>]+>", " ", html).replace("&nbsp;", " ")
    period = re.search(r"(\d{4})年(\d{1,2})月份", text)
    numbers = re.search(r"租赁房房租\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)", text)
    if not period or not numbers:
        raise ValueError("China CPI article has no rental row")
    label = f"{int(period.group(1)):04d}-{int(period.group(2)):02d}"
    return observation(float(numbers.group(3)) / 100, label, source_name, source_url)


def hong_kong_issue(payload: dict[str, Any]) -> tuple[int, int]:
    months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    products = payload.get("productIndex") or []
    product = next((item for item in products if item.get("Product_Code") == "B1060001"), None)
    if product is None:
        raise ValueError("Hong Kong report index has no rent bulletin")
    parts = str(product.get("issue", "")).split()
    if len(parts) != 2 or parts[0] not in months:
        raise ValueError("Hong Kong report issue is not a month")
    return int(parts[1]), months.index(parts[0]) + 1


def parse_hong_kong_rent_text(text: str, period_label: str, source_name: str, source_url: str) -> dict[str, Any]:
    normalized = re.sub(r"\s+", " ", text.replace("−", "-"))
    match = re.search(
        r"(\d{2,3}\.\d)\s*([+-]\d{1,2}\.\d)(?:\s*\d{2,3}\.\d\s*[+-]\d{1,2}\.\d){3}\s*Private housing rent",
        normalized,
    )
    if not match:
        raise ValueError("Hong Kong rent bulletin has no private housing rent")
    return observation(float(match.group(2)) / 100, period_label, source_name, source_url)


def _decode_bytes(raw: bytes) -> str:
    for encoding in ("utf-8-sig", "cp932", "utf-16"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace")


def pdf_text(data: bytes) -> str:
    from pypdf import PdfReader

    reader = PdfReader(BytesIO(data))
    return "\n".join(page.extract_text() or "" for page in reader.pages)


def parse_singapore_rent(payload: dict[str, Any], source_name: str, source_url: str) -> dict[str, Any]:
    records = (payload.get("result") or {}).get("records") or []
    record = next(
        (item for item in records if str(item.get("DataSeries", "")).strip() == "Rental Index Of Residential Properties"),
        None,
    )
    if record is None:
        raise ValueError("Singapore rent index was not found")
    quarters: list[tuple[int, str, float]] = []
    for key, raw in record.items():
        if not (isinstance(key, str) and len(key) == 6 and key.endswith("Q") and key[4] in "1234"):
            continue
        try:
            value = float(raw)
            year = int(key[:4])
            quarter = int(key[4])
        except (TypeError, ValueError):
            continue
        quarters.append((year * 10 + quarter, f"{year:04d}-Q{quarter}", value))
    if not quarters:
        raise ValueError("Singapore rent index has no quarter")
    latest = max(quarters, key=lambda item: item[0])
    prior_key = (latest[0] // 10 - 1) * 10 + latest[0] % 10
    prior = next((item for item in quarters if item[0] == prior_key), None)
    if prior is None or prior[2] == 0:
        raise ValueError("Singapore rent index is missing the quarter one year earlier")
    return observation(latest[2] / prior[2] - 1, latest[1], source_name, source_url)


def parse_bis_csv(text: str, area_code: str, source_name: str, source_url: str) -> dict[str, Any]:
    """10-year compound growth of the nominal index between the latest quarter and the same quarter 10 years earlier."""
    rows = []
    for line in text.splitlines():
        rows.append([cell.strip().strip('"') for cell in line.split(",")])
    if not rows:
        raise ValueError("BIS CSV is empty")
    header = rows[0]
    try:
        area_column = header.index("REF_AREA")
        period_column = header.index("TIME_PERIOD")
        value_column = header.index("OBS_VALUE")
    except ValueError as error:
        raise ValueError("BIS CSV is missing columns") from error
    levels: dict[int, tuple[str, float]] = {}
    for row in rows[1:]:
        if len(row) <= max(area_column, period_column, value_column) or row[area_column] != area_code:
            continue
        match = re.fullmatch(r"(20\d{2})-Q([1-4])", row[period_column])
        if not match:
            continue
        try:
            level = float(row[value_column])
        except ValueError:
            continue
        if level <= 0:
            continue
        key = int(match.group(1)) * 10 + int(match.group(2))
        levels[key] = (row[period_column], level)
    if not levels:
        raise ValueError(f"BIS CSV has no price index for {area_code}")
    latest_key = max(levels)
    start_key = latest_key - 100
    if start_key not in levels:
        raise ValueError(f"BIS CSV is missing the index 10 years before {levels[latest_key][0]}")
    start_label, start_level = levels[start_key]
    end_label, end_level = levels[latest_key]
    rate = (end_level / start_level) ** 0.1 - 1
    return observation(rate, f"{start_label}\u2013{end_label}", source_name, source_url)


def _mortgage_url(country: str) -> str:
    if country in ECB_CODES:
        code = ECB_CODES[country]
        return (
            "https://data-api.ecb.europa.eu/service/data/MIR/"
            f"M.{code}.B.A2C.AM.R.A.2250.EUR.N?format=jsondata&lastNObservations=1"
        )
    return {
        "unitedStates": "https://fred.stlouisfed.org/graph/fredgraph.csv?id=MORTGAGE30US",
        "unitedKingdom": "https://www.bankofengland.co.uk/boeapps/iadb/fromshowcolumns.asp?csv.x=yes&Datefrom=01/Jan/2020&Dateto=now&SeriesCodes=IUMBV34&CSVF=TN&UsingCodes=Y&VPD=Y&VFD=N",
        "canada": "https://www.bankofcanada.ca/valet/observations/V80691335/json?recent=4",
        "australia": "https://www.rba.gov.au/statistics/tables/csv/f6-data.csv",
        "singapore": "https://data.gov.sg/api/action/datastore_search?resource_id=d_5fe5a4bb4a1ecc4d8a56a095832e2b24&limit=100",
        "switzerland": "https://data.snb.ch/api/cube/zikrepro/data/csv/en?D1=MV",
        "chinaMainland": "https://www.chinamoney.com.cn/dqs/rest/cm-u-bk-currency/LprHis",
        "hongKong": "https://api.hkma.gov.hk/public/market-data-and-statistics/monthly-statistical-bulletin/er-ir/hk-interbank-ir-daily?segment=hibor.fixing&pagesize=5&sortby=end_of_day&sortorder=desc",
        "japan": "https://www.flat35.com/loan/lineup/flat35/index.html",
    }[country]


def fetch_mortgage(country: str, as_of: date) -> dict[str, Any]:
    name = MORTGAGE_NAMES[country]
    url = _mortgage_url(country)
    if country in ECB_CODES:
        record = parse_ecb_json(json.loads(str(download(url))), name, url)
    elif country == "unitedStates":
        record = parse_fred_csv(str(download(url, user_agent=BOT_USER_AGENT)), name, url)
    elif country == "unitedKingdom":
        record = parse_boe_csv(str(download(url)), name, url)
    elif country == "canada":
        record = parse_bank_of_canada(json.loads(str(download(url))), name, url)
    elif country == "australia":
        record = parse_rba_csv(str(download(url)), name, url)
    elif country == "singapore":
        record = parse_sora_json(json.loads(str(download(url))), name, url.split("&limit")[0])
    elif country == "switzerland":
        record = parse_snb_csv(str(download(url)), name, url)
    elif country == "chinaMainland":
        start = _subtract_months(as_of, 4).isoformat()
        live = f"{url}?lang=CN&strStartDate={start}&strEndDate={as_of.isoformat()}"
        record = parse_lpr_json(json.loads(str(download(live))), name, url)
    elif country == "hongKong":
        record = parse_hibor_json(json.loads(str(download(url))), name, url.split("?")[0])
    elif country == "japan":
        record = parse_flat35_html(str(download(url)), name, url)
    else:
        raise ValueError(f"no mortgage source for {country}")
    if country in MORTGAGE_SPREADS:
        record = apply_spread(record, MORTGAGE_SPREADS[country], name)
    return record


def _oecd_url(code: str) -> str:
    return (
        "https://sdmx.oecd.org/public/rest/data/"
        f"OECD.SDD.TPS,DSD_PRICES@DF_PRICES_ALL,1.0/{code}.A.N.CPI.PA.CP041.N.GY"
        "?startPeriod=2020&format=csvfile"
    )


def fetch_rent_growth(country: str) -> dict[str, Any]:
    if country in OECD_CODES:
        code = OECD_CODES[country]
        url = _oecd_url(code)
        return parse_oecd_csv(str(download(url)), code, RENT_NAMES["oecd"], url.split("?")[0])
    if country == "japan":
        url = "https://www.stat.go.jp/data/cpi/2020/csv/zmi2020aa.csv"
        raw = download(url, binary=True)
        assert isinstance(raw, bytes)
        return parse_japan_cpi(_decode_bytes(raw), RENT_NAMES["japan"], url)
    if country == "chinaMainland":
        pages = [
            "https://www.stats.gov.cn/sj/zxfb/index.html",
            "https://www.stats.gov.cn/sj/zxfb/index_1.html",
        ]
        for page in pages:
            article = china_release_url(str(download(page)))
            if article:
                return parse_china_html(str(download(article)), RENT_NAMES["chinaMainland"], article)
        raise ValueError("China CPI release was not found")
    if country == "hongKong":
        index_url = "https://www.censtatd.gov.hk/en/data/stat_report/subject/270/report_index.json"
        year, month = hong_kong_issue(json.loads(str(download(index_url))))
        code = f"B1060001{year:04d}MM{month:02d}"
        pdf_url = f"https://www.censtatd.gov.hk/wbr/B1060001/{code}/att/en/{code}.pdf"
        text = pdf_text(download(pdf_url, binary=True))  # type: ignore[arg-type]
        return parse_hong_kong_rent_text(text, f"{year:04d}-{month:02d}", RENT_NAMES["hongKong"], pdf_url)
    if country == "singapore":
        url = "https://data.gov.sg/api/action/datastore_search?resource_id=d_647dabde09e726b9eeb75e4d9cd96699&limit=10"
        return parse_singapore_rent(json.loads(str(download(url))), RENT_NAMES["singapore"], url.split("&limit")[0])
    raise ValueError(f"no rent-growth source for {country}")


def fetch_appreciation(country: str, as_of: date) -> dict[str, Any]:
    code = BIS_CODES[country]
    url = f"{BIS_SOURCE}/Q.{code}.N.628?startPeriod={as_of.year - 11}-Q1&format=csv"
    return parse_bis_csv(str(download(url)), code, APPRECIATION_NAME, url)


def fetch_market_series(countries: set[str], as_of: date) -> dict[str, dict[str, dict[str, Any]]]:
    fetched: dict[str, dict[str, dict[str, Any]]] = {}
    for country in sorted(countries):
        fetched[country] = {}
        for field, fetcher in (
            ("mortgageRate", lambda country=country: fetch_mortgage(country, as_of)),
            ("rentGrowth", lambda country=country: fetch_rent_growth(country)),
            ("appreciation", lambda country=country: fetch_appreciation(country, as_of)),
        ):
            try:
                record = fetcher()
                validate_observation(record, field, as_of)
                fetched[country][field] = record
            except (ValueError, json.JSONDecodeError, OSError, KeyError, TypeError) as error:
                print(f"warning: {country}.{field} fetch failed: {error}", file=sys.stderr)
    return fetched


def _previous_observation(previous: dict[str, Any] | None, country: str, field: str) -> dict[str, Any] | None:
    if not isinstance(previous, dict):
        return None
    countries = previous.get("countries")
    if not isinstance(countries, dict):
        return None
    record = countries.get(country)
    if not isinstance(record, dict):
        return None
    observation_record = record.get(field)
    if isinstance(observation_record, dict) and "rate" in observation_record:
        return observation_record
    return None


def assemble_market_series(
    fetched: dict[str, dict[str, dict[str, Any]]],
    previous: dict[str, Any] | None,
    countries: set[str],
    as_of: date,
) -> dict[str, dict[str, dict[str, Any]]]:
    assembled: dict[str, dict[str, dict[str, Any]]] = {}
    for country in sorted(countries):
        assembled[country] = {}
        for field, maximum in MAX_DELTAS.items():
            new = fetched.get(country, {}).get(field)
            old = _previous_observation(previous, country, field)
            if new is None:
                if old is None:
                    raise ValueError(f"{country}.{field} unavailable and previous catalog has no value")
                print(f"warning: {country}.{field} kept the previous value", file=sys.stderr)
                assembled[country][field] = old
                continue
            validate_observation(new, field, as_of)
            single_quarter = re.fullmatch(r"20\d{2}-Q[1-4]", str((old or {}).get("periodLabel", "")))
            if old is not None and not (field == "appreciation" and single_quarter):
                delta = abs(float(new["rate"]) - float(old["rate"]))
                if delta > maximum:
                    raise ValueError(
                        f"{country}.{field} changed by {delta:.4f}; "
                        f"manual review threshold is {maximum:.4f}"
                    )
            assembled[country][field] = new
    return assembled


def load_market_json(path_text: str, as_of: date) -> dict[str, dict[str, dict[str, Any]]]:
    payload = json.loads(path_text)
    if not isinstance(payload, dict):
        raise ValueError("market JSON must be an object")
    fetched: dict[str, dict[str, dict[str, Any]]] = {}
    for country, record in payload.items():
        if not isinstance(record, dict):
            raise ValueError(f"{country} market record must be an object")
        fetched[country] = {}
        for field in FIELDS:
            if field not in record:
                continue
            observation_record = record[field]
            if not isinstance(observation_record, dict):
                raise ValueError(f"{country}.{field} must be an object")
            validate_observation(observation_record, field, as_of)
            fetched[country][field] = observation_record
    return fetched
