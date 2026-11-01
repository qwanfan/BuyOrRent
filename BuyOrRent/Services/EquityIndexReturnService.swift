import Foundation

struct EquityIndexReturnQuote: Equatable, Codable, Sendable {
    var rate: Double
    var startDate: String
    var endDate: String
    var sourceName: String
}

struct EquityIndexSpec: Equatable, Sendable {
    var yahooSymbol: String
    var sourceName: String
}

enum EquityIndexReturnError: Error, Equatable {
    case unreadable
    case insufficient
    case outOfRange
    case emptyBatch
}

/// 各国主指数日线的 10 年价格年化回报，不含股息。
enum EquityIndexReturnParser {
    static func chartURL(for symbol: String) -> URL {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        return URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?range=11y&interval=1d")!
    }

    static func parseChart(_ data: Data, sourceName: String, asOf: Date = Date(), calendar: Calendar = .current) throws -> EquityIndexReturnQuote {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = root["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let result = results.first,
              let timestamps = result["timestamp"] as? [Any],
              let indicators = result["indicators"] as? [String: Any],
              let quotes = indicators["quote"] as? [[String: Any]],
              let quote = quotes.first,
              let closes = quote["close"] as? [Any] else {
            throw EquityIndexReturnError.unreadable
        }

        var points: [(date: Date, level: Double)] = []
        let count = min(timestamps.count, closes.count)
        for index in 0..<count {
            guard let epoch = jsonNumber(timestamps[index]),
                  let level = jsonNumber(closes[index]),
                  level > 0 else {
                continue
            }
            let date = startOfDay(Date(timeIntervalSince1970: epoch), calendar: calendar)
            points.append((date, level))
        }
        points.sort { $0.date < $1.date }
        return try trailingReturn(points: points, sourceName: sourceName, asOf: asOf, calendar: calendar)
    }

    static func trailingReturn(
        points: [(date: Date, level: Double)],
        sourceName: String,
        asOf: Date = Date(),
        calendar: Calendar = .current
    ) throws -> EquityIndexReturnQuote {
        let today = startOfDay(asOf, calendar: calendar)
        let eligible = points.filter { $0.date <= today }
        guard let end = eligible.last else { throw EquityIndexReturnError.insufficient }
        let target = subtractingYears(10, from: end.date, calendar: calendar)
        let before = eligible.filter { $0.date <= target }
        let after = eligible.filter { $0.date >= target }
        let start: (date: Date, level: Double)
        if let last = before.last, days(from: last.date, to: target, calendar: calendar) <= 10 {
            start = last
        } else if let first = after.first, days(from: target, to: first.date, calendar: calendar) <= 10 {
            start = first
        } else {
            throw EquityIndexReturnError.insufficient
        }

        let span = days(from: start.date, to: end.date, calendar: calendar)
        guard (3650 - 20)...(3650 + 20) ~= span else { throw EquityIndexReturnError.insufficient }
        let raw = pow(end.level / start.level, 365.25 / Double(span)) - 1
        let rate = (raw * 10_000).rounded() / 10_000
        guard (-0.5...0.5).contains(rate) else { throw EquityIndexReturnError.outOfRange }
        return EquityIndexReturnQuote(
            rate: rate,
            startDate: isoDate(start.date, calendar: calendar),
            endDate: isoDate(end.date, calendar: calendar),
            sourceName: sourceName
        )
    }

    private static func jsonNumber(_ value: Any) -> Double? {
        switch value {
        case let number as Double: return number
        case let number as Int: return Double(number)
        case let number as NSNumber: return number.doubleValue
        default: return nil
        }
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
        calendar.dateComponents(
            [.day],
            from: startOfDay(start, calendar: calendar),
            to: startOfDay(end, calendar: calendar)
        ).day ?? 0
    }

    private static func startOfDay(_ date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }

    private static func isoDate(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

private struct EquityIndexReturnCache: Equatable, Codable, Sendable {
    var fetchedOn: String
    var quotes: [String: EquityIndexReturnQuote]
}

/// 启动时（或跨日）向 Yahoo 拉取各国主指数。失败时用上次缓存，再没有才用种子。
struct EquityIndexReturnService {
    private static let cacheKey = "equityIndexReturn.v1"
    private static let requestGapNanoseconds: UInt64 = 250_000_000

    static let specs: [Country: EquityIndexSpec] = [
        .chinaMainland: EquityIndexSpec(yahooSymbol: "000300.SS", sourceName: "Yahoo Finance：沪深 300"),
        .hongKong: EquityIndexSpec(yahooSymbol: "^HSI", sourceName: "Yahoo Finance：恒生指数"),
        .singapore: EquityIndexSpec(yahooSymbol: "^STI", sourceName: "Yahoo Finance：海峡时报指数"),
        .japan: EquityIndexSpec(yahooSymbol: "^N225", sourceName: "Yahoo Finance：日经 225"),
        .australia: EquityIndexSpec(yahooSymbol: "^AXJO", sourceName: "Yahoo Finance：S&P/ASX 200"),
        .unitedKingdom: EquityIndexSpec(yahooSymbol: "^FTSE", sourceName: "Yahoo Finance：FTSE 100"),
        .netherlands: EquityIndexSpec(yahooSymbol: "^AEX", sourceName: "Yahoo Finance：AEX"),
        .france: EquityIndexSpec(yahooSymbol: "^FCHI", sourceName: "Yahoo Finance：CAC 40"),
        .germany: EquityIndexSpec(yahooSymbol: "^GDAXI", sourceName: "Yahoo Finance：DAX"),
        .spain: EquityIndexSpec(yahooSymbol: "^IBEX", sourceName: "Yahoo Finance：IBEX 35"),
        .italy: EquityIndexSpec(yahooSymbol: "FTSEMIB.MI", sourceName: "Yahoo Finance：FTSE MIB"),
        .switzerland: EquityIndexSpec(yahooSymbol: "^SSMI", sourceName: "Yahoo Finance：SMI"),
        .unitedStates: EquityIndexSpec(yahooSymbol: "^GSPC", sourceName: "Yahoo Finance：S&P 500"),
        .canada: EquityIndexSpec(yahooSymbol: "^GSPTSE", sourceName: "Yahoo Finance：S&P/TSX"),
    ]

    /// 首次安装、无缓存时使用。联网成功后会被覆盖。
    static let seedRates: [Country: Double] = [
        .chinaMainland: 0.04,
        .hongKong: 0.04,
        .singapore: 0.04,
        .japan: 0.06,
        .australia: 0.06,
        .unitedKingdom: 0.05,
        .netherlands: 0.07,
        .france: 0.07,
        .germany: 0.07,
        .spain: 0.05,
        .italy: 0.06,
        .switzerland: 0.05,
        .unitedStates: 0.1377,
        .canada: 0.07,
    ]

    var now: @Sendable () -> Date = { Date() }
    var fetchData: @Sendable (URL) async throws -> Data = { url in
        try await RemoteFetch.fetch(url, timeout: 30)
    }
    var sleepNanoseconds: @Sendable (UInt64) async -> Void = { nanoseconds in
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
    var cacheDefaults: UserDefaults = .standard
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    static func seedRate(for country: Country) -> Double {
        seedRates[country] ?? 0.04
    }

    func quote(for country: Country) -> EquityIndexReturnQuote? {
        cachedBundle()?.quotes[country.rawValue]
    }

    func resolvedRate(for country: Country) -> Double {
        quote(for: country)?.rate ?? Self.seedRate(for: country)
    }

    func fetchedOnToday() -> Bool {
        cachedBundle()?.fetchedOn == todayString()
    }

    /// 非 force 且今天已成功拉过则跳过。返回是否使用了今天的网络表（含缓存命中）。
    @discardableResult
    func fetchAllIfNeeded(force: Bool = false) async throws -> Bool {
        if !force, let bundle = cachedBundle(), bundle.fetchedOn == todayString(), !bundle.quotes.isEmpty {
            return true
        }

        var quotes = cachedBundle()?.quotes ?? [:]
        var anySuccess = false
        let countries = Country.allCases
        for (index, country) in countries.enumerated() {
            if index > 0 {
                await sleepNanoseconds(Self.requestGapNanoseconds)
            }
            guard let spec = Self.specs[country] else { continue }
            do {
                let data = try await fetchData(EquityIndexReturnParser.chartURL(for: spec.yahooSymbol))
                let quote = try EquityIndexReturnParser.parseChart(
                    data,
                    sourceName: spec.sourceName,
                    asOf: now(),
                    calendar: calendar
                )
                quotes[country.rawValue] = quote
                anySuccess = true
            } catch {
                continue
            }
        }

        guard anySuccess else { throw EquityIndexReturnError.emptyBatch }
        store(EquityIndexReturnCache(fetchedOn: todayString(), quotes: quotes))
        return true
    }

    private func cachedBundle() -> EquityIndexReturnCache? {
        guard let data = cacheDefaults.data(forKey: Self.cacheKey) else { return nil }
        return try? JSONDecoder().decode(EquityIndexReturnCache.self, from: data)
    }

    private func store(_ bundle: EquityIndexReturnCache) {
        guard let data = try? JSONEncoder().encode(bundle) else { return }
        cacheDefaults.set(data, forKey: Self.cacheKey)
    }

    private func todayString() -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: now())
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
