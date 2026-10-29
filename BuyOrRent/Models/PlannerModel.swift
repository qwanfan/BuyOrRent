import Foundation
import Observation

enum RateEditSource {
    case stepper
    case manual
}

/// 贷款利率的联网状态。
enum MortgageRateState: Equatable {
    /// 尚未切换过国家（初始默认值）。
    case idle
    /// 已套用内置缺省利率（未联网或等待联网）。
    case usingDefault
    case fetching
    /// 已用联网（或缓存）利率，附带报价信息。
    case updated(MortgageRateQuote)
    /// 联网失败，继续使用缺省利率。
    case failedUsingDefault

    var statusText: String? {
        switch self {
        case .idle:
            nil
        case .usingDefault:
            "利率为内置缺省值，可点「更新利率」联网获取最新官方数据。"
        case .fetching:
            "正在联网更新利率…"
        case let .updated(quote):
            "来源：\(quote.sourceName) · \(quote.periodLabel)"
        case .failedUsingDefault:
            "联网失败，已使用缺省利率。可点「更新利率」重试。"
        }
    }
}

enum PropertyCostState: Equatable {
    case idle
    case usingSeed
    case fetching
    case updated(PropertyCostResolution)
    case failedUsingFallback(PropertyCostResolution)

    var statusText: String? {
        switch self {
        case .idle:
            return nil
        case .usingSeed:
            return "房产成本为内置自住代表值；本地无新数据时会联网检查。"
        case .fetching:
            return "正在检查房产成本数据…"
        case let .updated(resolution):
            let version = resolution.datasetVersion.map { " · v\($0)" } ?? ""
            let date = resolution.publishedAt.map { " · 数据 \($0.prefix(10))" } ?? ""
            let source: String
            if let first = resolution.sourceNames.first {
                source = resolution.sourceNames.count > 1
                    ? " · 来源：\(first) 等"
                    : " · 来源：\(first)"
            } else {
                source = ""
            }
            let origin = resolution.origin == .remote ? "刚刚更新" : "本地缓存"
            return "房产成本：\(origin)\(version)\(date)\(source)"
        case let .failedUsingFallback(resolution):
            let fallback = resolution.origin == .seed ? "内置值" : "上次缓存"
            return "联网检查失败，继续使用\(fallback)。"
        }
    }
}

@MainActor
@Observable
final class PlannerModel {
    var assumptions = Assumptions()

    /// 该侧被手动改成与另一侧不同后，步进另一侧时不再覆盖本侧。
    private(set) var appreciationDetached = false
    private(set) var rentGrowthDetached = false

    private(set) var mortgageRateState: MortgageRateState = .idle
    private(set) var propertyCostState: PropertyCostState = .idle
    /// 用户在当前国家下手动改过贷款利率后，自动联网结果不再覆盖。
    private(set) var mortgageRateManuallyEdited = false
    /// 用户手动改过月租后，改房价不再覆盖。切换国家或恢复默认会重新按种子计算。
    private(set) var monthlyRentManuallyEdited = false
    private(set) var propertyTaxManuallyEdited = false
    private(set) var buyingCostManuallyEdited = false
    private(set) var sellingCostManuallyEdited = false
    @ObservationIgnored
    private var rateService: MortgageRateService
    @ObservationIgnored
    private var propertyCostService: PropertyCostService
    @ObservationIgnored
    private let autoFetchRates: Bool
    @ObservationIgnored
    private let autoFetchPropertyCosts: Bool
    @ObservationIgnored
    private var rateFetchTask: Task<Void, Never>?
    @ObservationIgnored
    private var propertyCostFetchTask: Task<Void, Never>?

    init(
        rateService: MortgageRateService = MortgageRateService(),
        propertyCostService: PropertyCostService = PropertyCostService(),
        autoFetchRates: Bool = true,
        autoFetchPropertyCosts: Bool = true
    ) {
        self.rateService = rateService
        self.propertyCostService = propertyCostService
        self.autoFetchRates = autoFetchRates
        self.autoFetchPropertyCosts = autoFetchPropertyCosts
        // 首屏同步使用缓存或内置值；联网更新不会阻塞计算。
        assumptions.monthlyRent = suggestedMonthlyRent
        assumptions.annualInterestRate = Country.chinaMainland.preset.defaultMortgageRate
        applyResolvedPropertyCosts()
    }

    var analysis: Analysis {
        NetWorthCalculator.analyze(assumptions: assumptions)
    }

    func resetAssumptions() {
        rateFetchTask?.cancel()
        propertyCostFetchTask?.cancel()
        assumptions = Assumptions()
        appreciationDetached = false
        rentGrowthDetached = false
        mortgageRateState = .idle
        mortgageRateManuallyEdited = false
        monthlyRentManuallyEdited = false
        clearPropertyCostManualFlags()
        assumptions.monthlyRent = suggestedMonthlyRent
        assumptions.annualInterestRate = assumptions.country.preset.defaultMortgageRate
        applyResolvedPropertyCosts()
    }

    // MARK: - 国别与房型

