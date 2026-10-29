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
        // 两类数据独立刷新；房产成本只有在缓存缺失或距上次成功检查满 30 天时才联网。
        .task {
            async let mortgage: Void = model.refreshMortgageRate(force: false)
            async let propertyCosts: Void = model.refreshPropertyCosts(force: false)
            _ = await (mortgage, propertyCosts)
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

    var body: some View {
        NavigationSplitView {
            InputsFormView(model: model)
                .navigationTitle("参数")
        } detail: {
            ResultsPage(model: model)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

/// iPhone 单栏：结论、曲线、明细和参数在同一页滚动。
struct CompactPlannerView: View {
    @Bindable var model: PlannerModel

    var body: some View {
        NavigationStack {
            Form {
                ResultsSections(model: model)
                InputSections(model: model)
            }
            .formStyle(.grouped)
            .navigationTitle("Buy or Rent")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

private struct ResultsPage: View {
    @Bindable var model: PlannerModel

    var body: some View {
        let analysis = model.analysis
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if analysis.isComputable, let breakdown = selectedBreakdown(in: analysis) {
                    card {
                        ResultSummaryView(
                            breakdown: breakdown,
                            crossover: analysis.crossover,
                            currencySymbol: model.assumptions.country.currencySymbol
                        )
                    }
                    card {
                        AdvantageChartView(model: model, analysis: analysis)
                    }
                } else {
                    ContentUnavailableView(
                        "无法计算",
                        systemImage: "house",
                        description: Text("请输入大于 0 的买房款。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                }
            }
            .padding()
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Buy or Rent")
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

    var body: some View {
        let analysis = model.analysis

        if analysis.isComputable, let breakdown = selectedBreakdown(in: analysis) {
            Section {
                ResultSummaryView(
                    breakdown: breakdown,
                    crossover: analysis.crossover,
                    currencySymbol: model.assumptions.country.currencySymbol
                )
            }
            Section {
                AdvantageChartView(model: model, analysis: analysis)
            }
        } else {
            Section {
                ContentUnavailableView(
                    "无法计算",
                    systemImage: "house",
                    description: Text("请输入大于 0 的买房款。")
                )
            }
        }
    }

    private func selectedBreakdown(in analysis: Analysis) -> HorizonBreakdown? {
        let year = min(max(model.assumptions.horizonYears, 1), NetWorthCalculator.horizonLimit)
        return analysis.breakdown(for: year)
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
