from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "Scripts" / "update_property_costs.py"
SOURCES = ROOT / "Data" / "property-cost-sources.json"
NUMBEO_NAMES = {
    "unitedStates": "United States",
    "chinaMainland": "China",
    "germany": "Germany",
    "japan": "Japan",
    "india": "India",
    "unitedKingdom": "United Kingdom",
    "france": "France",
    "italy": "Italy",
    "russia": "Russia",
    "canada": "Canada",
    "brazil": "Brazil",
    "mexico": "Mexico",
    "southKorea": "South Korea",
    "spain": "Spain",
    "australia": "Australia",
    "netherlands": "Netherlands",
    "saudiArabia": "Saudi Arabia",
    "turkey": "Turkey",
    "indonesia": "Indonesia",
    "switzerland": "Switzerland",
}


def load_generator():
    spec = importlib.util.spec_from_file_location("update_property_costs", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def sample_observation(rate: float, name: str, period: str = "2026-06") -> dict:
    return {
        "rate": rate,
        "periodLabel": period,
        "sourceName": name,
        "sourceUrl": "https://example.com/source",
    }


def sample_market() -> dict:
    """用源表种子附近的值，避免相对种子的跳变校验失败。"""
    source_data = json.loads(SOURCES.read_text(encoding="utf-8"))
    market: dict = {}
    for country in NUMBEO_NAMES:
        record = source_data["countries"][country]
        # 周期用新近标签，避免 live validate 的 24 个月新鲜度卡住旧种子区间。
        block: dict = {}
        if isinstance(record.get("mortgageRate"), dict):
            block["mortgageRate"] = sample_observation(
                float(record["mortgageRate"]["rate"]), "Mortgage"
            )
        if isinstance(record.get("rentGrowth"), dict):
            block["rentGrowth"] = sample_observation(
                float(record["rentGrowth"]["rate"]), "Rent"
            )
        if isinstance(record.get("appreciation"), dict):
            block["appreciation"] = sample_observation(
                float(record["appreciation"]["rate"]), "Prices"
            )
        market[country] = block
    return market


class UpdatePropertyCostsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.generator = load_generator()

    def run_generator(
        self,
        source_data: dict,
        previous_data: dict | None = None,
        market_data: dict | None = None,
    ) -> tuple[subprocess.CompletedProcess[str], Path, tempfile.TemporaryDirectory[str]]:
        temporary = tempfile.TemporaryDirectory()
        directory = Path(temporary.name)
        sources = directory / "sources.json"
        output = directory / "property-costs.json"
        previous = directory / "previous.json"
        market = directory / "market.json"
        equity = directory / "equity-index-returns.json"
        sources.write_text(json.dumps(source_data), encoding="utf-8")
        market.write_text(json.dumps(market_data or sample_market()), encoding="utf-8")
        equity.write_text(
            json.dumps(
                {
                    "schemaVersion": 1,
                    "publishedAt": "2026-10-29T05:00:00Z",
                    "fetchedOn": "2026-10-29",
                    "methodology": "fixture",
                    "countries": {
                        country: {
                            "rate": 0.04,
                            "startDate": "2016-10-28",
                            "endDate": "2026-10-28",
                            "sourceName": "Fixture",
                        }
                        for country in NUMBEO_NAMES
                    },
                }
            ),
            encoding="utf-8",
        )
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
                "--market-json",
                str(market),
                "--equity-json",
                str(equity),
                "--equity-output",
                str(directory / "equity-out.json"),
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
        self.assertEqual(len(catalog["countries"]), 20)
        self.assertEqual(len(catalog["contentDigest"]), 64)
        self.assertNotIn("investmentReturn", catalog)
        canada = catalog["countries"]["canada"]
        self.assertEqual(canada["priceToRentYears"], 17.2)
        self.assertNotIn("confidence", canada)
        self.assertNotIn("methodologyNote", canada)
        self.assertEqual(canada["mortgageRate"]["sourceName"], "Mortgage")
        self.assertEqual(
            canada["rentGrowth"]["rate"],
            source_data["countries"]["canada"]["rentGrowth"]["rate"],
        )
        self.assertEqual(canada["appreciation"]["periodLabel"], "2026-06")
        self.assertIn("sourcesByField", canada)
        self.assertEqual(
            canada["sourcesByField"]["propertyTaxRate"]["name"],
            source_data["countries"]["canada"]["sourcesByField"]["propertyTaxRate"]["name"],
        )
        self.assertNotIn("url", canada["sourcesByField"]["propertyTaxRate"])
        self.assertEqual(canada["sourcesByField"]["mortgageRate"]["name"], "Mortgage")
        self.assertIn("url", canada["sourcesByField"]["mortgageRate"])
        self.assertEqual(canada["sourcesByField"]["mortgageRate"]["asOf"], "2026-06")
        self.assertNotIn("periodLabel", canada["sourcesByField"]["mortgageRate"])
        for field in ("mortgageRate", "rentGrowth", "appreciation"):
            self.assertIn(field, canada)
            self.assertIn("sourceName", canada[field])

    def test_allows_market_source_without_url(self) -> None:
        source_data = json.loads(SOURCES.read_text(encoding="utf-8"))
        source_data["countries"]["india"]["sourcesByField"]["mortgageRate"].pop("url", None)
        self.generator.validate_sources(source_data)
        seeds = self.generator.market_seeds_from_sources(source_data)
        self.assertNotIn("sourceUrl", seeds["india"]["mortgageRate"])

    def test_allows_empty_provenance_and_missing_market_seed(self) -> None:
        source_data = json.loads(SOURCES.read_text(encoding="utf-8"))
        # 构造「有出处名但缺种子」应失败；缺种子且出处为空应通过。
        source_data["countries"]["indonesia"].pop("mortgageRate", None)
        source_data["countries"]["indonesia"]["sourcesByField"]["mortgageRate"] = {"name": ""}
        self.generator.validate_sources(source_data)
        source_data["countries"]["indonesia"]["sourcesByField"]["mortgageRate"] = {
            "name": "Named",
            "asOf": "2026-09",
        }
        with self.assertRaisesRegex(ValueError, "seed is required when provenance is set"):
            self.generator.validate_sources(source_data)

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

    def test_uses_sources_seed_when_fetch_is_missing(self) -> None:
        source_data = json.loads(SOURCES.read_text(encoding="utf-8"))
        seed_rate = source_data["countries"]["italy"]["mortgageRate"]["rate"]
        market = sample_market()
        del market["italy"]["mortgageRate"]
        result, output, temporary = self.run_generator(source_data, market_data=market)
        self.addCleanup(temporary.cleanup)
        self.assertEqual(result.returncode, 0, result.stderr)
        catalog = json.loads(output.read_text(encoding="utf-8"))
        self.assertEqual(catalog["countries"]["italy"]["mortgageRate"]["rate"], seed_rate)
        self.assertIn("using sources seed", result.stderr)

    def test_keeps_previous_when_fetch_and_seed_are_missing(self) -> None:
        source_data = json.loads(SOURCES.read_text(encoding="utf-8"))
        initial, output, first = self.run_generator(source_data)
        self.addCleanup(first.cleanup)
        self.assertEqual(initial.returncode, 0, initial.stderr)
        previous = json.loads(output.read_text(encoding="utf-8"))
        del source_data["countries"]["italy"]["mortgageRate"]
        market = sample_market()
        del market["italy"]["mortgageRate"]
        # validate_sources now requires seeds; bypass by injecting after load isn't possible,
        # so call assemble directly for this fallback path.
        as_of = __import__("datetime").date.today()
        assembled = self.generator.market_series.assemble_market_series(
            {"italy": {"rentGrowth": market["italy"]["rentGrowth"], "appreciation": market["italy"]["appreciation"]}},
            previous,
            {"italy"},
            as_of,
            seeds={"italy": {}},
        )
        self.assertEqual(assembled["italy"]["mortgageRate"]["rate"], previous["countries"]["italy"]["mortgageRate"]["rate"])

    def test_uses_sources_seed_for_appreciation_when_fetch_missing(self) -> None:
        source_data = json.loads(SOURCES.read_text(encoding="utf-8"))
        seed = source_data["countries"]["japan"]["appreciation"]
        market = sample_market()
        del market["japan"]["appreciation"]
        result, output, temporary = self.run_generator(source_data, market_data=market)
        self.addCleanup(temporary.cleanup)
        self.assertEqual(result.returncode, 0, result.stderr)
        catalog = json.loads(output.read_text(encoding="utf-8"))
        self.assertEqual(catalog["countries"]["japan"]["appreciation"]["rate"], seed["rate"])
        self.assertIn("mortgageRate", catalog["countries"]["japan"])

    def test_rejects_large_mortgage_rate_jump(self) -> None:
        source_data = json.loads(SOURCES.read_text(encoding="utf-8"))
        initial, output, first = self.run_generator(source_data)
        self.addCleanup(first.cleanup)
        self.assertEqual(initial.returncode, 0, initial.stderr)
        market = sample_market()
        base = market["unitedStates"]["mortgageRate"]["rate"]
        market["unitedStates"]["mortgageRate"]["rate"] = round(base + 0.03, 4)
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