    /// 切换国家：立即套用该国预设（利率先用缺省值），地税和买卖费率用出厂种子，随后异步联网更新利率。
    /// 不改变房价、首付、房产增值、租金升值与投资回报。月租按该国租售比种子重算。
    func applyCountry(_ country: Country) {
        rateFetchTask?.cancel()
        propertyCostFetchTask?.cancel()
        assumptions.country = country
        let preset = country.preset
        assumptions.loanYears = preset.loanYears
        assumptions.pmiRate = preset.pmiRate
        clearPropertyCostManualFlags()
        applyResolvedPropertyCosts()
        applyHousingPreset(preset.housingPreset(for: assumptions.housingType))
        applyMortgageRate(preset.defaultMortgageRate)
        mortgageRateManuallyEdited = false
        monthlyRentManuallyEdited = false
        assumptions.monthlyRent = suggestedMonthlyRent

        // 有新鲜缓存先用缓存显示，并后台刷新。
        if let cached = rateService.cachedQuote(for: country), cached.isCacheFresh(now: rateService.now()) {
            applyMortgageRate(cached.rate)
            mortgageRateState = .updated(cached)
        } else {
            mortgageRateState = .usingDefault
        }

        if autoFetchRates {
            rateFetchTask = Task { [weak self] in
                await self?.refreshMortgageRate(force: false)
            }
        }
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

    /// 当前国家的租售比种子（年）。
    var currentPriceToRentYears: Double {
        assumptions.country.preset.priceToRentYears
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

    func refreshPropertyCosts(force: Bool) async {
        let country = assumptions.country
        if !force, !propertyCostService.isCheckDue(for: country) {
            let resolution = propertyCostService.resolvedRates(for: country)
            propertyCostState = resolution.origin == .seed ? .usingSeed : .updated(resolution)
            return
        }

        propertyCostState = .fetching
        do {
            let catalog = try await propertyCostService.fetchCatalog()
            guard assumptions.country == country,
                  let resolution = PropertyCostService.resolution(
                      for: country,
                      in: catalog,
                      origin: .remote
                  ) else { return }
            if force {
                clearPropertyCostManualFlags()
            }
            applyPropertyCosts(resolution.rates, preservingManualEdits: !force)
            propertyCostState = .updated(resolution)
        } catch {
            guard assumptions.country == country else { return }
            let fallback = propertyCostService.resolvedRates(for: country)
            propertyCostState = .failedUsingFallback(fallback)
        }
    }

    private func applyResolvedPropertyCosts() {
        let resolution = propertyCostService.resolvedRates(for: assumptions.country)
        applyPropertyCosts(resolution.rates, preservingManualEdits: false)
        propertyCostState = resolution.origin == .seed ? .usingSeed : .updated(resolution)
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

    private func clearPropertyCostManualFlags() {
        propertyTaxManuallyEdited = false
        buyingCostManuallyEdited = false
        sellingCostManuallyEdited = false
    }

    private static func clampPercent(_ fraction: Double, _ range: ClosedRange<Double>) -> Double {
        let snapped = (fraction * 1000).rounded() / 1000
        return min(max(snapped, range.lowerBound), range.upperBound)
    }

    // MARK: - 贷款利率

    /// 用户手动/步进修改贷款利率：此后自动联网结果不再覆盖。
    func setMortgageRate(_ fraction: Double, source: RateEditSource) {
        let snapped = (fraction * 1000).rounded() / 1000
        assumptions.annualInterestRate = min(max(snapped, AssumptionBounds.interest.lowerBound), AssumptionBounds.interest.upperBound)
        mortgageRateManuallyEdited = true
    }

    /// 联网更新当前国家的贷款利率。
    /// - Parameter force: 为 true（用户点「更新利率」）时覆盖手动修改；为 false 时尊重手动修改。
    func refreshMortgageRate(force: Bool) async {
        let country = assumptions.country
        if !force {
            if mortgageRateManuallyEdited { return }
            mortgageRateState = .fetching
            do {
                let quote = try await rateService.fetchQuote(for: country)
                // 等待期间用户可能切了国家或手动改了利率。
                guard assumptions.country == country, !mortgageRateManuallyEdited else { return }
                applyMortgageRate(quote.rate)
                mortgageRateState = .updated(quote)
            } catch {
                guard assumptions.country == country else { return }
                mortgageRateState = .failedUsingDefault
            }
            return
        }

        mortgageRateState = .fetching
        do {
            let quote = try await rateService.fetchQuote(for: country)
            guard assumptions.country == country else { return }
            applyMortgageRate(quote.rate)
            mortgageRateManuallyEdited = false
            mortgageRateState = .updated(quote)
        } catch {
            guard assumptions.country == country else { return }
            mortgageRateState = .failedUsingDefault
        }
    }

    /// 内部写入利率并按 0.1 个百分点对齐显示，不触碰手动标记。
    private func applyMortgageRate(_ fraction: Double) {
        let snapped = (fraction * 1000).rounded() / 1000
        assumptions.annualInterestRate = min(max(snapped, AssumptionBounds.interest.lowerBound), AssumptionBounds.interest.upperBound)
    }

    // MARK: - 房产增值 / 租金升值联动

    func setAppreciationRate(_ fraction: Double, source: RateEditSource) {
        let value = Self.clampAppreciation(fraction)
        assumptions.appreciationRate = value

        switch source {
        case .stepper:
            appreciationDetached = false
            if !rentGrowthDetached {
                assumptions.rentGrowthRate = Self.clampRentGrowth(value)
            }
        case .manual:
            if Self.nearlyEqual(value, assumptions.rentGrowthRate) {
                appreciationDetached = false
                rentGrowthDetached = false
            } else {
                appreciationDetached = true
            }
        }
    }

    func setRentGrowthRate(_ fraction: Double, source: RateEditSource) {
        let value = Self.clampRentGrowth(fraction)
        assumptions.rentGrowthRate = value

        switch source {
        case .stepper:
            rentGrowthDetached = false
            if !appreciationDetached {
                assumptions.appreciationRate = Self.clampAppreciation(value)
            }
        case .manual:
            if Self.nearlyEqual(value, assumptions.appreciationRate) {
                appreciationDetached = false
                rentGrowthDetached = false
            } else {
                rentGrowthDetached = true
            }
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

    private static func nearlyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.000_5
    }
}
