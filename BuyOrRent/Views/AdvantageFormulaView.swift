import SwiftUI

/// 期末净财富差额公式，并在下方对齐显示当前数值。
struct AdvantageFormulaView: View {
    let breakdown: HorizonBreakdown
    var currencySymbol: String = "¥"
    var language: AppLanguage = .zhHans

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var copy: L10n { L10n(language: language) }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                verticalFormula
            } else {
                ViewThatFits(in: .horizontal) {
                    formulaGrid(compact: false)
                    ScrollView(.horizontal, showsIndicators: false) {
                        formulaGrid(compact: true)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(copy.formulaAccessibility)
    }

    private var verticalFormula: some View {
        VStack(alignment: .leading, spacing: 10) {
            formulaLine(prefix: "", title: copy.endingGap, help: copy.helpAdvantage, value: breakdown.advantageFutureValue, emphasize: true)
            formulaLine(prefix: "=", title: copy.saleProceeds, help: copy.helpSaleProceeds, value: breakdown.saleProceeds)
            formulaLine(prefix: "−", title: copy.initialCashFV, help: copy.helpInitialCashFV, value: breakdown.initialCashFutureValue)
            formulaLine(prefix: "−", title: copy.holdingCostFV, help: copy.helpHoldingCostFV, value: breakdown.holdingCostFutureValue)
            formulaLine(prefix: "+", title: copy.savedRentFV, help: copy.helpSavedRentFV, value: breakdown.rentFutureValue)
        }
    }

    private func formulaLine(prefix: String, title: String, help: String, value: Double, emphasize: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(alignment: .top, spacing: 2) {
                Text(prefix.isEmpty ? title : "\(prefix) \(title)")
                    .font(.subheadline.weight(emphasize ? .semibold : .medium))
                    .fixedSize(horizontal: false, vertical: true)
                ParameterHelpButton(title: title, help: help)
                    .offset(y: -2)
            }
            Spacer(minLength: 8)
            Text(MoneyFormat.money(value, symbol: currencySymbol, language: language))
                .font(emphasize ? .subheadline.weight(.semibold) : .subheadline.monospacedDigit())
                .monospacedDigit()
                .foregroundStyle(emphasize ? (value >= 0 ? Color.green : Color.orange) : Color.primary)
                .layoutPriority(1)
        }
    }

    private func formulaGrid(compact: Bool) -> some View {
        Grid(alignment: .center, horizontalSpacing: compact ? 4 : 6, verticalSpacing: 6) {
            GridRow(alignment: .firstTextBaseline) {
                termHeader(copy.endingGap, help: copy.helpAdvantage)
                operatorText("=")
                termHeader(copy.saleProceeds, help: copy.helpSaleProceeds)
                operatorText("−")
                termHeader(copy.initialCashFV, help: copy.helpInitialCashFV)
                operatorText("−")
                termHeader(copy.holdingCostFV, help: copy.helpHoldingCostFV)
                operatorText("+")
                termHeader(copy.savedRentFV, help: copy.helpSavedRentFV)
            }

            GridRow(alignment: .firstTextBaseline) {
                termValue(breakdown.advantageFutureValue, emphasize: true)
                operatorText("")
                termValue(breakdown.saleProceeds)
                operatorText("")
                termValue(breakdown.initialCashFutureValue)
                operatorText("")
                termValue(breakdown.holdingCostFutureValue)
                operatorText("")
                termValue(breakdown.rentFutureValue)
            }
        }
    }

    private func termHeader(_ title: String, help: String) -> some View {
        HStack(alignment: .top, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: true, vertical: false)
            ParameterHelpButton(title: title, help: help)
                .offset(y: -2)
        }
        .gridColumnAlignment(.center)
    }

    private func termValue(_ value: Double, emphasize: Bool = false) -> some View {
        Text(MoneyFormat.money(value, symbol: currencySymbol, language: language))
            .font(emphasize ? .subheadline.weight(.semibold) : .subheadline.monospacedDigit())
            .monospacedDigit()
            .foregroundStyle(emphasize ? (value >= 0 ? Color.green : Color.orange) : Color.primary)
            .gridColumnAlignment(.center)
    }

    private func operatorText(_ symbol: String) -> some View {
        Text(symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(minWidth: symbol.isEmpty ? 8 : 14)
    }
}
