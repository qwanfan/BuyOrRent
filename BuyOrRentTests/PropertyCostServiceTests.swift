import XCTest
@testable import BuyOrRent

final class PropertyCostServiceTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-10-29T05:00:00Z")!

    func testSeedCoversEveryCountry() {
        for country in Country.allCases {
            XCTAssertNotNil(PropertyCostService.seed[country], country.englishName)
        }
        let china = PropertyCostService.seedRates(for: .chinaMainland)
        XCTAssertEqual(china.buyingCostRate, 0.025, accuracy: 0.000_1)
        XCTAssertEqual(china.sellingCostRate, 0.025, accuracy: 0.000_1)
        XCTAssertEqual(china.propertyTaxRate, 0, accuracy: 0.000_1)
        XCTAssertEqual(PropertyCostService.seedRates(for: .singapore).buyingCostRate, 0.040, accuracy: 0.000_1)
    }

    func testFetchValidatesCachesAndResolvesRemoteCatalog() async throws {
        let defaults = isolatedDefaults()
        let data = catalogData(countries: [
            "unitedStates": record(propertyTax: 0.012, buying: 0.031, selling: 0.056)
        ])
        let service = PropertyCostService(
            now: { self.now },
            fetchData: { _ in data },
            cacheDefaults: defaults
        )

        let catalog = try await service.fetchCatalog()
        XCTAssertEqual(catalog.datasetVersion, "2026.10.29")
        XCTAssertEqual(service.cachedCatalog(), catalog)
        XCTAssertFalse(service.isCheckDue(for: .unitedStates))

        let resolution = service.resolvedRates(for: .unitedStates)
        XCTAssertEqual(resolution.origin, .cache)
        XCTAssertEqual(resolution.rates.propertyTaxRate, 0.012, accuracy: 0.000_1)
        XCTAssertEqual(resolution.sourceNames, ["Official source"])
    }

    func testThirtyDayCheckBoundary() async throws {
        let defaults = isolatedDefaults()
        let data = catalogData(countries: [
            "canada": record(propertyTax: 0.011, buying: 0.03, selling: 0.05)
        ])
        let initial = PropertyCostService(
            now: { self.now },
            fetchData: { _ in data },
            cacheDefaults: defaults
        )
        _ = try await initial.fetchCatalog()

        let beforeBoundary = PropertyCostService(
            now: { self.now.addingTimeInterval(30 * 24 * 3600 - 1) },
            cacheDefaults: defaults
        )
        XCTAssertFalse(beforeBoundary.isCheckDue(for: .canada))

        let atBoundary = PropertyCostService(
            now: { self.now.addingTimeInterval(30 * 24 * 3600) },
            cacheDefaults: defaults
        )
        XCTAssertTrue(atBoundary.isCheckDue(for: .canada))
    }

    func testMissingCountryFallsBackToSeed() async throws {
        let defaults = isolatedDefaults()
        let service = PropertyCostService(
            now: { self.now },
            fetchData: { _ in
                self.catalogData(countries: [
                    "unitedStates": self.record(propertyTax: 0.012, buying: 0.03, selling: 0.05)
                ])
            },
            cacheDefaults: defaults
        )
        _ = try await service.fetchCatalog()

        let canada = service.resolvedRates(for: .canada)
        XCTAssertEqual(canada.origin, .seed)
        XCTAssertEqual(canada.rates, PropertyCostService.seedRates(for: .canada))
        XCTAssertTrue(service.isCheckDue(for: .canada))
    }

    func testRejectsMalformedAndOutOfRangeCatalogs() {
        XCTAssertThrowsError(try PropertyCostService.parse(Data("{}".utf8))) { error in
            XCTAssertEqual(error as? PropertyCostError, .parseFailed)
        }

        let data = catalogData(countries: [
            "italy": record(propertyTax: 0.5, buying: 0.03, selling: 0.03)
        ])
        let catalog = try! PropertyCostService.parse(data)
        XCTAssertThrowsError(try PropertyCostService.validate(catalog, now: now)) { error in
            XCTAssertEqual(error as? PropertyCostError, .invalidRate)
        }
    }

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
    }

    private func record(propertyTax: Double, buying: Double, selling: Double) -> [String: Any] {
        [
            "propertyTaxRate": propertyTax,
            "buyingCostRate": buying,
            "sellingCostRate": selling,
            "verifiedAt": "2026-10-29",
            "confidence": "medium",
            "methodologyNote": "Representative owner occupied home",
            "sources": [
                [
                    "name": "Official source",
                    "url": "https://example.gov/property"
                ]
            ]
        ]
    }

    private func catalogData(countries: [String: [String: Any]]) -> Data {
        let object: [String: Any] = [
            "schemaVersion": 1,
            "datasetVersion": "2026.10.29",
            "publishedAt": "2026-10-29T05:00:00Z",
            "checkedAt": "2026-10-29T05:00:00Z",
            "nextReviewAt": "2027-01-29",
            "methodology": "Representative owner occupied ordinary residential property costs.",
            "contentDigest": String(repeating: "a", count: 64),
            "countries": countries
        ]
        return try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
