import Charts
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct AdvantageChartView: View {
    @Bindable var model: PlannerModel
    let analysis: Analysis
    @State private var isDraggingYear = false
    #if os(macOS)
    /// 这次按下离曲线太远，整段手势都不再改年份。
    @State private var ignoresCurrentDrag = false
    #endif
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// 约一指宽。按下时离曲线超过这个距离就不开始拖动。
    private static let curveHitDistance: CGFloat = 36
    /// 圆点的圆形感应范围。按在这个圆里，上下左右都能拖。
    private static let pointHitDistance: CGFloat = 72

    private var selectedYear: Int {
        min(max(model.assumptions.horizonYears, 1), NetWorthCalculator.horizonLimit)
    }

    private var copy: L10n { L10n(model.assumptions.country) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(copy.chartTitle)
                .font(.headline)
            Text(copy.chartCaption)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

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
                            Text(copy.markedYear(year))
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
                        Text(copy.selectedYear(selectedYear))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.background, in: Capsule())
                            .overlay {
                                Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                            }
                            .allowsHitTesting(false)
                    }
                    .annotation(position: calloutPosition(for: selectedYear), spacing: 8) {
                        pointCallout(for: selected)
                            .allowsHitTesting(false)
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
                    // 30 年落在绘图区右边界，轴标签会被裁掉，改在 overlay 里补上。
                    if value.as(Int.self) != NetWorthCalculator.horizonLimit {
                        AxisValueLabel {
                            if let year = value.as(Int.self) {
                                Text(copy.axisYear(year))
                            }
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(MoneyFormat.yuanCompact(amount, symbol: model.assumptions.country.currencySymbol, language: copy.language))
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
                    if let plotFrame = proxy.plotFrame {
                        let plot = geometry[plotFrame]
                        // 文字左缘贴在绘图区右边界外侧，避免压在曲线末端。
                        Text(copy.axisYear(NetWorthCalculator.horizonLimit))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .offset(x: plot.maxX + 4, y: plot.maxY + 4)
                            .allowsHitTesting(false)
                    }
                    #if os(iOS)
                    // 离曲线较远，或明显是上下滑时，手势直接失败，页面可以滚动。
                    ChartCurveDragOverlay(
                        hit: { chartDragHit(at: $0, proxy: proxy, geometry: geometry) },
                        onDrag: { location in
                            isDraggingYear = true
                            updateYear(at: location, proxy: proxy, geometry: geometry)
                        },
                        onDragEnd: { isDraggingYear = false },
                        onTap: { updateYear(at: $0, proxy: proxy, geometry: geometry) }
                    )
                    #else
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard !ignoresCurrentDrag else { return }
                                    if !isDraggingYear, chartDragHit(at: value.location, proxy: proxy, geometry: geometry) == .none {
                                        ignoresCurrentDrag = true
                                        return
                                    }
                                    isDraggingYear = true
                                    updateYear(at: value.location, proxy: proxy, geometry: geometry)
                                }
                                .onEnded { _ in
                                    isDraggingYear = false
                                    ignoresCurrentDrag = false
                                }
                        )
                    #endif
                }
            }
            .accessibilityLabel(copy.chartAccessibility)

            chartControls
        }
    }

    @ViewBuilder
    private var chartControls: some View {
        if horizontalSizeClass == .compact {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    holdingControl.frame(maxWidth: .infinity, alignment: .leading)
                    investmentControl.frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                    appreciationControl.frame(maxWidth: .infinity, alignment: .leading)
                    rentControl.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                holdingControl
                investmentControl
                appreciationControl
                rentControl
            }
        }
    }

    private var holdingControl: some View {
        CompactYearStepper(
            title: copy.holdingPeriod,
            years: $model.assumptions.horizonYears,
            range: 1...30
        )
    }

    private var investmentControl: some View {
        CompactPercentStepper(
            title: copy.investmentReturn,
            fraction: $model.assumptions.investmentReturn,
            range: AssumptionBounds.investment,
            stepPercent: 1,
            onStepperChange: { model.setInvestmentReturn($0) },
            onManualChange: { model.setInvestmentReturn($0) }
        )
    }

    private var appreciationControl: some View {
        CompactPercentStepper(
            title: copy.appreciation,
            fraction: $model.assumptions.appreciationRate,
            range: AssumptionBounds.appreciation,
            stepPercent: 1,
            onStepperChange: { model.setAppreciationRate($0, source: .stepper) },
            onManualChange: { model.setAppreciationRate($0, source: .manual) }
        )
    }

    private var rentControl: some View {
        CompactMoneyStepper(
            title: copy.monthlyRent,
            value: $model.assumptions.monthlyRent,
            suffix: copy.perMonth(model.assumptions.country.currencySymbol),
            onChange: { model.setMonthlyRent($0) }
        )
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

    /// 一直显示在圆点旁边。靠右时改到左侧，避免挡住纵轴。
    private func calloutPosition(for year: Int) -> AnnotationPosition {
        year >= 18 ? .leading : .trailing
    }

    /// 该年末的月租：与模拟一致，每满一年才按租金升值调整一次。
    private func monthlyRent(at year: Int) -> Double {
        let assumptions = model.assumptions.sanitized
        let state = MonthlySimulation.state(month: year * 12, assumptions: assumptions)
        return assumptions.monthlyRent * state.rentMultiplier
    }

    private func pointCallout(for selected: HorizonBreakdown) -> some View {
        let symbol = model.assumptions.country.currencySymbol
        let language = copy.language
        return Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 3) {
            GridRow {
                Text(copy.saleProceeds)
                    .foregroundStyle(.secondary)
                Text(MoneyFormat.money(selected.saleProceeds, symbol: symbol, language: language))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            GridRow {
                Text(copy.monthlyRent)
                    .foregroundStyle(.secondary)
                Text(MoneyFormat.money(monthlyRent(at: selected.years), symbol: symbol, language: language) + copy.perMonth(""))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
    }

    /// 绿点靠近图顶时，年份放到下方，避免挤占上方空间。
    private func yearLabelPosition(for selected: HorizonBreakdown) -> AnnotationPosition {
        let span = yDomain.upperBound - yDomain.lowerBound
        guard span > 0 else { return .top }
        let relative = (selected.advantageFutureValue - yDomain.lowerBound) / span
        return relative > 0.72 ? .bottom : .top
    }

    /// 按下时贴近曲线或圆点才有命中。拖动开始后不再调用。
    private func chartDragHit(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) -> ChartDragHit {
        guard let plotFrame = proxy.plotFrame else { return .none }
        let origin = geometry[plotFrame].origin
        let x = location.x - origin.x
        let y = location.y - origin.y

        if let selected = analysis.breakdown(for: selectedYear),
           let dotX = proxy.position(forX: selected.years),
           let dotY = proxy.position(forY: selected.advantageFutureValue) {
            let dx = x - dotX
            let dy = y - dotY
            if dx * dx + dy * dy <= Self.pointHitDistance * Self.pointHitDistance {
                return .point
            }
        }

        let limit = NetWorthCalculator.horizonLimit
        guard let startX = proxy.position(forX: 1),
              let endX = proxy.position(forX: limit),
              endX != startX else { return .none }
        let pointsPerYear = abs(endX - startX) / CGFloat(limit - 1)
        let rawYear = 1 + Double((x - startX) / (endX - startX)) * Double(limit - 1)
        let slackYears = Double(Self.curveHitDistance / pointsPerYear)
        guard rawYear >= 1 - slackYears, rawYear <= Double(limit) + slackYears else { return .none }

        let yearValue = min(max(rawYear, 1), Double(limit))
        let lowerYear = Int(yearValue.rounded(.down))
        let upperYear = min(Int(yearValue.rounded(.up)), limit)
        guard let lower = analysis.breakdown(for: lowerYear),
              let upper = analysis.breakdown(for: upperYear) else { return .none }
        let fraction = upperYear == lowerYear ? 0 : (yearValue - Double(lowerYear)) / Double(upperYear - lowerYear)
        let advantage = lower.advantageFutureValue + (upper.advantageFutureValue - lower.advantageFutureValue) * fraction
        guard let curveY = proxy.position(forY: advantage) else { return .none }
        return abs(y - curveY) <= Self.curveHitDistance ? .curve : .none
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

private enum ChartDragHit {
    case none
    case curve
    case point
}

#if os(iOS)
/// 贴着曲线时，只有横向滑动才改年份，上下滑留给页面。按在圆点上则任意方向都拖动年份。
private struct ChartCurveDragOverlay: UIViewRepresentable {
    var hit: (CGPoint) -> ChartDragHit
    var onDrag: (CGPoint) -> Void
    var onDragEnd: () -> Void
    var onTap: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ChartDragSurface {
        let view = ChartDragSurface()
        view.backgroundColor = .clear
        view.isAccessibilityElement = false

        let pan = ChartYearPanRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        pan.maximumNumberOfTouches = 1

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        tap.require(toFail: pan)

        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: ChartDragSurface, context: Context) {
        uiView.hit = hit
        context.coordinator.hit = hit
        context.coordinator.onDrag = onDrag
        context.coordinator.onDragEnd = onDragEnd
        context.coordinator.onTap = onTap
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ChartDragSurface, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var hit: (CGPoint) -> ChartDragHit = { _ in .none }
        var onDrag: (CGPoint) -> Void = { _ in }
        var onDragEnd: () -> Void = {}
        var onTap: (CGPoint) -> Void = { _ in }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let location = recognizer.location(in: recognizer.view)
            switch recognizer.state {
            case .began, .changed:
                onDrag(location)
            case .ended, .cancelled:
                onDrag(location)
                onDragEnd()
            case .failed:
                onDragEnd()
            default:
                break
            }
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            let location = recognizer.location(in: recognizer.view)
            guard hit(location) != .none else { return }
            onTap(location)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            let location = touch.location(in: gestureRecognizer.view)
            if let pan = gestureRecognizer as? ChartYearPanRecognizer {
                pan.startLocation = location
            }
            return hit(location) != .none
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? ChartYearPanRecognizer else { return true }
            if hit(pan.startLocation) == .point { return true }
            let velocity = pan.velocity(in: pan.view)
            if hypot(velocity.x, velocity.y) < 1 {
                let translation = pan.translation(in: pan.view)
                return abs(translation.x) > abs(translation.y)
            }
            return abs(velocity.x) > abs(velocity.y)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? ChartYearPanRecognizer else { return false }
            guard hit(pan.startLocation) == .point else { return false }
            return otherGestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer.view is UIScrollView
        }
    }
}

/// 按在圆点上时记住起点，方便判断这次拖动不必让给页面滚动。
private final class ChartYearPanRecognizer: UIPanGestureRecognizer {
    var startLocation: CGPoint = .zero

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        startLocation = touches.first?.location(in: view) ?? startLocation
        super.touchesBegan(touches, with: event)
    }
}

/// 只有贴近曲线或圆点的位置才接住触摸，其余位置留给外层滚动。
private final class ChartDragSurface: UIView {
    var hit: (CGPoint) -> ChartDragHit = { _ in .none }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        hit(point) != .none
    }
}
#endif
