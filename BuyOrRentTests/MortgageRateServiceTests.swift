import XCTest
@testable import BuyOrRent

final class MortgageRateServiceTests: XCTestCase {
    private let fetchedAt = Date(timeIntervalSince1970: 1_793_548_800) // 2026-10-29

    func testParseFREDCSV() throws {
        let csv = "DATE,MORTGAGE30US\n2026-10-15,7.40\n2026-10-22,7.32\n"
        let quote = try MortgageRateService.parseFREDCSV(Data(csv.utf8), sourceName: "US", fetchedAt: fetchedAt)
        XCTAssertEqual(quote.rate, 0.0732, accuracy: 0.000_001)
        XCTAssertEqual(quote.periodLabel, "2026-10-22")
    }

    func testParseFREDCSVSkipsMissingValues() {
        let csv = "DATE,MORTGAGE30US\n2026-10-22,.\n"
        XCTAssertThrowsError(try MortgageRateService.parseFREDCSV(Data(csv.utf8), sourceName: "US", fetchedAt: fetchedAt))
    }

    func testParseBankOfCanadaJSON() throws {
        let json = #"{"observations":[{"d":"2026-10-21","V80691335":{"v":"4.99"}}]}"#
        let quote = try MortgageRateService.parseBankOfCanadaJSON(Data(json.utf8), sourceName: "CA", fetchedAt: fetchedAt)
        XCTAssertEqual(quote.rate, 0.0499, accuracy: 0.000_001)
    }

    func testParseECBJSON() throws {
        let json = #"{"dataSets":[{"series":{"0":{"observations":{"3":[3.84]}}}}],"structure":{"dimensions":{"observation":[{"id":"TIME_PERIOD","values":[{"id":"2026-05"},{"id":"2026-06"},{"id":"2026-07"},{"id":"2026-08"}]}]}}}"#
        let quote = try MortgageRateService.parseECBJSON(Data(json.utf8), sourceName: "ECB", fetchedAt: fetchedAt)
        XCTAssertEqual(quote.rate, 0.0384, accuracy: 0.000_001)
        XCTAssertEqual(quote.periodLabel, "2026-08")
    }

    func testParseSNBCSV() throws {
        let csv = "\"Date\";\"D0\";\"D1\";\"Value\"\n\"2026-08\";\"M\";\"MV\";2.79\n\"2026-09\";\"M\";\"MV\";2.81\n"
        let quote = try MortgageRateService.parseSNBCSV(Data(csv.utf8), sourceName: "SNB", fetchedAt: fetchedAt)
        XCTAssertEqual(quote.rate, 0.0281, accuracy: 0.000_001)
        XCTAssertEqual(quote.periodLabel, "2026-09")
    }

    func testParseLPRJSON() throws {
        let json = #"{"data":{"records":[{"5Y":"3.50","1Y":"3.00","showDateCN":"2026-10-20"}]}}"#
        let quote = try MortgageRateService.parseLPRJSON(Data(json.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(quote.rate, 0.035, accuracy: 0.000_001)
        XCTAssertEqual(quote.sourceName, "5 年期以上 LPR")
    }

    func testParseLPRJSONReadsNewestTopLevelRecord() throws {
        let json = #"{"data":{"endDateCN":"2026-10-29"},"records":[{"5Y":"3.50","1Y":"3.00","showDateCN":"2026-10-20"},{"5Y":"3.45","1Y":"3.00","showDateCN":"2026-09-20"}]}"#
        let quote = try MortgageRateService.parseLPRJSON(Data(json.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(quote.rate, 0.035, accuracy: 0.000_001)
        XCTAssertEqual(quote.periodLabel, "2026-10-20")
    }

    func testParseHIBORJSON() throws {
        let json = #"{"result":{"records":[{"end_of_day":"2026-10-28","ir_1m":3.00518}]}}"#
        let quote = try MortgageRateService.parseHIBORJSON(Data(json.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(quote.rate, 0.0300518, accuracy: 0.000_0001)
    }

    func testParseSORAJSONPicksLatestMonth() throws {
        let json = #"{"result":{"records":[{"DataSeries":"Compounded Singapore Overnight Rate Average (SORA) - 3 Month","2026Aug":1.1863,"2026Sep":1.2336}]}}"#
        let quote = try MortgageRateService.parseSORAJSON(Data(json.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(quote.rate, 0.012336, accuracy: 0.000_001)
        XCTAssertEqual(quote.periodLabel, "2026Sep")
    }

    func testParseFlat35HTML() throws {
        let html = "<html><body>【フラット３５】金利情報 ※2026年10月現在 返済期間 15 年 ～ 20 年 年 3.51 % ～ 年 5.52 % 年 3.51 % 21 年 ～ 35 年 年 3.83 % ～ 年 5.84 % 年 3.83 %</body></html>"
        let quote = try MortgageRateService.parseFlat35HTML(Data(html.utf8), sourceName: "Flat 35", fetchedAt: fetchedAt)
        XCTAssertEqual(quote.rate, 0.0383, accuracy: 0.000_001)
        XCTAssertEqual(quote.periodLabel, "2026-10")
    }

    func testParseRejectsHTMLForCSVSource() {
        let html = "<html><body>blocked</body></html>"
        XCTAssertThrowsError(try MortgageRateService.parseFREDCSV(Data(html.utf8), sourceName: "US", fetchedAt: fetchedAt))
        XCTAssertThrowsError(try MortgageRateService.parseBoECSV(Data(html.utf8), sourceName: "UK", fetchedAt: fetchedAt))
    }

    func testValidateRejectsInvalidAndStaleRates() {
        let now = fetchedAt
        let invalid = MortgageRateQuote(rate: 0.25, periodLabel: "2026-10", periodDate: now, sourceName: "x", fetchedAt: now)
        XCTAssertThrowsError(try MortgageRateService.validate(invalid, now: now)) { error in
            XCTAssertEqual(error as? MortgageRateError, .invalidRate)
        }
        let staleDate = Calendar(identifier: .gregorian).date(byAdding: .month, value: -30, to: now)!
        let stale = MortgageRateQuote(rate: 0.05, periodLabel: "old", periodDate: staleDate, sourceName: "x", fetchedAt: now)
        XCTAssertThrowsError(try MortgageRateService.validate(stale, now: now)) { error in
            XCTAssertEqual(error as? MortgageRateError, .staleData)
        }
    }

    func testFetchQuoteCachesResult() async throws {
        let defaults = UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        let csv = "DATE,MORTGAGE30US\n2026-10-22,7.32\n"
        let service = MortgageRateService(
            now: { self.fetchedAt },
            fetchData: { _ in Data(csv.utf8) },
            cacheDefaults: defaults
        )
        let quote = try await service.fetchQuote(for: .unitedStates)
        XCTAssertEqual(quote.rate, 0.0732, accuracy: 0.000_001)
        XCTAssertEqual(service.cachedQuote(for: .unitedStates)?.rate, 0.0732)
    }
}
