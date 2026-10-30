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
    var language: AppLanguage = .zhHans
    var pageSwitchTitle: String? = nil
    var onPageSwitch: (() -> Void)? = nil

    private var copy: L10n { L10n(language: language) }

    private var verdict: Verdict {
        Verdict(advantage: breakdown.advantageFutureValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(copy.verdictWord(verdict))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(verdict.tint)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(copy.verdictDetail(verdict))
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(copy.verdictWord(verdict))，\(copy.verdictDetail(verdict))")
                Spacer(minLength: 8)
                if let pageSwitchTitle, let onPageSwitch {
                    PageSwitchButton(title: pageSwitchTitle, action: onPageSwitch)
                }
            }

            AdvantageFormulaView(breakdown: breakdown, currencySymbol: currencySymbol, language: language)

            Text("\(copy.endingGapCaption) \(copy.crossover(crossover))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 12
            ) {
                stat(copy.monthlyPayment, breakdown.monthlyPayment)
                stat(copy.endingHomeValue, breakdown.homeValue)
                stat(copy.loanBalance, breakdown.loanBalance)
            }
        }
    }

    private func stat(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(MoneyFormat.money(value, symbol: currencySymbol, language: language))
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
