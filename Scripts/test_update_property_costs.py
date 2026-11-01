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
        self.assertEqual(len(catalog["countries"]), 14)
        self.assertEqual(len(catalog["contentDigest"]), 64)
        self.assertNotIn("investmentReturn", catalog)
        canada = catalog["countries"]["canada"]
        self.assertEqual(canada["priceToRentYears"], 18)
        self.assertNotIn("confidence", canada)
        self.assertNotIn("methodologyNote", canada)
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
