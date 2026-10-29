import Foundation

enum MoneyFormat {
    private static let yuanStyle = FloatingPointFormatStyle<Double>.Currency(code: "CNY")
        .precision(.fractionLength(0))
        .locale(Locale(identifier: "zh_CN"))

    private static let compactNumber = FloatingPointFormatStyle<Double>.number
        .precision(.fractionLength(1))
        .locale(Locale(identifier: "zh_CN"))

    static func yuan(_ value: Double) -> String {
        value.formatted(yuanStyle)
    }

    /// 以指定货币符号显示金额。金额不做汇率换算，只换符号。
    static func money(_ value: Double, symbol: String) -> String {
        if symbol == "¥" { return yuan(value) }
        let sign = value < 0 ? "-" : ""
        let grouped = abs(value).formatted(.number.precision(.fractionLength(0)).grouping(.automatic).locale(Locale(identifier: "zh_CN")))
        return sign + symbol + grouped
    }

    /// 坐标轴用的短金额。不用系统 compact notation，以兼容 macOS 14 / iOS 17。
    static func yuanCompact(_ value: Double) -> String {
        yuanCompact(value, symbol: "¥")
    }

    static func yuanCompact(_ value: Double, symbol: String) -> String {
        let sign = value < 0 ? "-" : ""
        let magnitude = abs(value)
        if magnitude >= 100_000_000 {
            return sign + symbol + (magnitude / 100_000_000).formatted(compactNumber) + "亿"
        }
        if magnitude >= 10_000 {
            return sign + symbol + (magnitude / 10_000).formatted(compactNumber) + "万"
        }
        return money(value, symbol: symbol)
    }
}

enum CrossoverCopy {
    static func text(_ crossover: Crossover) -> String {
        switch (crossover.favorableFromYear, crossover.unfavorableFromYear) {
        case (nil, _):
            return "在 1–30 年内，买房的期末净财富都没有超过租房。"
        case (1, nil):
            return "从第 1 年起，买房的期末净财富就更高。"
        case (let year?, nil):
            return "大约从第 \(year) 年起，买房转为更划算。"
        case (1, let later?):
            return "第 1 年买房更优，但从第 \(later) 年起转为租房更划算。"
        case (let year?, let later?):
            return "大约从第 \(year) 年到第 \(later - 1) 年，买房更划算；第 \(later) 年起转为租房。"
        }
    }
}
