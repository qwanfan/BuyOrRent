import Foundation
import Observation

enum RateEditSource {
    case stepper
    case manual
}

enum PropertyCostState: Equatable {
    case idle
    case usingSeed(PropertyCostResolution)
    case fetching
    case updated(PropertyCostResolution)
    case failedUsingFallback(PropertyCostResolution)

    var statusText: String? {
        switch self {
        case .idle:
            return nil
        case let .usingSeed(resolution):
            return "房产成本：内置数据\(Self.detail(resolution))"
        case .fetching:
            return "正在检查房产成本数据…"
        case let .updated(resolution):
            let origin = resolution.origin == .remote ? "刚刚更新" : "本地缓存"
            return "房产成本：\(origin)\(Self.detail(resolution))"
        case let .failedUsingFallback(resolution):
            let fallback = resolution.origin == .seed ? "内置数据" : "上次缓存"
            return "联网检查失败，继续使用\(fallback)\(Self.detail(resolution))。"
        }
    }

    private static func detail(_ resolution: PropertyCostResolution) -> String {
        let version = resolution.datasetVersion.map { " · v\($0)" } ?? ""
        let date = resolution.publishedAt.map { " · 数据 \($0.prefix(10))" } ?? ""
        let source: String
        if let first = resolution.sourceNames.first {
            source = resolution.sourceNames.count > 1 ? " · 来源：\(first) 等" : " · 来源：\(first)"
        } else {
            source = ""
        }
        return "\(version)\(date)\(source)"
    }
}

@MainActor
@Observable
final class PlannerModel {
    var assumptions = Assumptions()

    private(set) var propertyCostState: PropertyCostState = .idle
    /// 用户在当前国家下手动改过贷款利率后，自动更新不再覆盖。
    private(set) var mortgageRateManuallyEdited = false
    /// 用户在当前国家下手动改过房价涨跌后，自动更新不再覆盖。
    private(set) var appreciationManuallyEdited = false
    /// 用户在当前国家下手动改过租金升值后，自动更新不再覆盖。
    private(set) var rentGrowthManuallyEdited = false
    /// 用户手动改过月租后，自动重算不再覆盖。切换国家或恢复默认会重新按租售比计算。
    private(set) var monthlyRentManuallyEdited = false
    private(set) var propertyTaxManuallyEdited = false
    private(set) var buyingCostManuallyEdited = false
    private(set) var sellingCostManuallyEdited = false
    private(set) var investmentReturnManuallyEdited = false
    /// 本次运行里房产成本表已从 GitHub 取到。手改或联网失败后不显示来源。
    private(set) var propertyCostsFetchedFromNetwork = false
    /// 本次运行里已从 Numbeo 取到租售比。手改月租或抓取失败后不显示来源。
    private(set) var priceToRentFetchedFromNetwork = false
    @ObservationIgnored
    private var propertyCostService: PropertyCostService
    @ObservationIgnored
    private var priceToRentService: PriceToRentService
    private var priceToRentTable: PriceToRentTable?
    @ObservationIgnored
    private let autoFetchPropertyCosts: Bool
    /// 首次打开和恢复默认时使用的国家，按系统地区匹配。
    @ObservationIgnored
    private let defaultCountry: Country
    /// 恢复默认参数正在联网刷新房产成本表。
    private(set) var isRestoringDefaults = false

    @ObservationIgnored
    private var propertyCostFetchTask: Task<Void, Never>?

    init(
        propertyCostService: PropertyCostService = PropertyCostService(),
        priceToRentService: PriceToRentService = PriceToRentService(),
        autoFetchPropertyCosts: Bool = true,
        regionCode: String? = Locale.current.region?.identifier
    ) {
        self.propertyCostService = propertyCostService
        self.priceToRentService = priceToRentService
        self.priceToRentTable = priceToRentService.cachedTable()
        self.autoFetchPropertyCosts = autoFetchPropertyCosts
        let country = Country.matching(regionCode: regionCode)
        self.defaultCountry = country
        assumptions.country = country
        // 首屏同步使用缓存或安装包里的表；联网更新不会阻塞计算。
        assumptions.monthlyRent = suggestedMonthlyRent
        applyResolvedPropertyCosts()
        applyResolvedMarketSeries(preservingManualEdits: false)
        applyResolvedInvestmentReturn(preservingManualEdits: false)
    }

