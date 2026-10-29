import XCTest
@testable import BuyOrRent

final class NetWorthCalculatorTests: XCTestCase {
    func testZeroRatesMatchUndiscountedCash() {
        var assumptions = Assumptions()
        assumptions.annualInterestRate = 0
        assumptions.investmentReturn = 0
        assumptions.appreciationRate = 0
        assumptions.rentGrowthRate = 0
        assumptions.maintenanceRate = 0.01
        assumptions.propertyTaxRate = 0.008
        assumptions.insuranceRate = 0.0035
        assumptions.pmiRate = 0.005
        assumptions.buyingCostRate = 0.02
        assumptions.sellingCostRate = 0.05
        assumptions.monthlyHOA = 0
        assumptions.monthlyRent = 2_500

        let point = breakdown(assumptions, years: 1)
        XCTAssertEqual(point.advantageFutureValue, -27_558.75, accuracy: 0.02)
        XCTAssertEqual(point.advantageNPV, point.advantageFutureValue, accuracy: 0.000_001)
        XCTAssertEqual(point.loanBalance, 522_000, accuracy: 0.02)
        XCTAssertEqual(point.monthlyPayment, 1_500, accuracy: 0.000_001)
    }

    func testDownPaymentCompoundsAtFullInvestmentReturn() {
        var assumptions = Assumptions()
        assumptions.downPaymentRatio = 1
        assumptions.investmentReturn = 0.05
        assumptions.appreciationRate = 0
        assumptions.maintenanceRate = 0
        assumptions.propertyTaxRate = 0
        assumptions.insuranceRate = 0
        assumptions.buyingCostRate = 0
        assumptions.sellingCostRate = 0
        assumptions.monthlyRent = 0
        assumptions.monthlyHOA = 0
        assumptions.pmiRate = 0

        let point = breakdown(assumptions, years: 1)
        XCTAssertEqual(point.initialCashFutureValue, 600_000 * 1.05, accuracy: 0.05)
        XCTAssertEqual(point.advantageFutureValue, 600_000 - 600_000 * 1.05, accuracy: 0.05)
        XCTAssertEqual(point.monthlyPayment, 0, accuracy: 0.000_001)
        XCTAssertEqual(point.loanBalance, 0, accuracy: 0.000_001)
    }

    func testCarryingCostsFollowAppreciatedValue() {
        var flat = Assumptions()
        flat.downPaymentRatio = 1
        flat.investmentReturn = 0
        flat.appreciationRate = 0
        flat.maintenanceRate = 0.01
        flat.propertyTaxRate = 0
        flat.insuranceRate = 0
        flat.buyingCostRate = 0
        flat.sellingCostRate = 0
        flat.monthlyRent = 0
        flat.monthlyHOA = 0
        flat.pmiRate = 0
        flat.rentGrowthRate = 0
        flat.annualInterestRate = 0

        var growing = flat
        growing.appreciationRate = 0.07

        let flatPoint = breakdown(flat, years: 1)
        let growingPoint = breakdown(growing, years: 1)

        XCTAssertEqual(flatPoint.holdingCostFutureValue, 6_000, accuracy: 0.02)
        XCTAssertEqual(flatPoint.saleProceeds, 600_000, accuracy: 0.02)
        XCTAssertEqual(flatPoint.advantageFutureValue, -6_000, accuracy: 0.02)
        XCTAssertEqual(growingPoint.saleProceeds, 642_000, accuracy: 0.05)
        XCTAssertGreaterThan(growingPoint.holdingCostFutureValue, flatPoint.holdingCostFutureValue)
    }

    func testBreakevenRentReturnsZeroAdvantage() {
        let cases: [(Int, Assumptions)] = [
            (10, Assumptions()),
            (30, Assumptions()),
            (12, {
                var assumptions = Assumptions()
                assumptions.appreciationRate = 0.02
                assumptions.investmentReturn = 0.08
                assumptions.rentGrowthRate = 0.03
                return assumptions
            }()),
        ]

        for (years, assumptions) in cases {
            let original = breakdown(assumptions, years: years)
            guard let breakeven = original.breakevenMonthlyRent else {
                XCTFail("缺少盈亏平衡租金 \(years)")
                continue
            }
            var plugged = assumptions
            plugged.monthlyRent = breakeven
            let again = breakdown(plugged, years: years)
            XCTAssertEqual(again.advantageFutureValue, 0, accuracy: 0.05, "years \(years)")
        }
    }

    func testHigherRentImprovesBuying() {
        var low = Assumptions()
        low.monthlyRent = 1_000
        var high = Assumptions()
        high.monthlyRent = 5_000

        let lowAdvantage = breakdown(low, years: 10).advantageFutureValue
        let highAdvantage = breakdown(high, years: 10).advantageFutureValue
        XCTAssertGreaterThan(highAdvantage, lowAdvantage)
    }

    func testPaymentAndBalanceAreZeroAfterLoanEnds() {
        var assumptions = Assumptions()
        assumptions.loanYears = 15
        let atMaturity = breakdown(assumptions, years: 15)
        let afterMaturity = breakdown(assumptions, years: 16)
        XCTAssertEqual(atMaturity.loanBalance, 0, accuracy: 0.05)
        XCTAssertEqual(
            atMaturity.monthlyPayment,
            Amortization.monthlyPayment(
                principal: assumptions.loanPrincipal,
                annualRate: assumptions.annualInterestRate,
                termMonths: assumptions.loanTermMonths
            ),
            accuracy: 0.01
        )
        XCTAssertEqual(afterMaturity.loanBalance, 0, accuracy: 0.01)
        XCTAssertEqual(afterMaturity.monthlyPayment, 0, accuracy: 0.01)
    }

    func testZeroRentGrowthStaysFinite() {
        var assumptions = Assumptions()
        assumptions.rentGrowthRate = 0
        assumptions.annualInterestRate = 0
        assumptions.investmentReturn = 0
        assumptions.appreciationRate = 0
        let analysis = NetWorthCalculator.analyze(assumptions: assumptions)
        XCTAssertTrue(analysis.isComputable)
        XCTAssertEqual(analysis.horizons.count, 30)
        XCTAssertTrue(analysis.horizons.allSatisfy {
            $0.advantageFutureValue.isFinite && $0.breakevenMonthlyRent?.isFinite == true
        })
    }

    func testNonPositivePriceIsNotComputable() {
        var assumptions = Assumptions()
        assumptions.homePrice = 0
        XCTAssertFalse(NetWorthCalculator.analyze(assumptions: assumptions).isComputable)
    }

    func testNetPresentValueUsesTheSameCompounding() {
        let point = breakdown(Assumptions(), years: 10)
        let grown = point.advantageNPV * pow(1.04, 10)
        XCTAssertEqual(grown, point.advantageFutureValue, accuracy: 1)
    }

    private func breakdown(_ assumptions: Assumptions, years: Int) -> HorizonBreakdown {
        let analysis = NetWorthCalculator.analyze(assumptions: assumptions)
        XCTAssertTrue(analysis.isComputable)
        guard let point = analysis.breakdown(for: years) else {
            XCTFail("缺少年份 \(years)")
            return HorizonBreakdown(
                years: years,
                saleProceeds: 0,
                initialCashFutureValue: 0,
                holdingCostFutureValue: 0,
                rentFutureValue: 0,
                advantageFutureValue: 0,
                advantageNPV: 0,
                breakevenMonthlyRent: nil,
                homeValue: 0,
                loanBalance: 0,
                monthlyPayment: 0
            )
        }
        return point
    }
}
