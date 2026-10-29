import XCTest
@testable import BuyOrRent

final class AmortizationTests: XCTestCase {
    func testDefaultMortgageMatchesKnownSchedule() {
        let principal = 540_000.0
        let payment = Amortization.monthlyPayment(principal: principal, annualRate: 0.03, termMonths: 360)
        XCTAssertEqual(payment, 2276.6617821390323, accuracy: 0.001)

        let balanceAfterFiveYears = Amortization.balance(
            principal: principal,
            annualRate: 0.03,
            termMonths: 360,
            paymentsMade: 60
        )
        XCTAssertEqual(balanceAfterFiveYears, 480_094.36207216553, accuracy: 0.01)

        let balanceAtMaturity = Amortization.balance(
            principal: principal,
            annualRate: 0.03,
            termMonths: 360,
            paymentsMade: 360
        )
        XCTAssertEqual(balanceAtMaturity, 0, accuracy: 0.000_001)
    }

    func testClosedFormMatchesMonthByMonthRecurrence() {
        let principal = 540_000.0
        let annualRate = 0.03
        let payment = Amortization.monthlyPayment(principal: principal, annualRate: annualRate, termMonths: 360)
        let monthlyRate = annualRate / 12
        var balance = principal
        for month in 1...60 {
            balance = balance * (1 + monthlyRate) - payment
            let closed = Amortization.balance(
                principal: principal,
                annualRate: annualRate,
                termMonths: 360,
                paymentsMade: month
            )
            XCTAssertEqual(balance, closed, accuracy: 0.02, "month \(month)")
        }
    }

    func testZeroInterestIsStraightLine() {
        let payment = Amortization.monthlyPayment(principal: 120_000, annualRate: 0, termMonths: 120)
        XCTAssertEqual(payment, 1_000, accuracy: 0.000_001)
        XCTAssertEqual(
            Amortization.balance(principal: 120_000, annualRate: 0, termMonths: 120, paymentsMade: 30),
            90_000,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            Amortization.balance(principal: 120_000, annualRate: 0, termMonths: 120, paymentsMade: 120),
            0,
            accuracy: 0.000_001
        )
    }

    func testPaymentStopsAfterTerm() {
        XCTAssertEqual(
            Amortization.paymentDue(principal: 120_000, annualRate: 0.04, termMonths: 120, month: 120),
            Amortization.monthlyPayment(principal: 120_000, annualRate: 0.04, termMonths: 120),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            Amortization.paymentDue(principal: 120_000, annualRate: 0.04, termMonths: 120, month: 121),
            0,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            Amortization.balance(principal: 120_000, annualRate: 0.04, termMonths: 120, paymentsMade: 121),
            0,
            accuracy: 0.000_001
        )
    }

    func testNoPrincipalHasNoPayment() {
        XCTAssertEqual(Amortization.monthlyPayment(principal: 0, annualRate: 0.03, termMonths: 360), 0)
        XCTAssertEqual(
            Amortization.balance(principal: 0, annualRate: 0.03, termMonths: 360, paymentsMade: 12),
            0
        )
    }
}
