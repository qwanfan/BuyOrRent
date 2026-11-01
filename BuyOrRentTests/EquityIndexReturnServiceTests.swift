import XCTest
@testable import BuyOrRent

final class EquityIndexReturnServiceTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testTrailingTenYearPriceReturnFromPoints() throws {
        let asOf = calendar.date(from: DateComponents(year: 2026, month: 10, day: 29))!
        let start = calendar.date(from: DateComponents(year: 2016, month: 10, day: 28))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 10, day: 28))!
        let quote = try EquityIndexReturnParser.trailingReturn(
            points: [(start, 2000), (end, 4000)],
            sourceName: "Yahoo Finance：S&P 500",
            asOf: asOf,
            calendar: calendar
        )
        XCTAssertEqual(quote.rate, 0.0718, accuracy: 0.000_000_1)
        XCTAssertEqual(quote.startDate, "2016-10-28")
        XCTAssertEqual(quote.endDate, "2026-10-28")
    }

    func testParseYahooChartJSON() throws {
        let asOf = calendar.date(from: DateComponents(year: 2026, month: 10, day: 29))!
        let start = calendar.date(from: DateComponents(year: 2016, month: 10, day: 28))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 10, day: 28))!
        let payload: [String: Any] = [
            "chart": [
                "result": [
                    [
                        "timestamp": [start.timeIntervalSince1970, end.timeIntervalSince1970],
                        "indicators": [
                            "quote": [
                                ["close": [2000.0, 4000.0]]
                            ]
                        ]
                    ]
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let quote = try EquityIndexReturnParser.parseChart(
            data,
            sourceName: "Yahoo Finance：沪深 300",
            asOf: asOf,
            calendar: calendar
        )
        XCTAssertEqual(quote.rate, 0.0718, accuracy: 0.000_000_1)
        XCTAssertEqual(quote.sourceName, "Yahoo Finance：沪深 300")
    }

    func testRejectsSeriesThatDoesNotCoverTenYears() {
        let asOf = calendar.date(from: DateComponents(year: 2026, month: 10, day: 29))!
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 10, day: 28))!
        XCTAssertThrowsError(
            try EquityIndexReturnParser.trailingReturn(
                points: [(start, 5000), (end, 5100)],
                sourceName: "Yahoo Finance：DAX",
                asOf: asOf,
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(error as? EquityIndexReturnError, .insufficient)
        }
    }

    func testFetchAllCachesByCountryAndSkipsSameDay() async throws {
        let defaults = UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        let asOf = calendar.date(from: DateComponents(year: 2026, month: 10, day: 29))!
        var requestCount = 0
        let service = EquityIndexReturnService(
            now: { asOf },
            fetchData: { url in
                requestCount += 1
                return Self.chartData(
                    start: Date(timeIntervalSince1970: 1_477_612_800),
                    end: Date(timeIntervalSince1970: 1_793_145_600),
                    startLevel: 2000,
                    endLevel: 4000
                )
            },
            sleepNanoseconds: { _ in },
            cacheDefaults: defaults,
            calendar: calendar
        )

        _ = try await service.fetchAllIfNeeded(force: false)
        XCTAssertEqual(requestCount, Country.allCases.count)
        XCTAssertEqual(service.quote(for: .unitedStates)?.rate ?? 0, 0.0718, accuracy: 0.000_000_1)
        XCTAssertEqual(service.quote(for: .chinaMainland)?.sourceName, "Yahoo Finance：沪深 300")
        XCTAssertTrue(service.fetchedOnToday())

        _ = try await service.fetchAllIfNeeded(force: false)
        XCTAssertEqual(requestCount, Country.allCases.count)

        _ = try await service.fetchAllIfNeeded(force: true)
        XCTAssertEqual(requestCount, Country.allCases.count * 2)
    }

    func testPartialFailureKeepsPreviousCountryQuote() async throws {
        let defaults = UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        let asOf = calendar.date(from: DateComponents(year: 2026, month: 10, day: 29))!
        var failUnitedStates = false
        let service = EquityIndexReturnService(
            now: { asOf },
            fetchData: { url in
                if failUnitedStates, url.absoluteString.contains("%5EGSPC") || url.absoluteString.contains("^GSPC") {
                    throw EquityIndexReturnError.unreadable
                }
                return Self.chartData(
                    start: Date(timeIntervalSince1970: 1_477_612_800),
                    end: Date(timeIntervalSince1970: 1_793_145_600),
                    startLevel: 1000,
                    endLevel: 2000
                )
            },
            sleepNanoseconds: { _ in },
            cacheDefaults: defaults,
            calendar: calendar
        )
        _ = try await service.fetchAllIfNeeded(force: true)
        XCTAssertEqual(service.quote(for: .unitedStates)?.rate ?? 0, 0.0718, accuracy: 0.000_000_1)

        failUnitedStates = true
        _ = try await service.fetchAllIfNeeded(force: true)
        XCTAssertEqual(service.quote(for: .unitedStates)?.rate ?? 0, 0.0718, accuracy: 0.000_000_1)
        XCTAssertNotNil(service.quote(for: .germany))
    }

    func testSeedUsedWhenNoCache() {
        let service = EquityIndexReturnService(
            cacheDefaults: UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        )
        XCTAssertEqual(service.resolvedRate(for: .unitedStates), 0.1377, accuracy: 0.000_000_1)
        XCTAssertEqual(service.resolvedRate(for: .chinaMainland), 0.04, accuracy: 0.000_000_1)
        XCTAssertNil(service.quote(for: .unitedStates))
    }

    private static func chartData(start: Date, end: Date, startLevel: Double, endLevel: Double) -> Data {
        let payload: [String: Any] = [
            "chart": [
                "result": [
                    [
                        "timestamp": [start.timeIntervalSince1970, end.timeIntervalSince1970],
                        "indicators": [
                            "quote": [
                                ["close": [startLevel, endLevel]]
                            ]
                        ]
                    ]
                ]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }
}
