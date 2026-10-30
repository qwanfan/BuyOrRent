import SwiftUI

struct MoneyEditor: View {
    let title: String
    let help: String
    @Binding var value: Double
    var suffix: String
    var allowsNegative = false

    private var fieldValue: Binding<Double> {
        Binding(
            get: { value },
            set: { newValue in
                let finite = newValue.isFinite ? newValue : 0
                value = allowsNegative ? finite : max(0, finite)
            }
        )
    }

    var body: some View {
        LabeledContent {
            HStack(spacing: 4) {
                TextField(
                    "",
                    value: fieldValue,
                    format: .number.precision(.fractionLength(0)).grouping(.automatic)
                )
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                #endif
                .accessibilityLabel(title)
                Text(suffix)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 200)
        } label: {
            ParameterLabel(title: title, help: help)
        }
    }
}

struct YearStepper: View {
    let title: String
    let help: String
    @Binding var years: Int
    var range: ClosedRange<Int>
    @Environment(\.appLanguage) private var appLanguage

    private var yearsBinding: Binding<Int> {
        Binding(
            get: { years },
            set: { years = min(max($0, range.lowerBound), range.upperBound) }
        )
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ParameterLabel(title: title, help: help)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField(
                "",
                value: yearsBinding,
                format: .number.precision(.fractionLength(0))
            )
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .frame(width: 44)
            .accessibilityLabel(title)
            Text(L10n(language: appLanguage).yearUnit)
                .foregroundStyle(.secondary)
            Stepper("", value: yearsBinding, in: range)
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel(title)
        }
    }
}

