import SwiftUI

struct ContentView: View {
    @State private var model = PlannerModel()

    var body: some View {
        Group {
            #if os(macOS)
            SplitPlannerView(model: model)
            #else
            AdaptivePlannerView(model: model)
            #endif
        }
        // 开机检查房产成本表，并拉取各国主指数回报。成功且用户未手改时，才显示来源。
        .environment(\.appLanguage, model.assumptions.country.appLanguage)
        .task {
            await model.refreshPropertyCosts(force: false, attemptNetwork: true)
            await model.refreshInvestmentReturn(force: false)
        }
    }
}

#if os(iOS)
private struct AdaptivePlannerView: View {
    @Bindable var model: PlannerModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .compact {
            CompactPlannerView(model: model)
        } else {
            SplitPlannerView(model: model)
        }
    }
}
#endif

struct SplitPlannerView: View {
    @Bindable var model: PlannerModel

    private var copy: L10n { L10n(model.assumptions.country) }

    var body: some View {
        NavigationSplitView {
            InputsFormView(model: model)
                .navigationTitle(copy.parametersTitle)
        } detail: {
            ResultsPage(model: model)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

/// iPhone 紧凑宽度：结论和参数分成两页，用页内右上角按钮切换。
struct CompactPlannerView: View {
    @Bindable var model: PlannerModel
    @State private var showsInputs = false

    var body: some View {
        NavigationStack {
            Group {
                if showsInputs {
                    parameterForm
                } else {
                    resultsForm
                }
            }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
    }

    private var parameterForm: some View {
        Form {
            InputSections(model: model, onShowResults: { showsInputs = false })
        }
        .formStyle(.grouped)
    }

    private var resultsForm: some View {
        Form {
            ResultsSections(model: model, onShowInputs: { showsInputs = true })
        }
        .formStyle(.grouped)
        #if os(iOS)
        // 分组列表默认段间距大约 35，顶部内容边距大约 16。这里都收到一半。
        .listSectionSpacing(18)
        .contentMargins(.top, 8, for: .scrollContent)
        #endif
    }
}

private struct ResultsPage: View {
    @Bindable var model: PlannerModel

    private var copy: L10n { L10n(model.assumptions.country) }

    var body: some View {
        let analysis = model.analysis
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if analysis.isComputable, let breakdown = selectedBreakdown(in: analysis) {
                    card {
                        ResultSummaryView(
                            breakdown: breakdown,
                            crossover: analysis.crossover,
                            currencySymbol: model.assumptions.country.currencySymbol,
                            language: model.assumptions.country.appLanguage
                        )
                    }
                    card {
                        AdvantageChartView(model: model, analysis: analysis)
                    }
                } else {
                    ContentUnavailableView(
                        copy.cannotCalculate,
                        systemImage: "house",
                        description: Text(copy.enterPurchasePrice)
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                }
            }
            .padding()
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .modifier(HiddenPageTitle())
        .background(Color.platformGroupedBackground)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func selectedBreakdown(in analysis: Analysis) -> HorizonBreakdown? {
        let year = min(max(model.assumptions.horizonYears, 1), NetWorthCalculator.horizonLimit)
        return analysis.breakdown(for: year)
    }
}

struct ResultsSections: View {
    @Bindable var model: PlannerModel
    var onShowInputs: (() -> Void)? = nil

    private var copy: L10n { L10n(model.assumptions.country) }

    var body: some View {
        let analysis = model.analysis

        if analysis.isComputable, let breakdown = selectedBreakdown(in: analysis) {
            Section {
                ResultSummaryView(
                    breakdown: breakdown,
                    crossover: analysis.crossover,
                    currencySymbol: model.assumptions.country.currencySymbol,
                    language: model.assumptions.country.appLanguage,
                    pageSwitchTitle: onShowInputs == nil ? nil : copy.parametersTitle,
                    onPageSwitch: onShowInputs
                )
            }
            Section {
                AdvantageChartView(model: model, analysis: analysis)
            }
        } else {
            Section {
                if let onShowInputs {
                    HStack {
                        Spacer(minLength: 0)
                        PageSwitchButton(title: copy.parametersTitle, action: onShowInputs)
                    }
                }
                ContentUnavailableView(
                    copy.cannotCalculate,
                    systemImage: "house",
                    description: Text(copy.enterPurchasePrice)
                )
            }
        }
    }

    private func selectedBreakdown(in analysis: Analysis) -> HorizonBreakdown? {
        let year = min(max(model.assumptions.horizonYears, 1), NetWorthCalculator.horizonLimit)
        return analysis.breakdown(for: year)
    }
}

struct PageSwitchButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(verbatim: title)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

/// 结果页不显示标题。空的 navigationTitle 仍会在工具栏中间留一块占位。
private struct HiddenPageTitle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15, iOS 18, *) {
            content.toolbar(removing: .title)
        } else {
            content.navigationTitle("")
        }
    }
}

private extension Color {
    static var platformGroupedBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }
}

#Preview {
    ContentView()
}
