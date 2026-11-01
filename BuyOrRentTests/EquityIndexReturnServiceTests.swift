import XCTest
@testable import BuyOrRent

final class EquityIndexReturnServiceTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testParseAndValidateCatalog() throws {
        let catalog = try EquityIndexReturnService.parse(Self.catalogData())
        try EquityIndexReturnService.validate(catalog)
        XCTAssertEqual(catalog.schemaVersion, 1)
        XCTAssertEqual(catalog.countries["unitedStates"]?.rate ?? 0, 0.0718, accuracy: 0.000_000_1)
        XCTAssertEqual(catalog.countries["chinaMainland"]?.sourceName, "Yahoo Finance：沪深 300")
    }

    func testRejectsEmptyCountries() {
        let data = Self.catalogData(countries: [:])
        XCTAssertThrowsError(try EquityIndexReturnService.validate(try EquityIndexReturnService.parse(data))) { error in
            XCTAssertEqual(error as? EquityIndexReturnError, .emptyBatch)
        }
    }

    func testRejectsInvalidRate() {
        let data = Self.catalogData(countries: [
            "unitedStates": [
                "rate": 0.9,
                "startDate": "2016-10-28",
                "endDate": "2026-10-28",
                "sourceName": "Yahoo Finance：S&P 500",
            ]
        ])
        XCTAssertThrowsError(try EquityIndexReturnService.validate(try EquityIndexReturnService.parse(data))) { error in
            XCTAssertEqual(error as? EquityIndexReturnError, .invalidRate)
        }
    }

    func testFetchCachesAndSkipsSameDay() async throws {
        let defaults = UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        let asOf = calendar.date(from: DateComponents(year: 2026, month: 10, day: 29))!
        var requestCount = 0
        let service = EquityIndexReturnService(
            now: { asOf },
            fetchData: { _ in
                requestCount += 1
                return Self.catalogData()
            },
            bundledData: { nil },
            cacheDefaults: defaults,
            calendar: calendar
        )

        _ = try await service.fetchAllIfNeeded(force: false)
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(service.quote(for: .unitedStates)?.rate ?? 0, 0.0718, accuracy: 0.000_000_1)
        XCTAssertEqual(service.quote(for: .chinaMainland)?.sourceName, "Yahoo Finance：沪深 300")
        XCTAssertTrue(service.fetchedOnToday())
        XCTAssertEqual(service.cachedCatalog()?.fetchedOn, "2026-10-29")

        _ = try await service.fetchAllIfNeeded(force: false)
        XCTAssertEqual(requestCount, 1)

        _ = try await service.fetchAllIfNeeded(force: true)
        XCTAssertEqual(requestCount, 2)
    }

    func testFallsBackToBundledWhenCacheMissing() {
        let service = EquityIndexReturnService(
            fetchData: { _ in throw EquityIndexReturnError.unreadable },
            bundledData: { Self.catalogData() },
            cacheDefaults: UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        )
        XCTAssertEqual(service.resolvedRate(for: .unitedStates), 0.0718, accuracy: 0.000_000_1)
        XCTAssertEqual(service.quote(for: .chinaMainland)?.rate ?? 0, 0.0414, accuracy: 0.000_1)
    }

    func testSeedUsedWhenNoCacheOrBundle() {
        let service = EquityIndexReturnService(
            bundledData: { nil },
            cacheDefaults: UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        )
        XCTAssertEqual(service.resolvedRate(for: .unitedStates), 0.1355, accuracy: 0.000_000_1)
        XCTAssertEqual(service.resolvedRate(for: .chinaMainland), 0.0179, accuracy: 0.000_000_1)
        XCTAssertNil(service.quote(for: .unitedStates))
    }

    private static func catalogData(
        countries: [String: [String: Any]]? = nil
    ) -> Data {
        let defaultCountries: [String: [String: Any]] = [
            "chinaMainland": [
                "rate": 0.0414,
                "startDate": "2016-10-28",
                "endDate": "2026-10-28",
                "sourceName": "Yahoo Finance：沪深 300",
            ],
            "unitedStates": [
                "rate": 0.0718,
                "startDate": "2016-10-28",
                "endDate": "2026-10-28",
                "sourceName": "Yahoo Finance：S&P 500",
            ],
            "germany": [
                "rate": 0.05,
                "startDate": "2016-10-28",
                "endDate": "2026-10-28",
                "sourceName": "Yahoo Finance：DAX",
            ],
        ]
        let payload: [String: Any] = [
            "schemaVersion": 1,
            "publishedAt": "2026-10-29T05:00:00Z",
            "fetchedOn": "2026-10-01",
            "methodology": "Ten-year price CAGR",
            "countries": countries ?? defaultCountries,
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }
}
