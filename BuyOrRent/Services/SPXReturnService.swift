import Foundation

struct SPXReturnQuote: Equatable, Codable, Sendable {
    var rate: Double
    var startDate: String
    var endDate: String
    var sourceName: String
}

enum SPXReturnError: Error, Equatable {
    case unreadable
    case insufficient
    case outOfRange
}

/// 标普 500 日线的 10 年价格年化回报，不含股息。算法与原先生成脚本一致。
enum SPXReturnParser {
    static let csvURL = URL(string: "https://fred.stlouisfed.org/graph/fredgraph.csv?id=SP500")!
    static let sourceName = "FRED：S&P 500"

    static func parse(_ csv: String, asOf: Date = Date(), calendar: Calendar = .current) throws -> SPXReturnQuote {
        let today = startOfDay(asOf, calendar: calendar)
        let points = prices(in: csv, calendar: calendar).filter { $0.date <= today }
        guard let end = points.last else { throw SPXReturnError.insufficient }
        let target = subtractingYears(10, from: end.date, calendar: calendar)
        let before = points.filter { $0.date <= target }
        let after = points.filter { $0.date >= target }
        let start: (date: Date, level: Double)
        if let last = before.last, days(from: last.date, to: target, calendar: calendar) <= 10 {
            start = last
        } else if let first = after.first, days(from: target, to: first.date, calendar: calendar) <= 10 {
            start = first
        } else {
            throw SPXReturnError.insufficient
        }

        let span = days(from: start.date, to: end.date, calendar: calendar)
        guard (3650 - 20)...(3650 + 20) ~= span else { throw SPXReturnError.insufficient }
        let raw = pow(end.level / start.level, 365.25 / Double(span)) - 1
        let rate = (raw * 10_000).rounded() / 10_000
        guard (-0.5...0.5).contains(rate) else { throw SPXReturnError.outOfRange }
        return SPXReturnQuote(
            rate: rate,
            startDate: isoDate(start.date, calendar: calendar),
            endDate: isoDate(end.date, calendar: calendar),
            sourceName: sourceName
        )
    }

    private static func prices(in csv: String, calendar: Calendar) -> [(date: Date, level: Double)] {
        csv.split(whereSeparator: \.isNewline).compactMap { line in
            let pieces = line.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard pieces.count >= 2,
                  let observed = dateOnly(pieces[0], calendar: calendar),
                  let level = Double(pieces[1]),
                  level > 0 else {
                return nil
            }
            return (observed, level)
        }.sorted { $0.date < $1.date }
    }

    private static func subtractingYears(_ years: Int, from date: Date, calendar: Calendar) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        var target = DateComponents()
        target.year = (parts.year ?? 0) - years
        target.month = parts.month
        target.day = parts.day
        if let resolved = calendar.date(from: target) {
            return startOfDay(resolved, calendar: calendar)
        }
        target.day = 28
        return startOfDay(calendar.date(from: target) ?? date, calendar: calendar)
    }

    private static func days(from start: Date, to end: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: startOfDay(start, calendar: calendar), to: startOfDay(end, calendar: calendar)).day ?? 0
    }

    private static func startOfDay(_ date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }

    private static func dateOnly(_ text: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text)
    }

    private static func isoDate(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// 启动时向 FRED 查询标普 500。失败时用上次缓存，再没有才用种子。
struct SPXReturnService {
    static let seedRate = 0.1377
    private static let cacheKey = "spxReturn.v1"

    var now: @Sendable () -> Date = { Date() }
    var fetchData: @Sendable (URL) async throws -> Data = { url in
        try await RemoteFetch.fetch(url, timeout: 30)
    }
    var cacheDefaults: UserDefaults = .standard

    func fetchQuote() async throws -> SPXReturnQuote {
        let data = try await fetchData(SPXReturnParser.csvURL)
        guard let text = String(data: data, encoding: .utf8) else { throw SPXReturnError.unreadable }
        let quote = try SPXReturnParser.parse(text, asOf: now())
        if let encoded = try? JSONEncoder().encode(quote) {
            cacheDefaults.set(encoded, forKey: Self.cacheKey)
        }
        return quote
    }

    func cachedQuote() -> SPXReturnQuote? {
        guard let data = cacheDefaults.data(forKey: Self.cacheKey) else { return nil }
        return try? JSONDecoder().decode(SPXReturnQuote.self, from: data)
    }
}
