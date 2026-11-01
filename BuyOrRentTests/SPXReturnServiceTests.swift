import XCTest
@testable import BuyOrRent

final class SPXReturnServiceTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testTrailingTenYearPriceReturn() throws {
        let csv = """
        observation_date,SP500
        2016-10-28,2000
        2026-10-28,4000
        """
        let asOf = calendar.date(from: DateComponents(year: 2026, month: 10, day: 29))!
        let quote = try SPXReturnParser.parse(csv, asOf: asOf, calendar: calendar)
        XCTAssertEqual(quote.rate, 0.0718, accuracy: 0.000_000_1)
        XCTAssertEqual(quote.startDate, "2016-10-28")
        XCTAssertEqual(quote.endDate, "2026-10-28")
        XCTAssertEqual(quote.sourceName, "FRED：S&P 500")
    }

    func testRejectsSeriesThatDoesNotCoverTenYears() {
        let csv = "observation_date,SP500\n2026-01-02,5000\n2026-10-28,5100\n"
        let asOf = calendar.date(from: DateComponents(year: 2026, month: 10, day: 29))!
        XCTAssertThrowsError(try SPXReturnParser.parse(csv, asOf: asOf, calendar: calendar)) { error in
            XCTAssertEqual(error as? SPXReturnError, .insufficient)
        }
    }

    func testFetchStoresCacheAndFailureKeepsIt() async throws {
        let defaults = UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        let csv = Data("observation_date,SP500\n2016-10-28,2000\n2026-10-28,4000\n".utf8)
        let asOf = calendar.date(from: DateComponents(year: 2026, month: 10, day: 29))!
        let service = SPXReturnService(
            now: { asOf },
            fetchData: { _ in csv },
            cacheDefaults: defaults
        )
        let quote = try await service.fetchQuote()
        XCTAssertEqual(quote.rate, 0.0718, accuracy: 0.000_000_1)
        XCTAssertEqual(service.cachedQuote()?.endDate, "2026-10-28")

        let failing = SPXReturnService(
            now: { asOf },
            fetchData: { _ in throw SPXReturnError.unreadable },
            cacheDefaults: defaults
        )
        do {
            _ = try await failing.fetchQuote()
            XCTFail("Expected the second fetch to fail")
        } catch {
            XCTAssertEqual(failing.cachedQuote()?.rate ?? 0, 0.0718, accuracy: 0.000_000_1)
        }
    }
}
