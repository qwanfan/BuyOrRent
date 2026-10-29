import Charts
import SwiftUI

struct AdvantageChartView: View {
    @Bindable var model: PlannerModel
    let analysis: Analysis
    @State private var isDraggingYear = false

    private var selectedYear: Int {
        min(max(model.assumptions.horizonYears, 1), NetWorthCalculator.horizonLimit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("期末净财富优势")
                .font(.headline)
            Text("纵轴是买房相对租房的期末财富差额。高于 0 表示买房更优。可按住曲线上的圆点左右拖动（每年一步），或调节下面三项。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Chart {
                ForEach(curvePieces) { piece in
                    chartSeries(points: piece.points, colorKey: piece.colorKey, seriesID: piece.id)
                }

                RuleMark(y: .value("持平", 0))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                if let year = crossingYear {
                    RuleMark(x: .value("转折", year))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .trailing, alignment: .top, spacing: 4) {
                            Text("第 \(year) 年")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .padding(.top, 2)
                        }
                }

                if let selected = analysis.breakdown(for: selectedYear) {
                    PointMark(
                        x: .value("持有年限", selected.years),
                        y: .value("净财富优势", selected.advantageFutureValue)
                    )
                    .foregroundStyle(selectedPointTint)
                    .symbolSize(isDraggingYear ? 140 : 100)
                    .annotation(position: yearLabelPosition(for: selected)) {
                        Text("\(selectedYear) 年")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.thinMaterial, in: Capsule())
                            .opacity(isDraggingYear ? 1 : 0.85)
                    }
                }
            }
            .chartXScale(domain: 1...NetWorthCalculator.horizonLimit)
            // 锁定纵轴范围，避免年份标注把曲线压扁。
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: [1, 5, 10, 15, 20, 25, 30]) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let year = value.as(Int.self) {
                            Text("\(year)年")
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(MoneyFormat.yuanCompact(amount, symbol: model.assumptions.country.currencySymbol))
                        }
                    }
                }
            }
            .chartForegroundStyleScale([
                "租房": Color.orange,
                "买房": Color.green,
                "租房阴影": Color.orange.opacity(0.15),
                "买房阴影": Color.green.opacity(0.15)
            ])
            .chartLegend(.hidden)
            .frame(height: 240)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDraggingYear = true
                                    updateYear(at: value.location, proxy: proxy, geometry: geometry)
                                }
                                .onEnded { _ in
                                    isDraggingYear = false
                                }
                        )
                }
            }
            .accessibilityLabel("1 到 30 年的期末净财富优势曲线，可拖动选择持有年限")

            HStack(alignment: .top, spacing: 12) {
                CompactYearStepper(
                    title: "持有年限",
                    years: $model.assumptions.horizonYears,
                    range: 1...30
                )
                CompactPercentStepper(
                    title: "投资回报（年）",
                    fraction: $model.assumptions.investmentReturn,
                    range: AssumptionBounds.investment,
                    stepPercent: 1
                )
                CompactPercentStepper(
                    title: "房产增值（年）",
                    fraction: $model.assumptions.appreciationRate,
                    range: AssumptionBounds.appreciation,
                    stepPercent: 1,
                    onStepperChange: { model.setAppreciationRate($0, source: .stepper) },
                    onManualChange: { model.setAppreciationRate($0, source: .manual) }
                )
            }
        }
    }

    /// 差额不低于 0 的年份为绿色（买房更优），低于 0 的年份为橙色（租房更优）。
    /// 换色处带上相邻的一年，两段曲线才能接上。
    private struct CurvePiece: Identifiable {
        let id: Int
        let colorKey: String
        let points: [HorizonBreakdown]
    }

    private var curvePieces: [CurvePiece] {
        let horizons = analysis.horizons
        guard !horizons.isEmpty else { return [] }
        var pieces: [CurvePiece] = []
        var currentBuy = horizons[0].advantageFutureValue >= 0
        var current: [HorizonBreakdown] = [horizons[0]]
        for point in horizons.dropFirst() {
            let buy = point.advantageFutureValue >= 0
            if buy == currentBuy {
                current.append(point)
            } else {
                pieces.append(CurvePiece(id: pieces.count, colorKey: currentBuy ? "买房" : "租房", points: current))
                currentBuy = buy
                current = [current.last, point].compactMap { $0 }
            }
        }
        pieces.append(CurvePiece(id: pieces.count, colorKey: currentBuy ? "买房" : "租房", points: current))
        return pieces
    }

    private var selectedPointTint: Color {
        let advantage = analysis.breakdown(for: selectedYear)?.advantageFutureValue ?? 0
        return advantage >= 0 ? .green : .orange
    }

    @ChartContentBuilder
    private func chartSeries(points: [HorizonBreakdown], colorKey: String, seriesID: Int) -> some ChartContent {
        ForEach(points) { point in
            AreaMark(
                x: .value("持有年限", point.years),
                y: .value("净财富优势", point.advantageFutureValue),
                series: .value("分段", "\(colorKey)阴影-\(seriesID)"),
                stacking: .unstacked
            )
            .foregroundStyle(by: .value("配色", "\(colorKey)阴影"))
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("持有年限", point.years),
                y: .value("净财富优势", point.advantageFutureValue),
                series: .value("分段", "\(colorKey)-\(seriesID)")
            )
            .foregroundStyle(by: .value("配色", colorKey))
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
    }

    /// 从不利转为有利的年份；一开始就有利时不额外画线。
    private var crossingYear: Int? {
        guard let year = analysis.crossover.favorableFromYear, year > 1 else { return nil }
        return year
    }

    /// 仅按曲线数据定纵轴，不把标注高度算进刻度。
    private var yDomain: ClosedRange<Double> {
        let values = analysis.horizons.map(\.advantageFutureValue)
        guard let minValue = values.min(), let maxValue = values.max() else { return -1...1 }
        let span = max(maxValue - minValue, 1)
        let padding = span * 0.08
        let lower = min(minValue, 0) - padding
        let upper = max(maxValue, 0) + padding
        return lower...upper
    }

    /// 绿点靠近图顶时，年份放到下方，避免挤占上方空间。
    private func yearLabelPosition(for selected: HorizonBreakdown) -> AnnotationPosition {
        let span = yDomain.upperBound - yDomain.lowerBound
        guard span > 0 else { return .top }
        let relative = (selected.advantageFutureValue - yDomain.lowerBound) / span
        return relative > 0.72 ? .bottom : .top
    }

    private func updateYear(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let origin = geometry[plotFrame].origin
        let x = location.x - origin.x
        let year: Int
        if let value: Int = proxy.value(atX: x) {
            year = value
        } else if let value: Double = proxy.value(atX: x) {
            year = Int(value.rounded())
        } else {
            return
        }
        let clamped = min(max(year, 1), NetWorthCalculator.horizonLimit)
        if model.assumptions.horizonYears != clamped {
            model.assumptions.horizonYears = clamped
        }
    }
}
