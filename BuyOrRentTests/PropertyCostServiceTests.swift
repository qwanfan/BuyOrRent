import XCTest
@testable import BuyOrRent

final class PropertyCostServiceTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-10-31T00:00:00Z")!

    func testSeedCoversEveryCountry() {
        for country in Country.allCases {
            XCTAssertNotNil(PropertyCostService.seed[country], country.englishName)
        }
        let china = PropertyCostService.seedRates(for: .chinaMainland)
        XCTAssertEqual(china.buyingCostRate, 0.076, accuracy: 0.000_1)
        XCTAssertEqual(china.sellingCostRate, 0.01, accuracy: 0.000_1)
        XCTAssertEqual(china.propertyTaxRate, 0, accuracy: 0.000_1)
        XCTAssertEqual(PropertyCostService.seedRates(for: .singapore).buyingCostRate, 0.098, accuracy: 0.000_1)
    }

    func testFetchValidatesCachesAndResolvesRemoteCatalog() async throws {
        let defaults = isolatedDefaults()
        let data = catalogData(countries: [
            "unitedStates": record(propertyTax: 0.012, buying: 0.031, selling: 0.056)
        ])
        let service = PropertyCostService(
            now: { self.now },
            fetchData: { _ in data },
            bundledData: { nil },
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
            bundledData: { nil },
            cacheDefaults: defaults
        )
        _ = try await initial.fetchCatalog()

        let beforeBoundary = PropertyCostService(
            now: { self.now.addingTimeInterval(30 * 24 * 3600 - 1) },
            bundledData: { nil },
            cacheDefaults: defaults
        )
        XCTAssertFalse(beforeBoundary.isCheckDue(for: .canada))

        let atBoundary = PropertyCostService(
            now: { self.now.addingTimeInterval(30 * 24 * 3600) },
            bundledData: { nil },
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
            bundledData: { nil },
            cacheDefaults: defaults
        )
        _ = try await service.fetchCatalog()

        let canada = service.resolvedRates(for: .canada)
        XCTAssertEqual(canada.origin, .seed)
        XCTAssertEqual(canada.rates, PropertyCostService.seedRates(for: .canada))
        XCTAssertTrue(service.isCheckDue(for: .canada))
    }

    func testBundledCatalogMatchesSeedAndDefersNetwork() throws {
        let resource = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("BuyOrRent/Resources/property-costs.json")
        let data = try Data(contentsOf: resource)
        let catalog = try PropertyCostService.parse(data)
        let checked = try XCTUnwrap(ISO8601DateFormatter().date(from: catalog.checkedAt))
        try PropertyCostService.validate(catalog, now: checked)
        XCTAssertFalse(catalog.datasetVersion.isEmpty)
        XCTAssertEqual(catalog.countries.count, Country.allCases.count)

        for country in Country.allCases {
            let record = try XCTUnwrap(catalog.countries[country.rawValue])
            let seed = PropertyCostService.seedRates(for: country)
            XCTAssertEqual(record.propertyTaxRate, seed.propertyTaxRate, accuracy: 0.000_000_1, country.rawValue)
            XCTAssertEqual(record.buyingCostRate, seed.buyingCostRate, accuracy: 0.000_000_1, country.rawValue)
            XCTAssertEqual(record.sellingCostRate, seed.sellingCostRate, accuracy: 0.000_000_1, country.rawValue)
            XCTAssertEqual(record.priceToRentYears, country.preset.priceToRentYears, accuracy: 0.000_000_1, country.rawValue)
            XCTAssertFalse(record.sources.isEmpty, country.rawValue)
            XCTAssertNotNil(record.mortgageRate, country.rawValue)
            XCTAssertNotNil(record.rentGrowth, country.rawValue)
            XCTAssertNotNil(record.appreciation, country.rawValue)
        }

        let service = PropertyCostService(
            now: { checked },
            bundledData: { data },
            cacheDefaults: isolatedDefaults()
        )
        let china = service.resolvedRates(for: .chinaMainland)
        XCTAssertEqual(china.origin, .seed)
        XCTAssertFalse(china.datasetVersion?.isEmpty ?? true)
        XCTAssertEqual(china.rates.propertyTaxRate, 0, accuracy: 0.000_000_1)
        XCTAssertEqual(service.resolvedPriceToRentYears(for: .chinaMainland), 44, accuracy: 0.000_1)
        XCTAssertFalse(china.sourceNames.isEmpty)
        XCTAssertFalse(service.isCheckDue(for: .chinaMainland))
        XCTAssertFalse(service.isCheckDue(for: .italy))

        let stale = PropertyCostService(
            now: { checked.addingTimeInterval(31 * 24 * 3600) },
            bundledData: { data },
            cacheDefaults: isolatedDefaults()
        )
        XCTAssertTrue(stale.isCheckDue(for: .chinaMainland))
        XCTAssertEqual(stale.resolvedRates(for: .chinaMainland).origin, .seed)
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
            "priceToRentYears": 16,
            "verifiedAt": "2026-10-29",
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