/// 紧凑金额控件：标签在上，金额与步进器在下。数值未变时不回调，避免焦点离开被当成手动修改。
struct CompactMoneyStepper: View {
    let title: String
    @Binding var value: Double
    var suffix: String
    var range: ClosedRange<Double> = 0...1_000_000
    var step: Double = 100
    var onChange: ((Double) -> Void)?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var amountBinding: Binding<Double> {
        Binding(
            get: { value.rounded() },
            set: { apply($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: 4) {
                TextField(
                    "",
                    value: amountBinding,
                    format: .number.precision(.fractionLength(0)).grouping(.automatic)
                )
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .frame(minWidth: 52, maxWidth: 88)
                .accessibilityLabel(title)
                Text(suffix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if horizontalSizeClass == .compact {
                    Spacer(minLength: 4)
                }
                Stepper("", value: amountBinding, in: range, step: step)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityLabel(title)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func apply(_ newValue: Double) {
        let finite = newValue.isFinite ? newValue : 0
        let clamped = min(max(finite, range.lowerBound), range.upperBound)
        guard abs(clamped - value) >= 0.5 else { return }
        if let onChange {
            onChange(clamped)
        } else {
            value = clamped
        }
    }
}

/// 紧凑控件：标签在上，数值与步进器在下，适合并排摆放。
struct CompactYearStepper: View {
    let title: String
    @Binding var years: Int
    var range: ClosedRange<Int>
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var yearsBinding: Binding<Int> {
        Binding(
            get: { years },
            set: { years = min(max($0, range.lowerBound), range.upperBound) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: 4) {
                TextField(
                    "",
                    value: yearsBinding,
                    format: .number.precision(.fractionLength(0))
                )
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .frame(minWidth: 28, maxWidth: 40)
                .accessibilityLabel(title)
                Text(L10n(language: appLanguage).yearUnit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if horizontalSizeClass == .compact {
                    Spacer(minLength: 4)
                }
                Stepper("", value: yearsBinding, in: range)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityLabel(title)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CompactPercentStepper: View {
    let title: String
    @Binding var fraction: Double
    var range: ClosedRange<Double>
    var stepPercent: Double = 1
    var onStepperChange: ((Double) -> Void)?
    var onManualChange: ((Double) -> Void)?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private static let inputPrecision = 0.1

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: 4) {
                TextField(
                    "",
                    value: manualBinding,
                    format: .number.precision(.fractionLength(0...1))
                )
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .frame(minWidth: 36, maxWidth: 48)
                .accessibilityLabel(title)
                Text("%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if horizontalSizeClass == .compact {
                    Spacer(minLength: 4)
                }
                Stepper("", value: stepperBinding, in: percentRange, step: stepPercent)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityLabel(title)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var percentRange: ClosedRange<Double> {
        let lower = Self.snap(range.lowerBound * 100, to: Self.inputPrecision)
        let upper = Self.snap(range.upperBound * 100, to: Self.inputPrecision)
        return lower...upper
    }

    private var stepperBinding: Binding<Double> {
        Binding(
            get: { Self.snap(fraction * 100, to: Self.inputPrecision) },
            set: { apply($0, source: .stepper) }
        )
    }

    private var manualBinding: Binding<Double> {
        Binding(
            get: { Self.snap(fraction * 100, to: Self.inputPrecision) },
            set: { apply($0, source: .manual) }
        )
    }

    private func apply(_ percentPoints: Double, source: RateEditSource) {
        let snapped = Self.snap(percentPoints, to: Self.inputPrecision)
        let displayed = Self.snap(fraction * 100, to: Self.inputPrecision)
        // 焦点离开时输入框会交回当前显示值。数字没变就不记成手动修改。
        guard snapped != displayed else { return }
        let clamped = min(max(snapped / 100, range.lowerBound), range.upperBound)
        let fractionValue = Self.snap(clamped * 100, to: Self.inputPrecision) / 100
        switch source {
        case .stepper:
            if let onStepperChange {
                onStepperChange(fractionValue)
            } else {
                fraction = fractionValue
            }
        case .manual:
            if let onManualChange {
                onManualChange(fractionValue)
            } else {
                fraction = fractionValue
            }
        }
    }

    private static func snap(_ value: Double, to step: Double) -> Double {
        guard step > 0, value.isFinite else { return 0 }
        return (value / step).rounded() * step
    }
}

/// 百分比步进：右侧可手动输入（始终允许一位小数）+ 上下箭头按 `stepPercent` 增减。
struct PercentStepper: View {
    let title: String
    let help: String
    @Binding var fraction: Double
    var range: ClosedRange<Double>
    /// 每次步进的百分点，例如 `1` 或 `0.1`。
    var stepPercent: Double = 1
    var onStepperChange: ((Double) -> Void)?
    var onManualChange: ((Double) -> Void)?

    /// 手动输入统一精确到百分点后一位（0.1%）。
    private static let inputPrecision = 0.1

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ParameterLabel(title: title, help: help)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField(
                "",
                value: manualBinding,
                format: .number.precision(.fractionLength(0...1))
            )
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            #if os(iOS)
            .keyboardType(.decimalPad)
            #endif
            .frame(width: 56)
            .accessibilityLabel(title)
            Text("%")
                .foregroundStyle(.secondary)
            Stepper("", value: stepperBinding, in: percentRange, step: stepPercent)
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel(title)
        }
    }

    private var percentRange: ClosedRange<Double> {
        let lower = Self.snap(range.lowerBound * 100, to: Self.inputPrecision)
        let upper = Self.snap(range.upperBound * 100, to: Self.inputPrecision)
        return lower...upper
    }

    private var stepperBinding: Binding<Double> {
        Binding(
            get: { Self.snap(fraction * 100, to: Self.inputPrecision) },
            set: { apply($0, source: .stepper) }
        )
    }

    private var manualBinding: Binding<Double> {
        Binding(
            get: { Self.snap(fraction * 100, to: Self.inputPrecision) },
            set: { apply($0, source: .manual) }
        )
    }

    private func apply(_ percentPoints: Double, source: RateEditSource) {
        let snapped = Self.snap(percentPoints, to: Self.inputPrecision)
        let displayed = Self.snap(fraction * 100, to: Self.inputPrecision)
        // 焦点离开时输入框会交回当前显示值。数字没变就不记成手动修改。
        guard snapped != displayed else { return }
        let clamped = min(max(snapped / 100, range.lowerBound), range.upperBound)
        let fractionValue = Self.snap(clamped * 100, to: Self.inputPrecision) / 100
        switch source {
        case .stepper:
            if let onStepperChange {
                onStepperChange(fractionValue)
            } else {
                fraction = fractionValue
            }
        case .manual:
            if let onManualChange {
                onManualChange(fractionValue)
            } else {
                fraction = fractionValue
            }
        }
    }

    /// 按步进网格取整，避免浮点误差。
    private static func snap(_ value: Double, to step: Double) -> Double {
        guard step > 0, value.isFinite else { return 0 }
        return (value / step).rounded() * step
    }
}
