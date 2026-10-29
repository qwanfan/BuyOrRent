import Foundation

struct HorizonBreakdown: Equatable, Identifiable {
    var years: Int
    var saleProceeds: Double
    var initialCashFutureValue: Double
    var holdingCostFutureValue: Double
    var rentFutureValue: Double
    var advantageFutureValue: Double
    var advantageNPV: Double
    var breakevenMonthlyRent: Double?
    var homeValue: Double
    var loanBalance: Double
    var monthlyPayment: Double

    var id: Int { years }
}

struct Crossover: Equatable {
    /// 买房期末净财富第一次明显高于租房的年份。从未出现则为 nil。
    var favorableFromYear: Int?
    /// 曾经更优之后，第一次转为明显不利的年份。
    var unfavorableFromYear: Int?

    static func detect(in horizons: [HorizonBreakdown]) -> Crossover {
        var favorableFromYear: Int?
        var unfavorableFromYear: Int?
        var hasBeenFavorable = false
        for point in horizons {
            if point.advantageFutureValue > NetWorthCalculator.parityTolerance {
                if favorableFromYear == nil {
                    favorableFromYear = point.years
                }
                hasBeenFavorable = true
            } else if point.advantageFutureValue < -NetWorthCalculator.parityTolerance {
                if hasBeenFavorable, unfavorableFromYear == nil {
                    unfavorableFromYear = point.years
                }
            }
        }
        return Crossover(favorableFromYear: favorableFromYear, unfavorableFromYear: unfavorableFromYear)
    }
}

struct Analysis: Equatable {
    var horizons: [HorizonBreakdown]
    var crossover: Crossover
    var isComputable: Bool

    static let unavailable = Analysis(
        horizons: [],
        crossover: Crossover(favorableFromYear: nil, unfavorableFromYear: nil),
        isComputable: false
    )

    func breakdown(for years: Int) -> HorizonBreakdown? {
        horizons.first { $0.years == years }
    }
}

/// 按月模拟，把现金流按投资回报复利到各年末，比较买房相对租房的期末净财富。
///
/// 月初已有的金额先按月复利，再计入本月末的支出。卖出净得落在期末，不再额外计息。
/// 优势 = 卖出净得 − 买入现金终值 − 持有成本终值 + 省下房租终值。
enum NetWorthCalculator {
    static let horizonLimit = 30
    static let parityTolerance = 1.0

    static func analyze(assumptions: Assumptions) -> Analysis {
        let assumptions = assumptions.sanitized
        guard assumptions.homePrice > 0 else { return .unavailable }

        let growth = 1 + Compounding.monthlyEffectiveRate(annual: assumptions.investmentReturn)

        var initialFV = assumptions.initialCash
        var holdingFV = 0.0
        var rentUnitFV = 0.0
        var scale = 1.0
        var horizons: [HorizonBreakdown] = []
        horizons.reserveCapacity(horizonLimit)

        for month in 1...(horizonLimit * 12) {
            initialFV *= growth
            holdingFV *= growth
            rentUnitFV *= growth
            scale *= growth

            let state = MonthlySimulation.state(month: month, assumptions: assumptions)
            holdingFV += state.holdingCost
            rentUnitFV += state.rentMultiplier

            guard month.isMultiple(of: 12) else { continue }

            let sale = state.saleProceeds(sellingCostRate: assumptions.sellingCostRate)
            let rentFV = assumptions.monthlyRent * rentUnitFV
            let advantage = sale - initialFV - holdingFV + rentFV
            let breakeven: Double?
            if rentUnitFV > 1e-8 {
                breakeven = (initialFV + holdingFV - sale) / rentUnitFV
            } else {
                breakeven = nil
            }

            horizons.append(
                HorizonBreakdown(
                    years: month / 12,
                    saleProceeds: sale,
                    initialCashFutureValue: initialFV,
                    holdingCostFutureValue: holdingFV,
                    rentFutureValue: rentFV,
                    advantageFutureValue: advantage,
                    advantageNPV: scale > 0 ? advantage / scale : advantage,
                    breakevenMonthlyRent: breakeven,
                    homeValue: state.homeValue,
                    loanBalance: state.loanBalanceAfterPayment,
                    monthlyPayment: state.mortgagePayment
                )
            )
        }

        return Analysis(
            horizons: horizons,
            crossover: Crossover.detect(in: horizons),
            isComputable: horizons.count == horizonLimit && horizons.allSatisfy { $0.advantageFutureValue.isFinite }
        )
    }
}
