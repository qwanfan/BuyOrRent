import SwiftUI

enum Verdict: Equatable {
    case buy
    case rent
    case tie

    init(advantage: Double) {
        if advantage > NetWorthCalculator.parityTolerance {
            self = .buy
        } else if advantage < -NetWorthCalculator.parityTolerance {
            self = .rent
        } else {
            self = .tie
        }
    }

    var word: String {
        switch self {
        case .buy: "Buy"
        case .rent: "Rent"
        case .tie: "Tie"
        }
    }

    var detail: String {
        switch self {
        case .buy: "买房更划算"
        case .rent: "租房更划算"
        case .tie: "两边大致持平"
        }
    }

    var tint: Color {
        switch self {
        case .buy: .green
        case .rent: .orange
        case .tie: .secondary
        }
    }
}

struct ResultSummaryView: View {
    let breakdown: HorizonBreakdown
    let crossover: Crossover
    var currencySymbol: String = "¥"

    private var verdict: Verdict {
        Verdict(advantage: breakdown.advantageFutureValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verdict.word)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(verdict.tint)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(verdict.detail)
                    .font(.title3.weight(.semibold))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(verdict.word)，\(verdict.detail)")

            metricRow(
                title: "期末净财富差额",
                value: breakdown.advantageFutureValue,
                caption: "买房比租房多出的期末财富。正数表示买房更优。"
            )

            AdvantageFormulaView(breakdown: breakdown, currencySymbol: currencySymbol)

            Text(CrossoverCopy.text(crossover))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 12
            ) {
                stat("月供", breakdown.monthlyPayment)
                stat("期末房价", breakdown.homeValue)
                stat("贷款余额", breakdown.loanBalance)
            }
        }
    }

    private func metricRow(title: String, value: Double, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            LabeledContent(title) {
                Text(MoneyFormat.money(value, symbol: currencySymbol))
                    .monospacedDigit()
                    .fontWeight(.semibold)
                    .foregroundStyle(value >= 0 ? Color.green : Color.orange)
            }
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stat(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(MoneyFormat.money(value, symbol: currencySymbol))
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
