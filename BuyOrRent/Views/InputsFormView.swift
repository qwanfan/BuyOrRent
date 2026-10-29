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

    private var currencySymbol: String { model.assumptions.country.currencySymbol }

    var body: some View {
        Section("国别和房型") {
            HStack {
                ParameterLabel(title: "国家", help: ParameterHelp.country)
                Spacer()
                Picker("国家", selection: countryBinding) {
                    ForEach(Country.allCases) { country in
                        Text(country.displayName).tag(country)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("国家")
            }

            HStack {
                ParameterLabel(title: "房型", help: ParameterHelp.housingType)
                Spacer()
                Picker("房型", selection: housingTypeBinding) {
                    ForEach(HousingType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("房型")
            }

            HStack {
                ParameterLabel(title: "更新利率", help: ParameterHelp.updateRate)
                Spacer()
                if model.mortgageRateState == .fetching {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("更新利率") {
                    Task { await model.refreshMortgageRate(force: true) }
                }
                .disabled(model.mortgageRateState == .fetching)
            }

            if let status = model.mortgageRateState.statusText {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                ParameterLabel(title: "更新房产成本", help: ParameterHelp.updatePropertyCosts)
                Spacer()
                if model.propertyCostState == .fetching {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("检查更新") {
                    Task { await model.refreshPropertyCosts(force: true) }
                }
                .disabled(model.propertyCostState == .fetching)
            }

            if let status = model.propertyCostState.statusText {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        Section("房价与贷款") {
            MoneyEditor(
                title: "买房款",
                help: ParameterHelp.homePrice,
                value: homePriceBinding,
                suffix: currencySymbol
            )
            PercentStepper(
                title: "首付比例",
                help: ParameterHelp.downPayment,
                fraction: $model.assumptions.downPaymentRatio,
                range: AssumptionBounds.downPayment,
                stepPercent: 1
            )
            YearStepper(
                title: "贷款年限",
                help: ParameterHelp.loanYears,
                years: $model.assumptions.loanYears,
                range: 1...40
            )
            PercentStepper(
                title: "贷款利率（年）",
                help: ParameterHelp.interestRate,
                fraction: $model.assumptions.annualInterestRate,
                range: AssumptionBounds.interest,
                stepPercent: 1,
                onStepperChange: { model.setMortgageRate($0, source: .stepper) },
                onManualChange: { model.setMortgageRate($0, source: .manual) }
            )
            YearStepper(
                title: "持有年限",
                help: ParameterHelp.horizonYears,
                years: $model.assumptions.horizonYears,
                range: 1...30
            )
        }

        Section("市场假设") {
            PercentStepper(
                title: "投资回报（年）",
                help: ParameterHelp.investmentReturn,
                fraction: $model.assumptions.investmentReturn,
                range: AssumptionBounds.investment,
                stepPercent: 1
            )
            PercentStepper(
                title: "房产增值（年）",
                help: ParameterHelp.appreciation,
                fraction: $model.assumptions.appreciationRate,
                range: AssumptionBounds.appreciation,
                stepPercent: 1,
                onStepperChange: { model.setAppreciationRate($0, source: .stepper) },
                onManualChange: { model.setAppreciationRate($0, source: .manual) }
            )
            PercentStepper(
                title: "租金升值（年）",
                help: ParameterHelp.rentGrowth,
                fraction: $model.assumptions.rentGrowthRate,
                range: AssumptionBounds.rentGrowth,
                stepPercent: 1,
                onStepperChange: { model.setRentGrowthRate($0, source: .stepper) },
                onManualChange: { model.setRentGrowthRate($0, source: .manual) }
            )
            MoneyEditor(
                title: "月房租",
                help: ParameterHelp.monthlyRent,
                value: monthlyRentBinding,
                suffix: "\(currencySymbol)/月"
            )
        }

        Section("持有成本") {
            PercentStepper(
                title: "房屋维修（年）",
                help: ParameterHelp.maintenance,
                fraction: $model.assumptions.maintenanceRate,
                range: AssumptionBounds.maintenance,
                stepPercent: 0.1
            )
            PercentStepper(
                title: "地税（年）",
                help: ParameterHelp.propertyTax,
                fraction: $model.assumptions.propertyTaxRate,
                range: AssumptionBounds.propertyTax,
                stepPercent: 0.1,
                onStepperChange: { model.setPropertyTaxRate($0) },
                onManualChange: { model.setPropertyTaxRate($0) }
            )
            PercentStepper(
                title: "房屋保险（年）",
                help: ParameterHelp.insurance,
                fraction: $model.assumptions.insuranceRate,
                range: AssumptionBounds.insurance,
                stepPercent: 0.1
            )
            MoneyEditor(
                title: "物业费（月）",
                help: ParameterHelp.hoa,
                value: $model.assumptions.monthlyHOA,
                suffix: "\(currencySymbol)/月"
            )
            PercentStepper(
                title: "贷款保险（年）",
                help: ParameterHelp.pmi,
                fraction: $model.assumptions.pmiRate,
                range: AssumptionBounds.pmi,
                stepPercent: 0.1
            )
        }

        Section("交易成本") {
            PercentStepper(
                title: "买入费率",
                help: ParameterHelp.buyingCost,
                fraction: $model.assumptions.buyingCostRate,
                range: AssumptionBounds.buyingCost,
                stepPercent: 0.1,
                onStepperChange: { model.setBuyingCostRate($0) },
                onManualChange: { model.setBuyingCostRate($0) }
            )
            PercentStepper(
                title: "卖出费率",
                help: ParameterHelp.sellingCost,
                fraction: $model.assumptions.sellingCostRate,
                range: AssumptionBounds.sellingCost,
                stepPercent: 0.1,
                onStepperChange: { model.setSellingCostRate($0) },
                onManualChange: { model.setSellingCostRate($0) }
            )
        }

        Section {
            Button("恢复默认参数") {
                model.resetAssumptions()
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var countryBinding: Binding<Country> {
        Binding(
            get: { model.assumptions.country },
            set: { model.applyCountry($0) }
        )
    }

    private var homePriceBinding: Binding<Double> {
        Binding(
            get: { model.assumptions.homePrice },
            set: { model.setHomePrice($0) }
        )
    }

    private var monthlyRentBinding: Binding<Double> {
        Binding(
            get: { model.assumptions.monthlyRent },
            set: { model.setMonthlyRent($0) }
        )
    }

    private var housingTypeBinding: Binding<HousingType> {
        Binding(
            get: { model.assumptions.housingType },
            set: { model.applyHousingType($0) }
        )
    }
}
