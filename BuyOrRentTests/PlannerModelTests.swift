import XCTest
@testable import BuyOrRent

@MainActor
final class PlannerModelTests: XCTestCase {
    func testCountryMatchesSystemRegionOrFallsBackToUnitedStates() {
        XCTAssertEqual(Country.matching(regionCode: "CN"), .chinaMainland)
        XCTAssertEqual(Country.matching(regionCode: "hk"), .hongKong)
        XCTAssertEqual(Country.matching(regionCode: "US"), .unitedStates)
        XCTAssertEqual(Country.matching(regionCode: "GB"), .unitedKingdom)
        XCTAssertEqual(Country.matching(regionCode: "DE"), .germany)
        XCTAssertEqual(Country.matching(regionCode: "JP"), .japan)
        XCTAssertEqual(Country.matching(regionCode: "CH"), .switzerland)
        XCTAssertEqual(Country.matching(regionCode: "BR"), .unitedStates)
        XCTAssertEqual(Country.matching(regionCode: nil), .unitedStates)
        XCTAssertEqual(Country.matching(regionCode: "BR").appLanguage, .en)

        let model = PlannerModel(autoFetchPropertyCosts: false, regionCode: "JP")
        XCTAssertEqual(model.assumptions.country, .japan)
        XCTAssertEqual(model.assumptions.country.appLanguage, .ja)
        model.resetAssumptions()
        XCTAssertEqual(model.assumptions.country, .japan)
    }

    func testAppreciationAndRentGrowthChangeIndependently() {
        let model = PlannerModel(autoFetchPropertyCosts: false, regionCode: "US")
        XCTAssertEqual(model.assumptions.appreciationRate, 0.061, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.051, accuracy: 0.000_1)

        model.setAppreciationRate(0.08, source: .stepper)
        XCTAssertEqual(model.assumptions.appreciationRate, 0.08, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.051, accuracy: 0.000_1)

        model.setRentGrowthRate(0.03, source: .manual)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.03, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.appreciationRate, 0.08, accuracy: 0.000_1)

