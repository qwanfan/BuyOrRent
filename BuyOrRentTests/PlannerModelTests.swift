import XCTest
@testable import BuyOrRent

@MainActor
final class PlannerModelTests: XCTestCase {
    func testStepperSyncsTheOtherRateUntilManualDetach() {
        let model = PlannerModel()
        XCTAssertEqual(model.assumptions.appreciationRate, 0.01, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.01, accuracy: 0.000_1)

        model.setAppreciationRate(0.08, source: .stepper)
        XCTAssertEqual(model.assumptions.appreciationRate, 0.08, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.08, accuracy: 0.000_1)

        model.setRentGrowthRate(0.03, source: .manual)
        XCTAssertTrue(model.rentGrowthDetached)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.03, accuracy: 0.000_1)

        model.setAppreciationRate(0.09, source: .stepper)
        XCTAssertEqual(model.assumptions.appreciationRate, 0.09, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.03, accuracy: 0.000_1)

        model.setRentGrowthRate(0.09, source: .manual)
        XCTAssertFalse(model.rentGrowthDetached)
        XCTAssertFalse(model.appreciationDetached)

        model.setRentGrowthRate(0.10, source: .stepper)
        XCTAssertEqual(model.assumptions.appreciationRate, 0.10, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.10, accuracy: 0.000_1)
    }

    func testApplyCountryWritesPresetButKeepsScenarioAssumptions() {
        let isolated = UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        let model = PlannerModel(
            rateService: MortgageRateService(cacheDefaults: isolated),
            propertyCostService: PropertyCostService(cacheDefaults: isolated),
            autoFetchRates: false,
            autoFetchPropertyCosts: false
        )
        model.assumptions.homePrice = 800_000
        model.assumptions.monthlyRent = 3_000
        model.assumptions.investmentReturn = 0.06

        model.applyCountry(.unitedStates)

        XCTAssertEqual(model.assumptions.country, .unitedStates)
        XCTAssertEqual(model.assumptions.loanYears, 30)
        XCTAssertEqual(model.assumptions.annualInterestRate, 0.065, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.propertyTaxRate, 0.011, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.pmiRate, 0.005, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.buyingCostRate, 0.030, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.sellingCostRate, 0.055, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.monthlyHOA, 250, accuracy: 0.1)
        // 情景假设不被国家预设覆盖，金额不换汇；月租未手动改过时按美国租售比 16 年重算。
        XCTAssertEqual(model.assumptions.homePrice, 800_000, accuracy: 0.1)
        XCTAssertEqual(model.assumptions.monthlyRent, 4_167, accuracy: 0.1)
        XCTAssertEqual(model.assumptions.investmentReturn, 0.06, accuracy: 0.000_1)
    }

    func testApplyHousingTypeAdjustsHoldingCostsOnly() {
        let model = PlannerModel(autoFetchRates: false, autoFetchPropertyCosts: false)
        model.applyCountry(.unitedStates)
        model.applyHousingType(.detached)
        XCTAssertEqual(model.assumptions.monthlyHOA, 0, accuracy: 0.1)
        XCTAssertEqual(model.assumptions.maintenanceRate, 0.013, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.insuranceRate, 0.006, accuracy: 0.000_1)

        model.applyHousingType(.townhouse)
        XCTAssertEqual(model.assumptions.monthlyHOA, 100, accuracy: 0.1)
        XCTAssertEqual(model.assumptions.maintenanceRate, 0.011, accuracy: 0.000_1)
    }

    func testOnlineRateDoesNotOverrideManualEditUnlessForced() async {
        let defaults = UserDefaults(suiteName: "BuyOrRentTests.\(UUID().uuidString)")!
        let csv = "DATE,MORTGAGE30US\n2026-10-22,7.20\n"
        let service = MortgageRateService(fetchData: { _ in Data(csv.utf8) }, cacheDefaults: defaults)
        let model = PlannerModel(
            rateService: service,
            autoFetchRates: false,
            autoFetchPropertyCosts: false
        )

        model.applyCountry(.unitedStates)
        model.setMortgageRate(0.04, source: .manual)
        await model.refreshMortgageRate(force: false)
        XCTAssertEqual(model.assumptions.annualInterestRate, 0.04, accuracy: 0.000_1)

        await model.refreshMortgageRate(force: true)
        XCTAssertEqual(model.assumptions.annualInterestRate, 0.072, accuracy: 0.000_1)
        XCTAssertFalse(model.mortgageRateManuallyEdited)
    }

    func testOnlineFailureFallsBackToDefaultRate() async {
        struct StubError: Error {}
        let service = MortgageRateService(fetchData: { _ in throw StubError() })
        let model = PlannerModel(
            rateService: service,
            autoFetchRates: false,
            autoFetchPropertyCosts: false
        )

        model.applyCountry(.germany)
        XCTAssertEqual(model.assumptions.annualInterestRate, 0.038, accuracy: 0.000_1)
        await model.refreshMortgageRate(force: false)
        XCTAssertEqual(model.assumptions.annualInterestRate, 0.038, accuracy: 0.000_1)
        XCTAssertEqual(model.mortgageRateState, .failedUsingDefault)
    }

    func testRentAutoAdjustsWithCountryAndPriceUntilManualEdit() {
        let model = PlannerModel(autoFetchRates: false, autoFetchPropertyCosts: false)

        // 美国种子租售比 16 年：600,000 ÷ (16×12) = 3,125。
        model.applyCountry(.unitedStates)
        XCTAssertEqual(model.assumptions.monthlyRent, 3_125, accuracy: 0.1)

        // 改房价同步重算：960,000 ÷ 192 = 5,000。
        model.setHomePrice(960_000)
        XCTAssertEqual(model.assumptions.monthlyRent, 5_000, accuracy: 0.1)

        // 手动改月租后，改房价不覆盖。
        model.setMonthlyRent(2_000)
        model.setHomePrice(1_200_000)
        XCTAssertEqual(model.assumptions.monthlyRent, 2_000, accuracy: 0.1)

        // 切换国家总会按该国种子重算：加拿大 18 年，1,200,000 ÷ 216 ≈ 5,556。
        model.applyCountry(.canada)
        XCTAssertEqual(model.assumptions.monthlyRent, 5_556, accuracy: 0.1)
        XCTAssertFalse(model.monthlyRentManuallyEdited)
    }

    func testResetClearsRentManualFlagAndRestoresDefaultRent() {
        let model = PlannerModel(autoFetchRates: false, autoFetchPropertyCosts: false)
        model.setMonthlyRent(9_999)
        XCTAssertTrue(model.monthlyRentManuallyEdited)
        model.resetAssumptions()
        XCTAssertFalse(model.monthlyRentManuallyEdited)
        // 中国大陆种子租售比 38 年：600,000 ÷ (38×12) ≈ 1,316。
        XCTAssertEqual(model.assumptions.monthlyRent, 1_316, accuracy: 0.1)
        // 地税和买卖费率也回到中国大陆自住种子，而不是结构体里的旧初值。
        XCTAssertEqual(model.assumptions.propertyTaxRate, 0, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.buyingCostRate, 0.025, accuracy: 0.000_1)
        XCTAssertEqual(model.assumptions.sellingCostRate, 0.025, accuracy: 0.000_1)
    }

    func testCountrySwitchReplacesManualTransactionCostsWithSeed() {
        let model = PlannerModel(autoFetchRates: false, autoFetchPropertyCosts: false)
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
            cacheDefaults: defaults
        )
        let model = PlannerModel(
            propertyCostService: service,
            autoFetchRates: false,
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
        let service = PropertyCostService(fetchData: { _ in throw StubError() })
        let model = PlannerModel(
            propertyCostService: service,
            autoFetchRates: false,
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

    func testResetClearsDetachFlags() {
        let model = PlannerModel()
        model.setRentGrowthRate(0.02, source: .manual)
        XCTAssertTrue(model.rentGrowthDetached)
        model.resetAssumptions()
        XCTAssertFalse(model.rentGrowthDetached)
        XCTAssertFalse(model.appreciationDetached)
        XCTAssertEqual(model.assumptions.rentGrowthRate, 0.01, accuracy: 0.000_1)
    }

    private func propertyCostCatalogData(country: String) -> Data {
        let object: [String: Any] = [
            "schemaVersion": 1,
            "datasetVersion": "2026.10.29",
            "publishedAt": "2026-10-29T05:00:00Z",
            "checkedAt": "2026-10-29T05:00:00Z",
            "nextReviewAt": "2027-01-29",
            "methodology": "Representative owner occupied ordinary residential property costs.",
            "contentDigest": String(repeating: "b", count: 64),
            "countries": [
                country: [
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
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
