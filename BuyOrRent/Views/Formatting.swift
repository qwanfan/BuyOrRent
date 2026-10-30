import Foundation

enum MoneyFormat {
    private static let yuanStyle = FloatingPointFormatStyle<Double>.Currency(code: "CNY")
        .precision(.fractionLength(0))
        .locale(Locale(identifier: "zh_CN"))

    static func yuan(_ value: Double) -> String {
        value.formatted(yuanStyle)
    }

    /// 以指定货币符号显示金额。金额不做汇率换算，只换符号。分组方式跟着界面语言。
    static func money(_ value: Double, symbol: String, language: AppLanguage = .zhHans) -> String {
        if language == .zhHans && symbol == "¥" { return yuan(value) }
        let sign = value < 0 ? "-" : ""
        let grouped = abs(value).formatted(
            .number.precision(.fractionLength(0)).grouping(.automatic).locale(L10n(language: language).locale)
        )
        return sign + symbol + grouped
    }

    /// 坐标轴用的短金额。不用系统 compact notation，以兼容 macOS 14 / iOS 17。
    static func yuanCompact(_ value: Double) -> String {
        yuanCompact(value, symbol: "¥")
    }

    static func yuanCompact(_ value: Double, symbol: String, language: AppLanguage = .zhHans) -> String {
        let copy = L10n(language: language)
        let sign = value < 0 ? "-" : ""
        let magnitude = abs(value)
        if let scale = copy.compactScale(for: magnitude) {
            let number = (magnitude / scale.divisor).formatted(
                .number.precision(.fractionLength(1)).locale(copy.locale)
            )
            return sign + symbol + number + scale.suffix
        }
        return money(value, symbol: symbol, language: language)
    }
}

enum CrossoverCopy {
    static func text(_ crossover: Crossover, language: AppLanguage = .zhHans) -> String {
        L10n(language: language).crossover(crossover)
    }
}