    var analysis: Analysis {
        NetWorthCalculator.analyze(assumptions: assumptions)
    }

    /// 房价、年限回到出厂值。房贷利率、房价涨跌、租金升值、房产税和买卖成本先用本机已有的表，再强制刷新这张表。
    func resetAssumptions() {
        propertyCostFetchTask?.cancel()
        isRestoringDefaults = false
        propertyCostsFetchedFromNetwork = false
        priceToRentFetchedFromNetwork = false
        assumptions = Assumptions()
        assumptions.country = defaultCountry
        mortgageRateManuallyEdited = false
        rentGrowthManuallyEdited = false
        appreciationManuallyEdited = false
        monthlyRentManuallyEdited = false
        clearPropertyCostManualFlags()
        investmentReturnManuallyEdited = false
        assumptions.monthlyRent = suggestedMonthlyRent
        applyResolvedPropertyCosts()
        applyResolvedMarketSeries(preservingManualEdits: false)
        applyResolvedInvestmentReturn(preservingManualEdits: false)

        guard autoFetchPropertyCosts else { return }
        isRestoringDefaults = true
        propertyCostFetchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refreshPropertyCosts(force: true)
            await self.refreshPriceToRent()
            if !Task.isCancelled {
                self.isRestoringDefaults = false
            }
        }
    }

    // MARK: - 国别与房型

    /// 切换国家：利率、租金升值、房价涨跌、地税和买卖费率改用该国成本表。
    /// 不改变房价、首付与投资回报。月租按该国租售比重算。
    func applyCountry(_ country: Country) {
        propertyCostFetchTask?.cancel()
        isRestoringDefaults = false
        assumptions.country = country
        let preset = country.preset
        assumptions.loanYears = preset.loanYears
        assumptions.pmiRate = preset.pmiRate
        clearPropertyCostManualFlags()
        mortgageRateManuallyEdited = false
        rentGrowthManuallyEdited = false
        appreciationManuallyEdited = false
        monthlyRentManuallyEdited = false
        applyResolvedPropertyCosts()
        applyResolvedMarketSeries(preservingManualEdits: false)
        applyHousingPreset(preset.housingPreset(for: assumptions.housingType))
        assumptions.monthlyRent = suggestedMonthlyRent

        if autoFetchPropertyCosts {
            propertyCostFetchTask = Task { [weak self] in
                await self?.refreshPropertyCosts(force: false)
            }
        }
    }

    /// 切换房型：只调整物业费、维修与保险。
    func applyHousingType(_ type: HousingType) {
        assumptions.housingType = type
        applyHousingPreset(assumptions.country.preset.housingPreset(for: type))
    }

    private func applyHousingPreset(_ housing: HousingPreset) {
        assumptions.monthlyHOA = housing.monthlyHOA
        assumptions.maintenanceRate = housing.maintenanceRate
        assumptions.insuranceRate = housing.insuranceRate
    }

    // MARK: - 月租与租售比

    /// 当前国家的租售比（年）：本次或上次从 Numbeo 取到的值，没有时用出厂种子。
    var currentPriceToRentYears: Double {
        priceToRentTable?.years[assumptions.country.rawValue]
            ?? assumptions.country.preset.priceToRentYears
    }

    /// 按当前房价与租售比估算的月租：房价 ÷ (租售比 × 12)，取整到整数金额。
    var suggestedMonthlyRent: Double {
        guard currentPriceToRentYears > 0 else { return assumptions.monthlyRent }
        return (assumptions.homePrice / (currentPriceToRentYears * 12)).rounded()
    }

    /// 改房价：月租未被手动改过时，按租售比同步重算。
    func setHomePrice(_ value: Double) {
        assumptions.homePrice = value.isFinite ? max(0, value) : 0
        if !monthlyRentManuallyEdited {
            assumptions.monthlyRent = suggestedMonthlyRent
        }
    }

    /// 用户手动改月租：此后自动重算不再覆盖。
    func setMonthlyRent(_ value: Double) {
        assumptions.monthlyRent = value.isFinite ? max(0, value) : 0
        monthlyRentManuallyEdited = true
    }

    // MARK: - 地税与买卖费率

    var currentPropertyCosts: PropertyCostRates {
        propertyCostService.resolvedRates(for: assumptions.country).rates
    }

    func setPropertyTaxRate(_ fraction: Double) {
        assumptions.propertyTaxRate = Self.clampPercent(fraction, AssumptionBounds.propertyTax)
        propertyTaxManuallyEdited = true
    }

    func setBuyingCostRate(_ fraction: Double) {
        assumptions.buyingCostRate = Self.clampPercent(fraction, AssumptionBounds.buyingCost)
        buyingCostManuallyEdited = true
    }

    func setSellingCostRate(_ fraction: Double) {
        assumptions.sellingCostRate = Self.clampPercent(fraction, AssumptionBounds.sellingCost)
        sellingCostManuallyEdited = true
    }

    func setInvestmentReturn(_ fraction: Double) {
        assumptions.investmentReturn = Self.clampInvestment(fraction)
        investmentReturnManuallyEdited = true
    }

    /// - Parameter attemptNetwork: 开机时为 true，即使本地数据未过期也访问 GitHub，用来判断能否标注来源。
    func refreshPropertyCosts(force: Bool, attemptNetwork: Bool = false) async {
        let country = assumptions.country
        if !force, !attemptNetwork, !propertyCostService.isCheckDue(for: country) {
            let resolution = propertyCostService.resolvedRates(for: country)
            propertyCostState = resolution.origin == .seed ? .usingSeed(resolution) : .updated(resolution)
            return
        }

        propertyCostState = .fetching
        do {
            let catalog = try await propertyCostService.fetchCatalog()
            guard assumptions.country == country else { return }
            propertyCostsFetchedFromNetwork = true
            guard let resolution = PropertyCostService.resolution(
                for: country,
                in: catalog,
                origin: .remote
            ) else { return }
            if force {
                clearPropertyCostManualFlags()
                investmentReturnManuallyEdited = false
                mortgageRateManuallyEdited = false
                rentGrowthManuallyEdited = false
                appreciationManuallyEdited = false
            }
            applyPropertyCosts(resolution.rates, preservingManualEdits: !force)
            applyResolvedInvestmentReturn(preservingManualEdits: !force)
            applyResolvedMarketSeries(preservingManualEdits: !force)
            if force {
                monthlyRentManuallyEdited = false
            }
            applyResolvedMonthlyRent(preservingManualEdits: !force)
            propertyCostState = .updated(resolution)
        } catch {
            guard assumptions.country == country else { return }
            propertyCostsFetchedFromNetwork = false
            let fallback = propertyCostService.resolvedRates(for: country)
            propertyCostState = .failedUsingFallback(fallback)
            applyResolvedInvestmentReturn(preservingManualEdits: !force)
            applyResolvedMarketSeries(preservingManualEdits: !force)
            applyResolvedMonthlyRent(preservingManualEdits: !force)
        }
    }

    func refreshPriceToRent() async {
        do {
            let table = try await priceToRentService.fetchTable()
            priceToRentTable = table
            priceToRentFetchedFromNetwork = true
            applyResolvedMonthlyRent(preservingManualEdits: true)
        } catch {
            priceToRentFetchedFromNetwork = false
            if priceToRentTable == nil {
                priceToRentTable = priceToRentService.cachedTable()
            }
        }
    }

    var monthlyRentSourceText: String? {
        guard priceToRentFetchedFromNetwork, !monthlyRentManuallyEdited,
              let period = priceToRentTable?.periodLabel, !period.isEmpty else {
            return nil
        }
        return L10n(assumptions.country).source(PriceToRentParser.sourceName, period: period)
    }

    var mortgageRateSourceText: String? {
        marketSourceText(
            edited: mortgageRateManuallyEdited,
            resolution: propertyCostService.resolvedMortgageRate(for: assumptions.country)
        )
    }

    var rentGrowthSourceText: String? {
        marketSourceText(
            edited: rentGrowthManuallyEdited,
            resolution: propertyCostService.resolvedRentGrowth(for: assumptions.country)
        )
    }

    var appreciationSourceText: String? {
        marketSourceText(
            edited: appreciationManuallyEdited,
            resolution: propertyCostService.resolvedAppreciation(for: assumptions.country)
        )
    }

    var investmentReturnSourceText: String? {
        guard propertyCostsFetchedFromNetwork, !investmentReturnManuallyEdited else { return nil }
        let resolution = propertyCostService.resolvedInvestmentReturn()
        guard !resolution.sourceName.isEmpty else { return nil }
        let copy = L10n(assumptions.country)
        if let start = resolution.startDate, let end = resolution.endDate {
            return copy.source(resolution.sourceName, from: start, to: end)
        }
        return copy.source(resolution.sourceName)
    }

    var propertyTaxSourceText: String? {
        fieldSourceText(edited: propertyTaxManuallyEdited)
    }

    var buyingCostSourceText: String? {
        fieldSourceText(edited: buyingCostManuallyEdited)
    }

    var sellingCostSourceText: String? {
        fieldSourceText(edited: sellingCostManuallyEdited)
    }

    private func marketSourceText(edited: Bool, resolution: MarketObservationResolution?) -> String? {
        guard propertyCostsFetchedFromNetwork, !edited,
              let resolution, !resolution.sourceName.isEmpty else {
            return nil
        }
        return L10n(assumptions.country).source(resolution.sourceName, period: resolution.periodLabel)
    }

    private func fieldSourceText(edited: Bool) -> String? {
        guard propertyCostsFetchedFromNetwork, !edited else { return nil }
        let names = propertyCostService.resolvedRates(for: assumptions.country).sourceNames
        guard let first = names.first, !first.isEmpty else { return nil }
        let copy = L10n(assumptions.country)
        if names.count == 1 { return copy.source(first) }
        return copy.sourceAndOthers(first)
    }

    private func applyResolvedPropertyCosts() {
        let resolution = propertyCostService.resolvedRates(for: assumptions.country)
        applyPropertyCosts(resolution.rates, preservingManualEdits: false)
        propertyCostState = resolution.origin == .seed ? .usingSeed(resolution) : .updated(resolution)
    }

    private func applyPropertyCosts(_ rates: PropertyCostRates, preservingManualEdits: Bool) {
        if !preservingManualEdits || !propertyTaxManuallyEdited {
            assumptions.propertyTaxRate = Self.clampPercent(rates.propertyTaxRate, AssumptionBounds.propertyTax)
        }
        if !preservingManualEdits || !buyingCostManuallyEdited {
            assumptions.buyingCostRate = Self.clampPercent(rates.buyingCostRate, AssumptionBounds.buyingCost)
        }
        if !preservingManualEdits || !sellingCostManuallyEdited {
            assumptions.sellingCostRate = Self.clampPercent(rates.sellingCostRate, AssumptionBounds.sellingCost)
        }
    }

    private func applyResolvedMonthlyRent(preservingManualEdits: Bool) {
        guard !preservingManualEdits || !monthlyRentManuallyEdited else { return }
        assumptions.monthlyRent = suggestedMonthlyRent
    }

    private func applyResolvedMarketSeries(preservingManualEdits: Bool) {
        let country = assumptions.country
        let blank = Assumptions()
        if !preservingManualEdits || !mortgageRateManuallyEdited {
            if let rate = propertyCostService.resolvedMortgageRate(for: country)?.rate {
                applyMortgageRate(rate)
            } else {
                assumptions.annualInterestRate = blank.annualInterestRate
            }
        }
        if !preservingManualEdits || !rentGrowthManuallyEdited {
            if let rate = propertyCostService.resolvedRentGrowth(for: country)?.rate {
                applyRentGrowth(rate)
            } else {
                assumptions.rentGrowthRate = blank.rentGrowthRate
            }
        }
        if !preservingManualEdits || !appreciationManuallyEdited {
            if let rate = propertyCostService.resolvedAppreciation(for: country)?.rate {
                applyAppreciation(rate)
            } else {
                assumptions.appreciationRate = blank.appreciationRate
            }
        }
    }

    private func applyResolvedInvestmentReturn(preservingManualEdits: Bool) {
        guard !preservingManualEdits || !investmentReturnManuallyEdited else { return }
        let resolution = propertyCostService.resolvedInvestmentReturn()
        assumptions.investmentReturn = Self.clampInvestment(resolution.rate)
    }

    private func clearPropertyCostManualFlags() {
        propertyTaxManuallyEdited = false
        buyingCostManuallyEdited = false
        sellingCostManuallyEdited = false
    }

    private static func clampPercent(_ fraction: Double, _ range: ClosedRange<Double>) -> Double {
        let snapped = (fraction * 1000).rounded() / 1000
        return min(max(snapped, range.lowerBound), range.upperBound)
    }

    /// 投资回报保留 1 个基点，和远程表的标普 500 年化回报一致。
    private static func clampInvestment(_ fraction: Double) -> Double {
        let snapped = (fraction * 10_000).rounded() / 10_000
        return min(max(snapped, AssumptionBounds.investment.lowerBound), AssumptionBounds.investment.upperBound)
    }

    // MARK: - 贷款利率

    /// 用户手动/步进修改贷款利率：此后自动更新不再覆盖。
    func setMortgageRate(_ fraction: Double, source: RateEditSource) {
        let snapped = (fraction * 1000).rounded() / 1000
        assumptions.annualInterestRate = min(max(snapped, AssumptionBounds.interest.lowerBound), AssumptionBounds.interest.upperBound)
        mortgageRateManuallyEdited = true
    }

    /// 内部写入利率并按 0.1 个百分点对齐显示，不触碰手动标记。
    private func applyMortgageRate(_ fraction: Double) {
        let snapped = (fraction * 1000).rounded() / 1000
        assumptions.annualInterestRate = min(max(snapped, AssumptionBounds.interest.lowerBound), AssumptionBounds.interest.upperBound)
    }

    /// 内部写入房租年涨幅并按 0.1 个百分点对齐显示，不触碰手动标记。
    private func applyRentGrowth(_ fraction: Double) {
        assumptions.rentGrowthRate = Self.clampRentGrowth(fraction)
    }

    /// 内部写入房价涨跌并按 0.1 个百分点对齐显示，不触碰手动标记。
    private func applyAppreciation(_ fraction: Double) {
        assumptions.appreciationRate = Self.clampAppreciation(fraction)
    }

    // MARK: - 房产增值 / 租金升值

    func setAppreciationRate(_ fraction: Double, source: RateEditSource) {
        switch source {
        case .stepper, .manual:
            assumptions.appreciationRate = Self.clampAppreciation(fraction)
            appreciationManuallyEdited = true
        }
    }

    func setRentGrowthRate(_ fraction: Double, source: RateEditSource) {
        switch source {
        case .stepper, .manual:
            assumptions.rentGrowthRate = Self.clampRentGrowth(fraction)
            rentGrowthManuallyEdited = true
        }
    }

    private static func clampAppreciation(_ fraction: Double) -> Double {
        let snapped = (fraction * 1000).rounded() / 1000
        return min(max(snapped, AssumptionBounds.appreciation.lowerBound), AssumptionBounds.appreciation.upperBound)
    }

    private static func clampRentGrowth(_ fraction: Double) -> Double {
        let snapped = (fraction * 1000).rounded() / 1000
        return min(max(snapped, AssumptionBounds.rentGrowth.lowerBound), AssumptionBounds.rentGrowth.upperBound)
    }

}
