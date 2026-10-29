import SwiftUI

/// 期末净财富差额公式，并在下方对齐显示当前数值。
struct AdvantageFormulaView: View {
    let breakdown: HorizonBreakdown
    var currencySymbol: String = "¥"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                formulaGrid(compact: false)
                ScrollView(.horizontal, showsIndicators: false) {
                    formulaGrid(compact: true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("期末净财富差额公式")
    }

    private func formulaGrid(compact: Bool) -> some View {
        Grid(alignment: .center, horizontalSpacing: compact ? 4 : 6, verticalSpacing: 6) {
            GridRow(alignment: .firstTextBaseline) {
                termHeader("期末净财富差额", help: ParameterHelp.advantage)
                operatorText("=")
                termHeader("卖出净得", help: ParameterHelp.saleProceeds)
                operatorText("−")
                termHeader("买入现金的终值", help: ParameterHelp.initialCashFV)
                operatorText("−")
                termHeader("持有成本的终值", help: ParameterHelp.holdingCostFV)
                operatorText("+")
                termHeader("省下房租的终值", help: ParameterHelp.savedRentFV)
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
        Text(MoneyFormat.money(value, symbol: currencySymbol))
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