        model.setRentGrowthRate(0.08, source: .stepper)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.08, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.appreciationRate, 0.08, accuracy: 0.000_1)
    }

    func testApplyCountryWritesPresetButKeepsScenarioAssumptions() {
        let isolated = UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        let model = PlannerModel(
            propertyCostService: PropertyCostService(cacheDefaults: isolated),
            autoFetchPropertyCosts: false,
            regionCode: "CN"
        )
        model.assumptions.homePrice = 800_000
        model.assumptions.monthlyRent = 3_000
        model.assumptions.investmentReturn = 0.06
        model.assumptions.appreciationRate = 0.04

        model.applyCountry(.unitedStates)

        XCTAssertEqual(model.assumptions.country, .unitedStates)
        XCTAssertEqual(model.assumptions.loanYears, 30)
        XCTAssertEqual(model.assumptions.annualInterestRate, 0.072, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.propertyTaxRate, 0.011, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.pmiRate, 0.005, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.buyingCostRate, 0.030, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.sellingCostRate, 0.055, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.monthlyHOA, 250, accuracy: 0.1)
        // 房价和投资回报不被国家预设覆盖，金额不换汇。房贷利率、房价涨跌和租金升值换成该国成本表。月租未手动改过时按美国租售比 9.6 年重算。
        XCTAssertEqual(model.assumptions.homePrice, 800_000, accuracy: 0.1)
        XCTAssertEqual(model.assumptions.monthlyRent, 6_944, accuracy: 0.1)
        XCTAssertEqual(model.assumptions.investmentReturn, 0.06, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.appreciationRate, 0.061, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.051, accuracy: 0.000_1)
    }

    func testApplyHousingTypeAdjustsHoldingCostsOnly() {
        let model = PlannerModel(autoFetchPropertyCosts: false)
        model.applyCountry(.unitedStates)
        model.applyHousingType(.detached)
        XCTAssertEqual(model.assumptions.monthlyHOA, 0, accuracy: 0.1)
        XCTAssertEqual(model.assumptions.maintenanceRate, 0.013, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.insuranceRate, 0.006, accuracy: 0.000_1)

        model.applyHousingType(.townhouse)
        XCTAssertEqual(model.assumptions.monthlyHOA, 100, accuracy: 0.1)
        XCTAssertEqual(model.assumptions.maintenanceRate, 0.011, accuracy: 0.000_1)
    }

    func testCatalogMarketSeriesApplyUntilManualEdit() async {
        let defaults = UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        let fetchedAt = ISO8601DateFormatter().date(from: "2026-10-29T05:00:00Z")!
        let data = propertyCostCatalogData(
            country: "unitedStates",
            mortgageRate: 0.072,
            rentGrowth: 0.042,
            appreciation: -0.034
        )
        let service = PropertyCostService(
            now: { fetchedAt },
            fetchData: { _ in data },
            bundledData: { nil },
            cacheDefaults: defaults
        )
        let model = PlannerModel(
            propertyCostService: service,
            autoFetchPropertyCosts: false,
            regionCode: "US"
        )
        model.applyCountry(.unitedStates)
        model.setMortgageRate(0.04, source: .manual)
        model.setRentGrowthRate(0.02, source: .manual)
        model.setAppreciationRate(0.03, source: .manual)

        await model.refreshPropertyCosts(force: false)
        XCTAssertEqual(model.assumptions.annualInterestRate, 0.04, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.02, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.appreciationRate, 0.03, accuracy: 0.000_1)
        XCTAssertNil(model.mortgageRateSourceText)
        XCTAssertNil(model.rentGrowthSourceText)
        XCTAssertNil(model.appreciationSourceText)

        await model.refreshPropertyCosts(force: true)
        XCTAssertEqual(model.assumptions.annualInterestRate, 0.072, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.042, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.appreciationRate, -0.034, accuracy: 0.000_1)
        XCTAssertEqual(model.mortgageRateSourceText, "Source: Freddie Mac 30-year fixed mortgage rate · 2026-10-29")
        XCTAssertEqual(model.rentGrowthSourceText, "Source: OECD actual rentals · 2025")
        XCTAssertEqual(model.appreciationSourceText, "Source: BIS selected residential property prices · 2026-Q2")
        XCTAssertFalse(model.mortgageRateManuallyEdited)
        XCTAssertFalse(model.rentGrowthManuallyEdited)
        XCTAssertFalse(model.appreciationManuallyEdited)
    }

    func testMissingMarketSeriesUsesSeed() async {
        let defaults = UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        let fetchedAt = ISO8601DateFormatter().date(from: "2026-10-29T05:00:00Z")!
        let data = propertyCostCatalogData(country: "unitedStates")
        let service = PropertyCostService(
            now: { fetchedAt },
            fetchData: { _ in data },
            bundledData: { nil },
            cacheDefaults: defaults
        )
        let model = PlannerModel(
            propertyCostService: service,
            autoFetchPropertyCosts: false,
            regionCode: "US"
        )
        model.applyCountry(.unitedStates)
        await model.refreshPropertyCosts(force: false)
        XCTAssertEqual(model.assumptions.annualInterestRate, 0.065, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.051, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.appreciationRate, 0.061, accuracy: 0.000_1)
        XCTAssertNil(model.mortgageRateSourceText)
    }

    func testMarketSeriesFailureKeepsBundledTable() async {
        struct StubError: Error {}
        let defaults = UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        let fetchedAt = ISO8601DateFormatter().date(from: "2026-10-29T05:00:00Z")!
        let bundled = propertyCostCatalogData(
            country: "unitedStates",
            mortgageRate: 0.055,
            rentGrowth: 0.02,
            appreciation: -0.01
        )
        let service = PropertyCostService(
            now: { fetchedAt },
            fetchData: { _ in throw StubError() },
            bundledData: { bundled },
            cacheDefaults: defaults
        )
        let model = PlannerModel(
            propertyCostService: service,
            autoFetchPropertyCosts: false,
            regionCode: "US"
        )
        model.applyCountry(.unitedStates)
        XCTAssertEqual(model.assumptions.annualInterestRate, 0.055, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.02, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.appreciationRate, -0.01, accuracy: 0.000_1)

        await model.refreshPropertyCosts(force: false, attemptNetwork: true)
        XCTAssertEqual(model.assumptions.annualInterestRate, 0.055, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.02, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.appreciationRate, -0.01, accuracy: 0.000_1)
        XCTAssertNil(model.mortgageRateSourceText)
        XCTAssertNil(model.rentGrowthSourceText)
        XCTAssertNil(model.appreciationSourceText)
    }

    func testRentAutoAdjustsWithCountryAndPriceUntilManualEdit() {
        let model = PlannerModel(autoFetchPropertyCosts: false)

        // 美国种子租售比 9.6 年：600,000 ÷ (9.6×12) = 5,208。
        model.applyCountry(.unitedStates)
        XCTAssertEqual(model.assumptions.monthlyRent, 5_208, accuracy: 0.1)

        // 改房价同步重算：960,000 ÷ (9.6×12) = 8,333。
        model.setHomePrice(960_000)
        XCTAssertEqual(model.assumptions.monthlyRent, 8_333, accuracy: 0.1)

        // 手动改月租后，改房价不覆盖。
        model.setMonthlyRent(2_000)
        model.setHomePrice(1_200_000)
        XCTAssertEqual(model.assumptions.monthlyRent, 2_000, accuracy: 0.1)

        // 切换国家总会按该国种子重算：加拿大 17 年，1,200,000 ÷ (17×12) ≈ 5,882。
        model.applyCountry(.canada)
        XCTAssertEqual(model.assumptions.monthlyRent, 5_882, accuracy: 0.1)
        XCTAssertFalse(model.monthlyRentManuallyEdited)
    }

    func testResetClearsRentManualFlagAndRestoresDefaultRent() {
        let model = PlannerModel(autoFetchPropertyCosts: false, regionCode: "CN")
        model.setMonthlyRent(9_999)
        XCTAssertTrue(model.monthlyRentManuallyEdited)
        model.resetAssumptions()
        XCTAssertFalse(model.monthlyRentManuallyEdited)
        // 中国大陆种子租售比 47.8 年：600,000 ÷ (47.8×12) ≈ 1,046。
        XCTAssertEqual(model.assumptions.monthlyRent, 1_046, accuracy: 0.1)
        // 地税和买卖费率也回到中国大陆自住种子，而不是结构体里的旧初值。
        XCTAssertEqual(model.assumptions.propertyTaxRate, 0, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.buyingCostRate, 0.025, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.sellingCostRate, 0.025, accuracy: 0.000_1)
    }

    func testCountrySwitchReplacesManualTransactionCostsWithSeed() {
        let model = PlannerModel(autoFetchPropertyCosts: false)
        model.setBuyingCostRate(0.01)
        XCTAssertEqual(model.assumptions.buyingCostRate, 0.01, accuracy: 0.000_1)
        model.applyCountry(.unitedStates)
        XCTAssertEqual(model.assumptions.buyingCostRate, 0.030, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.sellingCostRate, 0.055, accuracy: 0.000_1)
    }

    func testRemotePropertyCostsPreserveManualFieldsUnlessForced() async {
        let defaults = UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        let fetchedAt = ISO8601DateFormatter().date(from: "2026-10-29T05:00:00Z")!
        let data = propertyCostCatalogData(country: "unitedStates")
        let service = PropertyCostService(
            now: { fetchedAt },
            fetchData: { _ in data },
            bundledData: { nil },
            cacheDefaults: defaults
        )
        let model = PlannerModel(
            propertyCostService: service,
            autoFetchPropertyCosts: false
        )
        model.applyCountry(.unitedStates)
        model.setPropertyTaxRate(0.02)

        await model.refreshPropertyCosts(force: false)
        XCTAssertEqual(model.assumptions.propertyTaxRate, 0.02, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.buyingCostRate, 0.031, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.sellingCostRate, 0.056, accuracy: 0.000_1)
        XCTAssertTrue(model.propertyTaxManuallyEdited)

        await model.refreshPropertyCosts(force: true)
        XCTAssertEqual(model.assumptions.propertyTaxRate, 0.012, accuracy: 0.000_1)
        XCTAssertFalse(model.propertyTaxManuallyEdited)
    }

    func testPropertyCostFailureKeepsSeed() async {
        struct StubError: Error {}
        let defaults = UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        let service = PropertyCostService(
            fetchData: { _ in throw StubError() },
            bundledData: { nil },
            cacheDefaults: defaults
        )
        let model = PlannerModel(
            propertyCostService: service,
            autoFetchPropertyCosts: false
        )
        model.applyCountry(.italy)

        await model.refreshPropertyCosts(force: false)
        XCTAssertEqual(model.assumptions.propertyTaxRate, 0, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.buyingCostRate, 0.060, accuracy: 0.000_1)
        guard case let .failedUsingFallback(resolution) = model.propertyCostState else {
            return XCTFail("Expected fallback state")
        }
        XCTAssertEqual(resolution.origin, .seed)
    }

    private struct StubResetError: Error {}

    func testResetRefreshesMortgageRateAndPropertyCosts() async {
        let fetchedAt = ISO8601DateFormatter().date(from: "2026-10-29T05:00:00Z")!
        let catalog = propertyCostCatalogData(
            country: "chinaMainland",
            mortgageRate: 0.035,
            rentGrowth: -0.006,
            appreciation: -0.059
        )
        let costService = PropertyCostService(
            now: { fetchedAt },
            fetchData: { _ in catalog },
            bundledData: { nil },
            cacheDefaults: UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        )
        let model = PlannerModel(
            propertyCostService: costService,
            priceToRentService: priceToRentService { _ in throw StubResetError() },
            autoFetchPropertyCosts: true,
            regionCode: "CN"
        )
        model.assumptions.country = .unitedStates
        model.setMortgageRate(0.09, source: .manual)
        model.setPropertyTaxRate(0.02)
        model.setBuyingCostRate(0.01)
        model.setInvestmentReturn(0.05)
        model.setHomePrice(900_000)

        model.resetAssumptions()
        XCTAssertEqual(model.assumptions.country, .chinaMainland)
        XCTAssertEqual(model.assumptions.homePrice, 600_000, accuracy: 0.1)
        XCTAssertFalse(model.mortgageRateManuallyEdited)
        XCTAssertFalse(model.propertyTaxManuallyEdited)

        for _ in 0..<50 where model.isRestoringDefaults {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertFalse(model.isRestoringDefaults)
        XCTAssertEqual(model.assumptions.annualInterestRate, 0.035, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.propertyTaxRate, 0.012, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.buyingCostRate, 0.031, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.sellingCostRate, 0.056, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.investmentReturn, 0.1111, accuracy: 0.000_000_1)
        XCTAssertFalse(model.investmentReturnManuallyEdited)
        XCTAssertEqual(model.assumptions.horizonYears, 20)
        XCTAssertEqual(model.assumptions.loanYears, 30)
        XCTAssertEqual(model.mortgageRateSourceText, "来源：Freddie Mac 30 年固定房贷利率 · 2026-10-29")
        XCTAssertEqual(model.propertyTaxSourceText, "来源：Official source")
        XCTAssertEqual(model.buyingCostSourceText, "来源：Official source")
        XCTAssertEqual(model.sellingCostSourceText, "来源：Official source")
        XCTAssertTrue(model.investmentReturnSourceText?.hasPrefix("来源：FRED：S&P 500") == true)

        model.setPropertyTaxRate(0.02)
        model.setMortgageRate(0.04, source: .manual)
        XCTAssertNil(model.propertyTaxSourceText)
        XCTAssertNil(model.mortgageRateSourceText)
        XCTAssertEqual(model.buyingCostSourceText, "来源：Official source")
    }

    func testSourceCaptionsStayHiddenWhenNetworkFails() async {
        struct StubError: Error {}
        let model = PlannerModel(
            propertyCostService: PropertyCostService(
                fetchData: { _ in throw StubError() },
                bundledData: { nil },
                cacheDefaults: UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
            ),
            autoFetchPropertyCosts: true
        )
        await model.refreshPropertyCosts(force: false, attemptNetwork: true)
        XCTAssertNil(model.mortgageRateSourceText)
        XCTAssertNil(model.rentGrowthSourceText)
        XCTAssertNil(model.appreciationSourceText)
        XCTAssertNil(model.propertyTaxSourceText)
        XCTAssertNil(model.buyingCostSourceText)
        XCTAssertNil(model.sellingCostSourceText)
        XCTAssertNil(model.investmentReturnSourceText)
    }

    func testNumbeoPriceToRentRecomputesRentUntilManualEdit() async {
        let model = PlannerModel(
            priceToRentService: priceToRentService(html: numbeoHTML(city: "10.0", outside: "10.0")),
            autoFetchPropertyCosts: false,
            regionCode: "US"
        )
        model.applyCountry(.unitedStates)
        XCTAssertEqual(model.assumptions.monthlyRent, 5_208, accuracy: 0.1)

        await model.refreshPriceToRent()
        XCTAssertEqual(model.currentPriceToRentYears, 10, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.monthlyRent, 5_000, accuracy: 0.1)
        XCTAssertEqual(model.monthlyRentSourceText, "Source: Numbeo · 2026 Mid-Year")

        model.setMonthlyRent(1_234)
        await model.refreshPriceToRent()
        XCTAssertEqual(model.assumptions.monthlyRent, 1_234, accuracy: 0.1)
        XCTAssertNil(model.monthlyRentSourceText)
        XCTAssertTrue(model.monthlyRentManuallyEdited)
    }

    func testMissingPriceToRentUsesSeed() async {
        struct StubError: Error {}
        let model = PlannerModel(
            priceToRentService: priceToRentService { _ in throw StubError() },
            autoFetchPropertyCosts: false,
            regionCode: "US"
        )
        model.applyCountry(.unitedStates)
        let seedRent = model.assumptions.monthlyRent

        await model.refreshPriceToRent()
        XCTAssertEqual(model.currentPriceToRentYears, 9.6, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.monthlyRent, seedRent, accuracy: 0.1)
        XCTAssertNil(model.monthlyRentSourceText)
    }

    func testPriceToRentRefreshFailureKeepsCachedRatios() async {
        struct StubError: Error {}
        let defaults = UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        let html = numbeoHTML(city: "10.0", outside: "10.0")
        let service = PriceToRentService(
            fetchData: { _ in html },
            cacheDefaults: defaults
        )
        let model = PlannerModel(
            priceToRentService: service,
            autoFetchPropertyCosts: false,
            regionCode: "US"
        )
        await model.refreshPriceToRent()
        XCTAssertEqual(model.assumptions.monthlyRent, 5_000, accuracy: 0.1)

        let failing = PriceToRentService(
            fetchData: { _ in throw StubError() },
            cacheDefaults: defaults
        )
        let again = PlannerModel(
            priceToRentService: failing,
            autoFetchPropertyCosts: false,
            regionCode: "US"
        )
        XCTAssertEqual(again.currentPriceToRentYears, 10, accuracy: 0.000_1)
        await again.refreshPriceToRent()
        XCTAssertEqual(again.assumptions.monthlyRent, 5_000, accuracy: 0.1)
        XCTAssertEqual(again.currentPriceToRentYears, 10, accuracy: 0.000_1)
        XCTAssertNil(again.monthlyRentSourceText)
    }

    func testResetRestoresCountryRentSeed() {
        let model = PlannerModel(autoFetchPropertyCosts: false, regionCode: "JP")
        model.setRentGrowthRate(0.02, source: .manual)
        model.setAppreciationRate(0.04, source: .manual)
        model.resetAssumptions()
        XCTAssertEqual(model.assumptions.appreciationRate, 0.033, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.005, accuracy: 0.000_1)
        XCTAssertFalse(model.rentGrowthManuallyEdited)
        XCTAssertFalse(model.appreciationManuallyEdited)
    }

    private func priceToRentService(
        html: Data? = nil,
        fetch: ((URL) async throws -> Data)? = nil
    ) -> PriceToRentService {
        PriceToRentService(
            fetchData: fetch ?? { _ in html ?? Data() },
            cacheDefaults: UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        )
    }

    private func numbeoHTML(city: String, outside: String) -> Data {
        let countries = [
            "China", "Hong Kong (China)", "United States", "Canada", "Singapore", "Australia",
            "Japan", "United Kingdom", "Germany", "France", "Netherlands", "Spain", "Italy", "Switzerland"
        ]
        let rows = countries.map { name in
            "<tr><td>\(name)</td><td>\(city)</td><td>\(outside)</td></tr>"
        }.joined()
        let html = """
        <html><head><title>Property Prices Index by Country 2026 Mid-Year</title></head>
        <table id="t2"><tr><th>Country</th><th>Price To Rent Ratio City Centre</th><th>Price To Rent Ratio Outside Of City Centre</th></tr>
        \(rows)
        </table></html>
        """
        return Data(html.utf8)
    }

    private func propertyCostCatalogData(
        country: String,
        mortgageRate: Double? = nil,
        rentGrowth: Double? = nil,
        appreciation: Double? = nil
    ) -> Data {
        let object: [String: Any] = [
            "schemaVersion": 1,
            "datasetVersion": "2026.10.29",
            "publishedAt": "2026-10-29T05:00:00Z",
            "checkedAt": "2026-10-29T05:00:00Z",
            "nextReviewAt": "2027-01-29",
            "methodology": "Representative owner occupied ordinary residential property costs.",
            "contentDigest": String(repeating: "b", count: 64),
            "investmentReturn": [
                "rate": 0.1111,
                "method": "spxPriceCagr10Y",
                "startDate": "2016-10-31",
                "endDate": "2026-10-28",
                "startLevel": 2126.15,
                "endLevel": 7743.98,
                "sourceName": "FRED：S&P 500",
                "sourceUrl": "https://fred.stlouisfed.org/series/SP500"
            ],
            "countries": [
                country: countryRecord(
                    mortgageRate: mortgageRate,
                    rentGrowth: rentGrowth,
                    appreciation: appreciation
                )
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func countryRecord(
        mortgageRate: Double?,
        rentGrowth: Double?,
        appreciation: Double?
    ) -> [String: Any] {
        var record: [String: Any] = [
            "propertyTaxRate": 0.012,
            "buyingCostRate": 0.031,
            "sellingCostRate": 0.056,
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
        if let mortgageRate {
            record["mortgageRate"] = observation(
                mortgageRate,
                period: "2026-10-29",
                name: "Freddie Mac 30 年固定房贷利率"
            )
        }
        if let rentGrowth {
            record["rentGrowth"] = observation(rentGrowth, period: "2025", name: "OECD 实际房租")
        }
        if let appreciation {
            record["appreciation"] = observation(
                appreciation,
                period: "2026-Q2",
                name: "国际清算银行选定住宅房价"
            )
        }
        return record
    }

    private func observation(_ rate: Double, period: String, name: String) -> [String: Any] {
        [
            "rate": rate,
            "periodLabel": period,
            "sourceName": name,
            "sourceUrl": "https://example.com/source"
        ]
    }
}
