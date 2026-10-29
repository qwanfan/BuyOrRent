import Foundation

/// 某个月末的房价、贷款和持有成本。现金流都记在月末。
struct MonthState: Equatable {
    var homeValue: Double
    var mortgagePayment: Double
    var maintenance: Double
    var propertyTax: Double
    var insurance: Double
    var hoa: Double
    var pmi: Double
    var holdingCost: Double
    /// 相对初始月租的倍数：租金每满一年才调整一次。
    var rentMultiplier: Double
    var loanBalanceAfterPayment: Double

    func saleProceeds(sellingCostRate: Double) -> Double {
        homeValue * (1 - sellingCostRate) - loanBalanceAfterPayment
    }
}

enum MonthlySimulation {
    static func state(month: Int, assumptions: Assumptions) -> MonthState {
        let homeValue = assumptions.homeValue(atMonth: month)
        let balanceBeforePayment = Amortization.balance(
            principal: assumptions.loanPrincipal,
            annualRate: assumptions.annualInterestRate,
            termMonths: assumptions.loanTermMonths,
            paymentsMade: month - 1
        )
        let mortgagePayment = Amortization.paymentDue(
            principal: assumptions.loanPrincipal,
            annualRate: assumptions.annualInterestRate,
            termMonths: assumptions.loanTermMonths,
            month: month
        )
        let balanceAfterPayment = Amortization.balance(
            principal: assumptions.loanPrincipal,
            annualRate: assumptions.annualInterestRate,
            termMonths: assumptions.loanTermMonths,
            paymentsMade: month
        )

        let maintenance = homeValue * assumptions.maintenanceRate / 12
        let propertyTax = homeValue * assumptions.propertyTaxRate / 12
        let insurance = homeValue * assumptions.insuranceRate / 12
        let pmi = assumptions.monthlyPMI(balance: balanceBeforePayment, homeValue: homeValue)
        let holdingCost = mortgagePayment + maintenance + propertyTax + insurance + assumptions.monthlyHOA + pmi
        let completedYears = (month - 1) / 12
        let rentMultiplier = pow(1 + assumptions.rentGrowthRate, Double(completedYears))

        return MonthState(
            homeValue: homeValue,
            mortgagePayment: mortgagePayment,
            maintenance: maintenance,
            propertyTax: propertyTax,
            insurance: insurance,
            hoa: assumptions.monthlyHOA,
            pmi: pmi,
            holdingCost: holdingCost,
            rentMultiplier: rentMultiplier,
            loanBalanceAfterPayment: balanceAfterPayment
        )
    }
}
