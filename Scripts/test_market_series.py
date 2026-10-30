from __future__ import annotations

import importlib.util
import json
import unittest
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "Scripts" / "market_series.py"


def load_module():
    spec = importlib.util.spec_from_file_location("market_series", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class MarketSeriesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.series = load_module()

    def test_fred_and_lpr_and_hibor_spread(self) -> None:
        fred = self.series.parse_fred_csv(
            "DATE,MORTGAGE30US\n2026-10-15,.\n2026-10-22,6.50\n",
            "Freddie Mac",
            "https://fred.stlouisfed.org/series/MORTGAGE30US",
        )
        self.assertEqual(fred["rate"], 0.065)
        self.assertEqual(fred["periodLabel"], "2026-10-22")

        lpr = self.series.parse_lpr_json(
            {"records": [{"5Y": "3.50", "showDateCN": "2026-10-20"}]},
            "5 年期以上 LPR",
            "https://www.chinamoney.com.cn/dqs/rest/cm-u-bk-currency/LprHis",
        )
        self.assertEqual(lpr["rate"], 0.035)

        hibor = self.series.parse_hibor_json(
            {"result": {"records": [{"end_of_day": "2026-10-22", "ir_1m": 3.2}]}},
            "1 个月 HIBOR",
            "https://api.hkma.gov.hk/public/market-data-and-statistics/monthly-statistical-bulletin/er-ir/hk-interbank-ir-daily",
        )
        priced = self.series.apply_spread(hibor, 0.013, "1 个月 HIBOR + 预设利差估算")
        self.assertEqual(priced["rate"], 0.045)
        self.assertEqual(priced["sourceName"], "1 个月 HIBOR + 预设利差估算")

    def test_rent_parsers_keep_their_own_sources(self) -> None:
        oecd = self.series.parse_oecd_csv(
            "REF_AREA,TIME_PERIOD,OBS_VALUE\nUSA,2024,5.1\nUSA,2025,4.2\n",
            "USA",
            "OECD 实际房租",
            "https://sdmx.oecd.org/public/rest/data/OECD.SDD.TPS,DSD_PRICES@DF_PRICES_ALL,1.0",
        )
        self.assertEqual(oecd["periodLabel"], "2025")
        self.assertEqual(oecd["rate"], 0.042)

        lines = ["類・品目符号(Group/Item code),0001,3000"]
        for month in range(1, 13):
            lines.append(f"2024{month:02d},0,100")
            lines.append(f"2025{month:02d},0,100.5")
        japan = self.series.parse_japan_cpi(
            "\n".join(lines),
            "总务省民营房租",
            "https://www.stat.go.jp/data/cpi/2020/csv/zmi2020aa.csv",
        )
        self.assertAlmostEqual(japan["rate"], 0.005, places=4)

        listing = """<a href="./202610/t20261014_1965477.html" title='2026年9月份居民消费价格同比上涨0.9%'>"""
        self.assertEqual(
            self.series.china_release_url(listing),
            "https://www.stats.gov.cn/sj/zxfb/202610/t20261014_1965477.html",
        )
        china = self.series.parse_china_html(
            "<h1>2026年9月份</h1><td>租赁房房租</td><td>-0.1</td><td>-0.6</td><td>-0.6</td>",
            "国家统计局租赁房房租",
            "https://www.stats.gov.cn/sj/zxfb/202610/t20261014_1965477.html",
        )
        self.assertEqual(china["rate"], -0.006)
        self.assertEqual(china["periodLabel"], "2026-09")

        issue = self.series.hong_kong_issue({
            "productIndex": [
                {"Product_Code": "OTHER", "issue": "August 2026"},
                {"Product_Code": "B1060001", "issue": "September 2026"},
            ]
        })
        self.assertEqual(issue, (2026, 9))
        hong_kong = self.series.parse_hong_kong_rent_text(
            "101.9 +0.4 102.5 +0.3 101.8 +0.4 101.2 +0.3 Private housing rent",
            "2026-09",
            "统计处私人住宅租金",
            "https://www.censtatd.gov.hk/wbr/B1060001/example.pdf",
        )
        self.assertEqual(hong_kong["rate"], 0.004)

        singapore = self.series.parse_singapore_rent(
            {"result": {"records": [{
                "DataSeries": "Rental Index Of Residential Properties",
                "20262Q": 162.5,
                "20252Q": 159.8,
            }]}},
            "市区重建局私人住宅租金指数",
            "https://data.gov.sg/api/action/datastore_search",
        )
        self.assertEqual(singapore["periodLabel"], "2026-Q2")
        self.assertAlmostEqual(singapore["rate"], 162.5 / 159.8 - 1, places=4)

    def test_bis_ten_year_compound_growth(self) -> None:
        quote = self.series.parse_bis_csv(
            "REF_AREA,TIME_PERIOD,OBS_VALUE\nUS,2016-Q2,100\nUS,2020-Q1,120\nUS,2026-Q2,150\n",
            "US",
            "国际清算银行选定住宅房价",
            "https://stats.bis.org/api/v1/data/WS_SPP",
        )
        self.assertEqual(quote["periodLabel"], "2016-Q2\u20132026-Q2")
        self.assertAlmostEqual(quote["rate"], 1.5 ** 0.1 - 1, places=4)
        self.assertEqual(quote["sourceName"], "国际清算银行选定住宅房价")
        self.assertEqual(self.series.period_date(quote["periodLabel"]), date(2026, 6, 30))

    def test_bis_requires_the_index_ten_years_earlier(self) -> None:
        with self.assertRaises(ValueError):
            self.series.parse_bis_csv(
                "REF_AREA,TIME_PERIOD,OBS_VALUE\nUS,2026-Q2,150\n",
                "US",
                "国际清算银行选定住宅房价",
                "https://stats.bis.org/api/v1/data/WS_SPP",
            )

    def test_appreciation_jump_check_skips_single_quarter_history(self) -> None:
        as_of = date(2026, 10, 31)
        fresh = {
            "rate": 0.04,
            "periodLabel": "2016-Q2\u20132026-Q2",
            "sourceName": "国际清算银行选定住宅房价",
            "sourceUrl": "https://stats.bis.org/api/v1/data/WS_SPP",
        }
        previous = {
            "countries": {
                "unitedStates": {
                    "appreciation": {
                        "rate": 0.20,
                        "periodLabel": "2026-Q2",
                        "sourceName": "国际清算银行选定住宅房价",
                        "sourceUrl": "https://stats.bis.org/api/v1/data/WS_SPP",
                    }
                }
            }
        }
        stable = {
            "rate": 0.05,
            "periodLabel": "2026-06",
            "sourceName": "官方来源",
            "sourceUrl": "https://example.com/source",
        }
        assembled = self.series.assemble_market_series(
            {"unitedStates": {
                "appreciation": fresh,
                "mortgageRate": dict(stable, rate=0.06),
                "rentGrowth": stable,
            }},
            previous,
            {"unitedStates"},
            as_of,
        )
        self.assertEqual(assembled["unitedStates"]["appreciation"]["rate"], 0.04)

    def test_rejects_stale_or_out_of_range_observation(self) -> None:
        as_of = date(2026, 10, 31)
        fresh = {
            "rate": -0.006,
            "periodLabel": "2026-09",
            "sourceName": "国家统计局租赁房房租",
            "sourceUrl": "https://www.stats.gov.cn/sj/zxfb/",
        }
        self.series.validate_observation(fresh, "rentGrowth", as_of)
        stale = dict(fresh, periodLabel="2023")
        with self.assertRaises(ValueError):
            self.series.validate_observation(stale, "rentGrowth", as_of)
        out_of_range = dict(fresh, rate=-0.06)
        with self.assertRaises(ValueError):
            self.series.validate_observation(out_of_range, "rentGrowth", as_of)

    def test_sora_latest_month(self) -> None:
        payload = {"result": {"records": [{
            "DataSeries": "Compound SORA (SORA) - 3 Month",
            "2026Aug": 1.5,
            "2026Sep": 1.7,
        }]}}
        quote = self.series.parse_sora_json(
            payload,
            "3 个月 SORA + 预设利差估算",
            "https://data.gov.sg/api/action/datastore_search",
        )
        self.assertEqual(quote["periodLabel"], "2026Sep")
        self.assertEqual(quote["rate"], 0.017)

    def test_rba_prefers_new_owner_occupier_loans(self) -> None:
        csv = "\n".join([
            "Title,outstanding,new loans",
            "Series ID,FLRHOOTL,FLRHOFTA",
            "31/07/2026,6.4,5.8",
            "31/08/2026,6.2,5.9",
        ])
        quote = self.series.parse_rba_csv(
            csv,
            "澳洲央行新发放自住房贷利率",
            "https://www.rba.gov.au/statistics/tables/csv/f6-data.csv",
        )
        self.assertEqual(quote["rate"], 0.059)
        self.assertEqual(quote["periodLabel"], "31/08/2026")

    def test_hong_kong_rent_text_without_column_spaces(self) -> None:
        quote = self.series.parse_hong_kong_rent_text(
            "101.9 +0.4102.5 +0.3101.8 +0.4101.2 +0.3 Private housing rent",
            "2026-09",
            "统计处私人住宅租金",
            "https://www.censtatd.gov.hk/wbr/B1060001/example.pdf",
        )
        self.assertEqual(quote["rate"], 0.004)


if __name__ == "__main__":
    unittest.main()
