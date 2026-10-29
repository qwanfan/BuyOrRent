from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "Scripts" / "update_property_costs.py"
SOURCES = ROOT / "Data" / "property-cost-sources.json"


class UpdatePropertyCostsTests(unittest.TestCase):
    def run_generator(
        self,
        source_data: dict,
        previous_data: dict | None = None,
    ) -> tuple[subprocess.CompletedProcess[str], Path, tempfile.TemporaryDirectory[str]]:
        temporary = tempfile.TemporaryDirectory()
        directory = Path(temporary.name)
        sources = directory / "sources.json"
        output = directory / "property-costs.json"
        previous = directory / "previous.json"
        sources.write_text(json.dumps(source_data), encoding="utf-8")
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


if __name__ == "__main__":
    unittest.main()
