import Foundation

/// 等额本息。月利率按名义年利率 / 12，与常见按揭口径一致。
enum Amortization {
    static func monthlyPayment(principal: Double, annualRate: Double, termMonths: Int) -> Double {
        guard principal > 0, termMonths > 0 else { return 0 }
        let monthlyRate = annualRate / 12
        if abs(monthlyRate) < 1e-12 {
            return principal / Double(termMonths)
        }
        let factor = pow(1 + monthlyRate, Double(termMonths))
        return principal * monthlyRate * factor / (factor - 1)
    }

    /// 已还 `paymentsMade` 期之后的剩余本金。超过期限则为 0。
    static func balance(
        principal: Double,
        annualRate: Double,
        termMonths: Int,
        paymentsMade: Int
    ) -> Double {
        guard principal > 0, termMonths > 0 else { return 0 }
        if paymentsMade <= 0 { return principal }
        if paymentsMade >= termMonths { return 0 }

        let monthlyRate = annualRate / 12
        if abs(monthlyRate) < 1e-12 {
            return principal * (1 - Double(paymentsMade) / Double(termMonths))
        }

        let growthOverTerm = pow(1 + monthlyRate, Double(termMonths))
        let growthSoFar = pow(1 + monthlyRate, Double(paymentsMade))
        return principal * (growthOverTerm - growthSoFar) / (growthOverTerm - 1)
    }

    /// 第 `month` 期（从 1 计）应还的月供。贷款到期后为 0。
    static func paymentDue(
        principal: Double,
        annualRate: Double,
        termMonths: Int,
        month: Int
    ) -> Double {
        guard month >= 1, month <= termMonths else { return 0 }
        return monthlyPayment(principal: principal, annualRate: annualRate, termMonths: termMonths)
    }
}

enum Compounding {
    /// 把年化收益率换成等价月利率，使连乘 12 个月后回到 `(1 + 年利率)`。
    static func monthlyEffectiveRate(annual: Double) -> Double {
        let safe = min(max(annual, -0.9), 1)
        return pow(1 + safe, 1.0 / 12.0) - 1
    }
}
