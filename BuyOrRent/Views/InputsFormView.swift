import SwiftUI

struct InputsFormView: View {
    @Bindable var model: PlannerModel

    var body: some View {
        Form {
            InputSections(model: model)
        }
        .formStyle(.grouped)
    }
}

struct InputSections: View {
    @Bindable var model: PlannerModel
    var onShowResults: (() -> Void)? = nil
    @State private var collapsedCategories: Set<String> = []

    var body: some View {
        CountryInputs(model: model, collapsed: $collapsedCategories, onShowResults: onShowResults)
        PriceInputs(model: model, collapsed: $collapsedCategories)
        MarketInputs(model: model, collapsed: $collapsedCategories)
        HoldingInputs(model: model, collapsed: $collapsedCategories)
        TransactionInputs(model: model, collapsed: $collapsedCategories)
        ResetInputs(model: model)
    }
}

private struct CountryInputs: View {
    @Bindable var model: PlannerModel
    @Binding var collapsed: Set<String>
    var onShowResults: (() -> Void)? = nil

    private var copy: L10n { L10n(model.assumptions.country) }

    var body: some View {
        Section {
            if collapsed.isExpanded("country") {
                HStack {
                    ParameterLabel(title: copy.country, help: copy.helpCountry)
                    Spacer()
                    CountryMenu(model: model)
                }
                HStack {
                    ParameterLabel(title: copy.homeType, help: copy.helpHousingType)
                    Spacer()
                    Picker(copy.homeType, selection: housingTypeBinding) {
                        ForEach(HousingType.allCases) { type in
                            Text(verbatim: copy.housingName(type)).tag(type)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel(copy.homeType)
                }
            }
        } header: {
            HStack(alignment: .center, spacing: 8) {
                CategoryHeader(id: "country", title: copy.sectionCountry, collapsed: $collapsed, copy: copy)
                if let onShowResults {
                    PageSwitchButton(title: copy.resultsTitle, action: onShowResults)
                        .textCase(nil)
                }
            }
            .textCase(nil)
        }
    }

    private var housingTypeBinding: Binding<HousingType> {
        Binding(
            get: { model.assumptions.housingType },
            set: { model.applyHousingType($0) }
        )
    }
}

private struct PriceInputs: View {
    @Bindable var model: PlannerModel
    @Binding var collapsed: Set<String>

    private var copy: L10n { L10n(model.assumptions.country) }
    private var currencySymbol: String { model.assumptions.country.currencySymbol }

    var body: some View {
        Section {
            if collapsed.isExpanded("price") {
                MoneyEditor(
                    title: copy.purchasePrice,
                    help: copy.helpHomePrice,
                    value: homePriceBinding,
                    suffix: currencySymbol
                )
                PercentStepper(
                    title: copy.downPayment,
                    help: copy.helpDownPayment,
                    fraction: $model.assumptions.downPaymentRatio,
                    range: AssumptionBounds.downPayment,
                    stepPercent: 1
                )
                YearStepper(
                    title: copy.loanTerm,
                    help: copy.helpLoanYears,
                    years: $model.assumptions.loanYears,
                    range: 1...40
                )
                ParameterSourceRow(sourceLabel: copy.sourceLabel, source: model.mortgageRateSourceText) {
                    PercentStepper(
                        title: copy.mortgageRate,
                        help: copy.helpInterestRate,
                        fraction: $model.assumptions.annualInterestRate,
                        range: AssumptionBounds.interest,
                        stepPercent: 1,
                        onStepperChange: { model.setMortgageRate($0, source: .stepper) },
                        onManualChange: { model.setMortgageRate($0, source: .manual) }
                    )
                }
                YearStepper(
                    title: copy.holdingPeriod,
                    help: copy.helpHorizonYears,
                    years: $model.assumptions.horizonYears,
                    range: 1...30
                )
            }
        } header: {
            CategoryHeader(id: "price", title: copy.sectionPrice, collapsed: $collapsed, copy: copy)
        }
    }

    private var homePriceBinding: Binding<Double> {
        Binding(
            get: { model.assumptions.homePrice },
            set: { model.setHomePrice($0) }
        )
    }
}

private struct MarketInputs: View {
    @Bindable var model: PlannerModel
    @Binding var collapsed: Set<String>

    private var copy: L10n { L10n(model.assumptions.country) }

    var body: some View {
        Section {
            if collapsed.isExpanded("market") {
                ParameterSourceRow(sourceLabel: copy.sourceLabel, source: model.investmentReturnSourceText) {
                    PercentStepper(
                        title: copy.investmentReturn,
                        help: copy.helpInvestmentReturn,
                        fraction: $model.assumptions.investmentReturn,
                        range: AssumptionBounds.investment,
                        stepPercent: 1,
                        onStepperChange: { model.setInvestmentReturn($0) },
                        onManualChange: { model.setInvestmentReturn($0) }
                    )
                }
                ParameterSourceRow(sourceLabel: copy.sourceLabel, source: model.appreciationSourceText) {
                    PercentStepper(
                        title: copy.appreciation,
                        help: copy.helpAppreciation,
                        fraction: $model.assumptions.appreciationRate,
                        range: AssumptionBounds.appreciation,
                        stepPercent: 1,
                        onStepperChange: { model.setAppreciationRate($0, source: .stepper) },
                        onManualChange: { model.setAppreciationRate($0, source: .manual) }
                    )
                }
                ParameterSourceRow(sourceLabel: copy.sourceLabel, source: model.rentGrowthSourceText) {
                    PercentStepper(
                        title: copy.rentGrowth,
                        help: copy.helpRentGrowth,
                        fraction: $model.assumptions.rentGrowthRate,
                        range: AssumptionBounds.rentGrowth,
                        stepPercent: 1,
                        onStepperChange: { model.setRentGrowthRate($0, source: .stepper) },
                        onManualChange: { model.setRentGrowthRate($0, source: .manual) }
                    )
                }
                ParameterSourceRow(sourceLabel: copy.sourceLabel, source: model.monthlyRentSourceText) {
                    MoneyEditor(
                        title: copy.monthlyRent,
                        help: copy.helpMonthlyRent,
                        value: monthlyRentBinding,
                        suffix: copy.perMonth(model.assumptions.country.currencySymbol)
                    )
                }
            }
        } header: {
            CategoryHeader(id: "market", title: copy.sectionMarket, collapsed: $collapsed, copy: copy)
        }
    }

    private var monthlyRentBinding: Binding<Double> {
        Binding(
            get: { model.assumptions.monthlyRent },
            set: { model.setMonthlyRent($0) }
        )
    }
}

private struct HoldingInputs: View {
    @Bindable var model: PlannerModel
    @Binding var collapsed: Set<String>

    private var copy: L10n { L10n(model.assumptions.country) }

    var body: some View {
        Section {
            if collapsed.isExpanded("holding") {
                PercentStepper(
                    title: copy.maintenance,
                    help: copy.helpMaintenance,
                    fraction: $model.assumptions.maintenanceRate,
                    range: AssumptionBounds.maintenance,
                    stepPercent: 0.1
                )
                ParameterSourceRow(sourceLabel: copy.sourceLabel, source: model.propertyTaxSourceText) {
                    PercentStepper(
                        title: copy.propertyTax,
                        help: copy.helpPropertyTax,
                        fraction: $model.assumptions.propertyTaxRate,
                        range: AssumptionBounds.propertyTax,
                        stepPercent: 0.1,
                        onStepperChange: { model.setPropertyTaxRate($0) },
                        onManualChange: { model.setPropertyTaxRate($0) }
                    )
                }
                PercentStepper(
                    title: copy.insurance,
                    help: copy.helpInsurance,
                    fraction: $model.assumptions.insuranceRate,
                    range: AssumptionBounds.insurance,
                    stepPercent: 0.1
                )
                MoneyEditor(
                    title: copy.hoa,
                    help: copy.helpHOA,
                    value: $model.assumptions.monthlyHOA,
                    suffix: copy.perMonth(model.assumptions.country.currencySymbol)
                )
                PercentStepper(
                    title: copy.mortgageInsurance,
                    help: copy.helpPMI,
                    fraction: $model.assumptions.pmiRate,
                    range: AssumptionBounds.pmi,
                    stepPercent: 0.1
                )
            }
        } header: {
            CategoryHeader(id: "holding", title: copy.sectionHolding, collapsed: $collapsed, copy: copy)
        }
    }
}

private struct TransactionInputs: View {
    @Bindable var model: PlannerModel
    @Binding var collapsed: Set<String>

    private var copy: L10n { L10n(model.assumptions.country) }

    var body: some View {
        Section {
            if collapsed.isExpanded("transaction") {
                ParameterSourceRow(sourceLabel: copy.sourceLabel, source: model.buyingCostSourceText) {
                    PercentStepper(
                        title: copy.buyingCost,
                        help: copy.helpBuyingCost,
                        fraction: $model.assumptions.buyingCostRate,
                        range: AssumptionBounds.buyingCost,
                        stepPercent: 0.1,
                        onStepperChange: { model.setBuyingCostRate($0) },
                        onManualChange: { model.setBuyingCostRate($0) }
                    )
                }
                ParameterSourceRow(sourceLabel: copy.sourceLabel, source: model.sellingCostSourceText) {
                    PercentStepper(
                        title: copy.sellingCost,
                        help: copy.helpSellingCost,
                        fraction: $model.assumptions.sellingCostRate,
                        range: AssumptionBounds.sellingCost,
                        stepPercent: 0.1,
                        onStepperChange: { model.setSellingCostRate($0) },
                        onManualChange: { model.setSellingCostRate($0) }
                    )
                }
            }
        } header: {
            CategoryHeader(id: "transaction", title: copy.sectionTransaction, collapsed: $collapsed, copy: copy)
        }
    }
}

private struct ResetInputs: View {
    @Bindable var model: PlannerModel

    private var copy: L10n { L10n(model.assumptions.country) }

    var body: some View {
        Section {
            Button {
                model.resetAssumptions()
            } label: {
                if model.isRestoringDefaults {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(verbatim: copy.resetDefaults)
                }
            }
            .disabled(model.isRestoringDefaults)
            .frame(maxWidth: .infinity, alignment: .center)
        } footer: {
            Text(verbatim: copy.resetFooter)
        }
    }
}

private struct CategoryHeader: View {
    let id: String
    let title: String
    @Binding var collapsed: Set<String>
    let copy: L10n

    private let categoryBlue = Color(red: 0x0d / 255, green: 0x75 / 255, blue: 0xa8 / 255)

    var body: some View {
        let expanded = collapsed.isExpanded(id)
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                collapsed.toggle(id)
            }
        } label: {
            HStack(spacing: 6) {
                Text(verbatim: title)
                    .font(.body)
                    .foregroundStyle(categoryBlue)
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(categoryBlue)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(expanded ? copy.expanded : copy.collapsed)
        .accessibilityAddTraits(.isHeader)
    }
}

/// 参数和来源放在同一行里，Form 就不会在两者之间画分隔线。
private struct ParameterSourceRow<Content: View>: View {
    let sourceLabel: String
    let source: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
            if let source {
                sourceLine(source)
            }
        }
    }

