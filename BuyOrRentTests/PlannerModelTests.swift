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
        let defaults = UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        let model = PlannerModel(
            propertyCostService: PropertyCostService(cacheDefaults: defaults),
            autoFetchPropertyCosts: false,
            regionCode: "US"
        )
        XCTAssertEqual(model.assumptions.appreciationRate, 0.061, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.043, accuracy: 0.000_1)

        model.setAppreciationRate(0.08, source: .stepper)
        XCTAssertEqual(model.assumptions.appreciationRate, 0.08, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.043, accuracy: 0.000_1)

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
        XCTAssertEqual(model.assumptions.propertyTaxRate, 0.015, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.pmiRate, 0.005, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.buyingCostRate, 0.0286, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.sellingCostRate, 0.045, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.monthlyHOA, 250, accuracy: 0.1)
        // 房价不被国家预设覆盖，金额不换汇。投资回报换成美国主指数种子。房贷利率、房价涨跌和租金升值换成该国成本表。月租未手动改过时按美国租售比 16 年重算。
        XCTAssertEqual(model.assumptions.homePrice, 800_000, accuracy: 0.1)
        XCTAssertEqual(model.assumptions.monthlyRent, 4_167, accuracy: 0.1)
        XCTAssertEqual(model.assumptions.investmentReturn, 0.1355, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.appreciationRate, 0.061, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.043, accuracy: 0.000_1)
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

    func testMissingMarketSeriesLeavesBlankRates() async {
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
        XCTAssertEqual(model.assumptions.annualInterestRate, 0.03, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.01, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.appreciationRate, 0.01, accuracy: 0.000_1)
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

        // 美国种子租售比 16 年：600,000 ÷ (16×12) = 3,125。
        model.applyCountry(.unitedStates)
        XCTAssertEqual(model.assumptions.monthlyRent, 3_125, accuracy: 0.1)

        // 改房价同步重算：960,000 ÷ (16×12) = 5,000。
        model.setHomePrice(960_000)
        XCTAssertEqual(model.assumptions.monthlyRent, 5_000, accuracy: 0.1)

        // 手动改月租后，改房价不覆盖。
        model.setMonthlyRent(2_000)
        model.setHomePrice(1_200_000)
        XCTAssertEqual(model.assumptions.monthlyRent, 2_000, accuracy: 0.1)

        // 切换国家总会按该国种子重算：加拿大 18 年，1,200,000 ÷ (18×12) ≈ 5,556。
        model.applyCountry(.canada)
        XCTAssertEqual(model.assumptions.monthlyRent, 5_556, accuracy: 0.1)
        XCTAssertFalse(model.monthlyRentManuallyEdited)
    }

    func testResetClearsRentManualFlagAndRestoresDefaultRent() {
        let model = PlannerModel(autoFetchPropertyCosts: false, regionCode: "CN")
        model.setMonthlyRent(9_999)
        XCTAssertTrue(model.monthlyRentManuallyEdited)
        model.resetAssumptions()
        XCTAssertFalse(model.monthlyRentManuallyEdited)
        // 中国大陆种子租售比 44 年：600,000 ÷ (44×12) ≈ 1,136。
        XCTAssertEqual(model.assumptions.monthlyRent, 1_136, accuracy: 0.1)
        // 地税和买卖费率也回到中国大陆自住种子，而不是结构体里的旧初值。
        XCTAssertEqual(model.assumptions.propertyTaxRate, 0, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.buyingCostRate, 0.076, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.sellingCostRate, 0.01, accuracy: 0.000_1)
    }

    func testCountrySwitchReplacesManualTransactionCostsWithSeed() {
        let model = PlannerModel(autoFetchPropertyCosts: false)
        model.setBuyingCostRate(0.01)
        XCTAssertEqual(model.assumptions.buyingCostRate, 0.01, accuracy: 0.000_1)
        model.applyCountry(.unitedStates)
        XCTAssertEqual(model.assumptions.buyingCostRate, 0.0286, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.sellingCostRate, 0.045, accuracy: 0.000_1)
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
        XCTAssertEqual(model.assumptions.buyingCostRate, 0.11, accuracy: 0.000_1)
        guard case let .failedUsingFallback(resolution) = model.propertyCostState else {
            return XCTFail("Expected fallback state")
        }
        XCTAssertEqual(resolution.origin, .seed)
    }

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
        let equity = EquityIndexReturnService(
            now: { fetchedAt },
            fetchData: { _ in PlannerModelTestFixtures.equityCatalogData() },
            bundledData: { nil },
            cacheDefaults: UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!,
            calendar: PlannerModelTestFixtures.utcCalendar
        )
        let model = PlannerModel(
            propertyCostService: costService,
            equityIndexService: equity,
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
        XCTAssertEqual(model.assumptions.investmentReturn, 0.0414, accuracy: 0.000_1)
        XCTAssertFalse(model.investmentReturnManuallyEdited)
        XCTAssertEqual(model.assumptions.horizonYears, 20)
        XCTAssertEqual(model.assumptions.loanYears, 30)
        XCTAssertEqual(model.mortgageRateSourceText, "来源：Freddie Mac 30 年固定房贷利率 · 2026-10-29")
        XCTAssertEqual(model.propertyTaxSourceText, "来源：Official source · 2026-10-29")
        XCTAssertEqual(model.buyingCostSourceText, "来源：Official source · 2026-10-29")
        XCTAssertEqual(model.sellingCostSourceText, "来源：Official source · 2026-10-29")
        XCTAssertEqual(model.investmentReturnSourceText, "来源：Yahoo Finance：沪深 300 · 2016-10-28 至 2026-10-28")

        model.setPropertyTaxRate(0.02)
        model.setMortgageRate(0.04, source: .manual)
        XCTAssertNil(model.propertyTaxSourceText)
        XCTAssertNil(model.mortgageRateSourceText)
        XCTAssertEqual(model.buyingCostSourceText, "来源：Official source · 2026-10-29")
    }

    func testSourceCaptionsStayHiddenWhenNetworkFails() async {
        struct StubError: Error {}
        let model = PlannerModel(
            propertyCostService: PropertyCostService(
                fetchData: { _ in throw StubError() },
                bundledData: { nil },
                cacheDefaults: UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
            ),
            equityIndexService: EquityIndexReturnService(
                fetchData: { _ in throw StubError() },
                bundledData: { nil },
                cacheDefaults: UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
            ),
            autoFetchPropertyCosts: true
        )
        await model.refreshPropertyCosts(force: false, attemptNetwork: true)
        await model.refreshInvestmentReturn(force: false)
        XCTAssertNil(model.mortgageRateSourceText)
        XCTAssertNil(model.rentGrowthSourceText)
        XCTAssertNil(model.appreciationSourceText)
        XCTAssertNil(model.propertyTaxSourceText)
        XCTAssertNil(model.buyingCostSourceText)
        XCTAssertNil(model.sellingCostSourceText)
        XCTAssertNil(model.investmentReturnSourceText)
    }

    func testCountrySwitchAppliesCachedEquityReturnUntilManualEdit() async {
        let fetchedAt = ISO8601DateFormatter().date(from: "2026-10-29T05:00:00Z")!
        let equity = EquityIndexReturnService(
            now: { fetchedAt },
            fetchData: { _ in PlannerModelTestFixtures.equityCatalogData() },
            bundledData: { nil },
            cacheDefaults: UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!,
            calendar: PlannerModelTestFixtures.utcCalendar
        )
        let model = PlannerModel(
            equityIndexService: equity,
            autoFetchPropertyCosts: false,
            regionCode: "CN"
        )
        await model.refreshInvestmentReturn(force: false)
        XCTAssertEqual(model.assumptions.investmentReturn, 0.0414, accuracy: 0.000_1)
        XCTAssertTrue(model.investmentReturnSourceText?.contains("沪深 300") == true)

        model.applyCountry(.unitedStates)
        XCTAssertEqual(model.assumptions.investmentReturn, 0.0718, accuracy: 0.000_000_1)
        XCTAssertTrue(model.investmentReturnSourceText?.contains("S&P 500") == true)

        model.setInvestmentReturn(0.09)
        await model.refreshInvestmentReturn(force: false)
        XCTAssertEqual(model.assumptions.investmentReturn, 0.09, accuracy: 0.000_1)
        XCTAssertNil(model.investmentReturnSourceText)
    }

    func testSourceCaptionSplitsLabelFromRemainder() {
        let copy = L10n(language: .zhHans)
        let text = copy.source("示例来源", period: "2026-10-29")
        let parts = copy.sourceCaptionParts(in: text)
        XCTAssertEqual(parts?.label, "来源")
        XCTAssertEqual(parts?.remainder, "：示例来源 · 2026-10-29")
        XCTAssertNil(copy.sourceCaptionParts(in: "Source: Numbeo"))
    }

    func testCatalogPriceToRentRecomputesRentUntilManualEdit() async {
        let fetchedAt = ISO8601DateFormatter().date(from: "2026-10-29T05:00:00Z")!
        let catalog = propertyCostCatalogData(country: "unitedStates", priceToRentYears: 10)
        let service = PropertyCostService(
            now: { fetchedAt },
            fetchData: { _ in catalog },
            bundledData: { nil },
            cacheDefaults: UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        )
        let model = PlannerModel(
            propertyCostService: service,
            autoFetchPropertyCosts: false,
            regionCode: "US"
        )
        model.applyCountry(.unitedStates)
        XCTAssertEqual(model.assumptions.monthlyRent, 3_125, accuracy: 0.1)

        await model.refreshPropertyCosts(force: false, attemptNetwork: true)
        XCTAssertEqual(model.currentPriceToRentYears, 10, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.monthlyRent, 5_000, accuracy: 0.1)
        XCTAssertEqual(model.monthlyRentSourceText, "Source: Official source · 2026-10-29")

        model.setMonthlyRent(1_234)
        await model.refreshPropertyCosts(force: false, attemptNetwork: true)
        XCTAssertEqual(model.assumptions.monthlyRent, 1_234, accuracy: 0.1)
        XCTAssertNil(model.monthlyRentSourceText)
        XCTAssertTrue(model.monthlyRentManuallyEdited)
    }

    func testMissingPriceToRentUsesSeed() async {
        struct StubError: Error {}
        let model = PlannerModel(
            propertyCostService: PropertyCostService(
                fetchData: { _ in throw StubError() },
                bundledData: { nil },
                cacheDefaults: UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
            ),
            autoFetchPropertyCosts: false,
            regionCode: "US"
        )
        model.applyCountry(.unitedStates)
        let seedRent = model.assumptions.monthlyRent

        await model.refreshPropertyCosts(force: false, attemptNetwork: true)
        XCTAssertEqual(model.currentPriceToRentYears, 16, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.monthlyRent, seedRent, accuracy: 0.1)
        XCTAssertNil(model.monthlyRentSourceText)
    }

    func testPriceToRentRefreshFailureKeepsCachedRatios() async {
        struct StubError: Error {}
        let defaults = UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        let fetchedAt = ISO8601DateFormatter().date(from: "2026-10-29T05:00:00Z")!
        let catalog = propertyCostCatalogData(country: "unitedStates", priceToRentYears: 10)
        let service = PropertyCostService(
            now: { fetchedAt },
            fetchData: { _ in catalog },
            bundledData: { nil },
            cacheDefaults: defaults
        )
        let model = PlannerModel(
            propertyCostService: service,
            autoFetchPropertyCosts: false,
            regionCode: "US"
        )
        await model.refreshPropertyCosts(force: false, attemptNetwork: true)
        XCTAssertEqual(model.assumptions.monthlyRent, 5_000, accuracy: 0.1)

        let failing = PropertyCostService(
            now: { fetchedAt },
            fetchData: { _ in throw StubError() },
            bundledData: { nil },
            cacheDefaults: defaults
        )
        let again = PlannerModel(
            propertyCostService: failing,
            autoFetchPropertyCosts: false,
            regionCode: "US"
        )
        XCTAssertEqual(again.currentPriceToRentYears, 10, accuracy: 0.000_1)
        await again.refreshPropertyCosts(force: false, attemptNetwork: true)
        XCTAssertEqual(again.assumptions.monthlyRent, 5_000, accuracy: 0.1)
        XCTAssertEqual(again.currentPriceToRentYears, 10, accuracy: 0.000_1)
        XCTAssertNil(again.monthlyRentSourceText)
    }

    func testResetRestoresCountryRentSeed() {
        let defaults = UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        let model = PlannerModel(
            propertyCostService: PropertyCostService(cacheDefaults: defaults),
            autoFetchPropertyCosts: false,
            regionCode: "JP"
        )
        model.setRentGrowthRate(0.02, source: .manual)
        model.setAppreciationRate(0.04, source: .manual)
        model.resetAssumptions()
        XCTAssertEqual(model.assumptions.appreciationRate, 0.033, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0, accuracy: 0.000_1)
        XCTAssertFalse(model.rentGrowthManuallyEdited)
        XCTAssertFalse(model.appreciationManuallyEdited)
    }

    private func propertyCostCatalogData(
        country: String,
        mortgageRate: Double? = nil,
        rentGrowth: Double? = nil,
        appreciation: Double? = nil,
        priceToRentYears: Double = 44
    ) -> Data {
        let object: [String: Any] = [
            "schemaVersion": 1,
            "datasetVersion": "2026.10.29",
            "publishedAt": "2026-10-29T05:00:00Z",
            "checkedAt": "2026-10-29T05:00:00Z",
            "nextReviewAt": "2027-01-29",
            "methodology": "Representative owner occupied ordinary residential property costs.",
            "contentDigest": String(repeating: "b", count: 64),
            "countries": [
                country: countryRecord(
                    mortgageRate: mortgageRate,
                    rentGrowth: rentGrowth,
                    appreciation: appreciation,
                    priceToRentYears: priceToRentYears
                )
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func countryRecord(
        mortgageRate: Double?,
        rentGrowth: Double?,
        appreciation: Double?,
        priceToRentYears: Double
    ) -> [String: Any] {
        var record: [String: Any] = [
            "propertyTaxRate": 0.012,
            "buyingCostRate": 0.031,
            "sellingCostRate": 0.056,
            "priceToRentYears": priceToRentYears,
            "verifiedAt": "2026-10-29",
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

private enum PlannerModelTestFixtures {
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func equityCatalogData() -> Data {
        let payload: [String: Any] = [
            "schemaVersion": 1,
            "publishedAt": "2026-10-29T05:00:00Z",
            "fetchedOn": "2026-10-01",
            "methodology": "Ten-year price CAGR",
            "countries": [
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
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }
}
