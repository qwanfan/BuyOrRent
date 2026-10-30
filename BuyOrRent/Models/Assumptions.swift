import Foundation

/// 买房与租房比较的全部输入。
/// 房价、贷款、增值、维修的默认值来自参考表；保险、物业费、贷款保险仍是内置预设。
/// 地税和买卖费率的结构体初值只给计算引擎的单元测试用，界面使用缓存或自住口径的内置种子。
struct Assumptions: Equatable {
    /// 仅用于套用市场预设与显示货币符号；首次打开时不会据此改写下面的默认数字。
    var country: Country = .chinaMainland
    var housingType: HousingType = .apartment
    var homePrice: Double = 600_000
    var downPaymentRatio: Double = 0.20
    var loanYears: Int = 30
    var annualInterestRate: Double = 0.03
    /// 仅作结构体初值。界面使用标普 500 过去 10 年价格年化回报，恢复默认时会重算。
    var investmentReturn: Double = 0.04
    var appreciationRate: Double = 0.01
    var maintenanceRate: Double = 0.01
    /// 仅作结构体初值。界面上的地税来自远程缓存或内置自住代表值，恢复默认时会重算。
    var propertyTaxRate: Double = 0.008
    var rentGrowthRate: Double = 0.01
    /// 仅作结构体初值。界面上的月租由租售比和房价算出，恢复默认时也会重算，不把 2,500 当作默认月租。
    var monthlyRent: Double = 2_500
    var horizonYears: Int = 20

    /// 仅作结构体初值。界面上的买入、卖出费率来自远程缓存或内置自住代表值。
    var buyingCostRate: Double = 0.02
    var sellingCostRate: Double = 0.05
    /// 对齐百分点后一位（原参考表 0.35% → 0.4%）。
    var insuranceRate: Double = 0.004
    var monthlyHOA: Double = 0
    var pmiRate: Double = 0.005

    var downPayment: Double { homePrice * downPaymentRatio }
    var loanPrincipal: Double { max(0, homePrice * (1 - downPaymentRatio)) }
    var loanTermMonths: Int { loanYears * 12 }
    /// 买入当下付出的现金：首付 + 买入成本。
    var initialCash: Double { homePrice * downPaymentRatio + homePrice * buyingCostRate }

    /// 持有 `month` 个月末的房价。`month == 0` 为买入价。
    func homeValue(atMonth month: Int) -> Double {
        guard month > 0, appreciationRate != 0 else { return homePrice }
        return homePrice * pow(1 + appreciationRate, Double(month) / 12)
    }

    /// 首付低于 20% 且剩余贷款 / 当时房价仍高于 80% 时，按剩余本金计贷款保险。
    func monthlyPMI(balance: Double, homeValue: Double) -> Double {
        guard downPaymentRatio < 0.20 else { return 0 }
        guard homeValue > 0, balance > 0 else { return 0 }
        guard balance / homeValue > 0.80 else { return 0 }
        return balance * pmiRate / 12
    }

    var sanitized: Assumptions {
        var copy = self
        copy.homePrice = Assumptions.finite(homePrice, fallback: 0)
        copy.downPaymentRatio = Assumptions.clamp(Assumptions.finite(downPaymentRatio, fallback: 0), 0, 1)
        copy.loanYears = Assumptions.clamp(loanYears, 1, 40)
        copy.horizonYears = Assumptions.clamp(horizonYears, 1, 30)
        copy.annualInterestRate = Assumptions.clamp(Assumptions.finite(annualInterestRate, fallback: 0), 0, 0.5)
        copy.investmentReturn = Assumptions.clamp(Assumptions.finite(investmentReturn, fallback: 0), -0.9, 1)
        copy.appreciationRate = Assumptions.clamp(
            Assumptions.finite(appreciationRate, fallback: 0),
            AssumptionBounds.appreciation.lowerBound,
            AssumptionBounds.appreciation.upperBound
        )
        copy.maintenanceRate = Assumptions.clamp(Assumptions.finite(maintenanceRate, fallback: 0), 0, 1)
        copy.propertyTaxRate = Assumptions.clamp(Assumptions.finite(propertyTaxRate, fallback: 0), 0, 1)
        copy.rentGrowthRate = Assumptions.clamp(Assumptions.finite(rentGrowthRate, fallback: 0), -0.9, 1)
        copy.monthlyRent = Assumptions.finite(monthlyRent, fallback: 0)
        copy.buyingCostRate = Assumptions.clamp(Assumptions.finite(buyingCostRate, fallback: 0), 0, 1)
        copy.sellingCostRate = Assumptions.clamp(Assumptions.finite(sellingCostRate, fallback: 0), 0, 1)
        copy.insuranceRate = Assumptions.clamp(Assumptions.finite(insuranceRate, fallback: 0), 0, 1)
        copy.monthlyHOA = max(0, Assumptions.finite(monthlyHOA, fallback: 0))
        copy.pmiRate = Assumptions.clamp(Assumptions.finite(pmiRate, fallback: 0), 0, 1)
        return copy
    }

    private static func finite(_ value: Double, fallback: Double) -> Double {
        value.isFinite ? value : fallback
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private static func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}

enum AssumptionBounds {
    static let downPayment = 0.0...1.0
    static let interest = 0.0...0.15
    static let investment = 0.0...0.20
    static let appreciation = -0.20...0.20
    static let maintenance = 0.0...0.05
    static let propertyTax = 0.0...0.06
    static let rentGrowth = -0.05...0.15
    static let insurance = 0.0...0.02
    static let pmi = 0.0...0.02
    /// 保留较宽输入范围，便于用户录入外国买家、多套房或高税率地区的实际成本。
    static let buyingCost = 0.0...0.80
    /// 保留较宽输入范围，便于录入资本利得相关费用或高佣金情形。
    static let sellingCost = 0.0...0.30
}
