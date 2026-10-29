#!/usr/bin/env python3
"""Validate a generated catalog against its public JSON Schema."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--schema",
        type=Path,
        default=Path("Data/property-costs-v1.schema.json"),
    )
    parser.add_argument(
        "--catalog",
        type=Path,
        default=Path("public/v1/property-costs.json"),
    )
    args = parser.parse_args()

    schema = json.loads(args.schema.read_text(encoding="utf-8"))
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    errors = sorted(validator.iter_errors(catalog), key=lambda item: list(item.path))
    if errors:
        for error in errors:
            location = ".".join(str(piece) for piece in error.path) or "<root>"
            print(f"{location}: {error.message}")
        return 1

    print(
        f"validated {catalog['datasetVersion']} "
        f"with {len(catalog['countries'])} countries"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