    @ViewBuilder
    private func sourceLine(_ source: String) -> some View {
        if let parts = SourceCaptionParts.splitting(source, label: sourceLabel) {
            highlightedSource(parts, fullText: source)
        } else {
            Text(verbatim: source)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func highlightedSource(_ parts: SourceCaptionParts, fullText: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(verbatim: parts.label)
                .font(.caption)
                .foregroundStyle(Color.black)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.yellow, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            Text(verbatim: parts.remainder)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(fullText)
    }
}

/// 系统弹出菜单会按当前选中项向上展开。国家行靠近窗口顶部时，前面的国家会被屏幕裁掉，而且不能滚动。
private struct CountryMenu: View {
    @Bindable var model: PlannerModel
    @State private var isPresented = false

    private var copy: L10n { L10n(model.assumptions.country) }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 4) {
                Text(verbatim: copy.countryName(model.assumptions.country))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(copy.country)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            CountryMenuList(model: model)
                .presentationCompactAdaptation(.popover)
        }
    }
}

private struct CountryMenuList: View {
    @Bindable var model: PlannerModel

    private var copy: L10n { L10n(model.assumptions.country) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Country.allCases) { country in
                        CountryMenuRow(model: model, country: country, name: copy.countryName(country))
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.visible)
            .frame(width: 240, height: 320)
            .onAppear {
                proxy.scrollTo(model.assumptions.country, anchor: .center)
            }
        }
    }
}

private struct CountryMenuRow: View {
    @Bindable var model: PlannerModel
    let country: Country
    let name: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            model.applyCountry(country)
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Text(verbatim: name)
                Spacer(minLength: 16)
                if country == model.assumptions.country {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(country)
    }
}

private extension Set where Element == String {
    func isExpanded(_ id: String) -> Bool {
        !contains(id)
    }

    mutating func toggle(_ id: String) {
        if contains(id) {
            remove(id)
        } else {
            insert(id)
        }
    }
}
