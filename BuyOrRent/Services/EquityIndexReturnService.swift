import Foundation

struct EquityIndexReturnQuote: Equatable, Codable, Sendable {
    var rate: Double
    var startDate: String
    var endDate: String
    var sourceName: String
}

struct EquityIndexReturnCatalog: Equatable, Codable, Sendable {
    var schemaVersion: Int
    var publishedAt: String
    var fetchedOn: String
    var methodology: String
    var countries: [String: EquityIndexReturnQuote]
}

enum EquityIndexReturnError: Error, Equatable {
    case unreadable
    case unsupportedSchema
    case emptyBatch
    case invalidRate
}

/// 各国主指数的 10 年价格年化回报。App 从 GitHub Pages 读取（中国大陆直连 Yahoo 不可用）。
struct EquityIndexReturnService {
    static let catalogURL = URL(string: "https://qwanfan.github.io/BuyOrRent/v1/equity-index-returns.json")!
    private static let cacheKey = "equityIndexReturn.v1"

    /// 首次安装、无缓存时使用。联网成功后会被覆盖。
    static let seedRates: [Country: Double] = [
        .chinaMainland: 0.0179,
        .hongKong: 0.0015,
        .singapore: 0.0668,
        .japan: 0.1375,
        .australia: 0.053,
        .unitedKingdom: 0.0437,
        .netherlands: 0.0955,
        .france: 0.0577,
        .germany: 0.0921,
        .spain: 0.0732,
        .italy: 0.1107,
        .switzerland: 0.0647,
        .unitedStates: 0.1355,
        .canada: 0.0919,
    ]

    var now: @Sendable () -> Date = { Date() }
    var fetchData: @Sendable (URL) async throws -> Data = { url in
        try await RemoteFetch.fetch(url, timeout: 30)
    }
    var bundledData: @Sendable () -> Data? = { Self.loadBundledCatalogData() }
    var cacheDefaults: UserDefaults = .standard
    var remoteURL: URL = Self.catalogURL
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    static func seedRate(for country: Country) -> Double {
        seedRates[country] ?? 0.04
    }

    func quote(for country: Country) -> EquityIndexReturnQuote? {
        if let quote = cachedCatalog()?.countries[country.rawValue], Self.isValid(quote) {
            return quote
        }
        if let quote = bundledCatalog()?.countries[country.rawValue], Self.isValid(quote) {
            return quote
        }
        return nil
    }

    func resolvedRate(for country: Country) -> Double {
        quote(for: country)?.rate ?? Self.seedRate(for: country)
    }

    func fetchedOnToday() -> Bool {
        cachedCatalog()?.fetchedOn == todayString()
    }

    /// 非 force 且今天已成功拉过则跳过。返回是否使用了今天的网络表（含缓存命中）。
    @discardableResult
    func fetchAllIfNeeded(force: Bool = false) async throws -> Bool {
        if !force, let catalog = cachedCatalog(), catalog.fetchedOn == todayString(), !catalog.countries.isEmpty {
            return true
        }

        let data = try await fetchData(remoteURL)
        var catalog = try Self.parse(data)
        try Self.validate(catalog)
        // 用本机日历日标记「今天已拉过」，这样每天最多请求一次 GitHub Pages。
        catalog.fetchedOn = todayString()
        store(catalog)
        return true
    }

    func cachedCatalog() -> EquityIndexReturnCatalog? {
        guard let data = cacheDefaults.data(forKey: Self.cacheKey),
              let catalog = try? Self.parse(data),
              (try? Self.validate(catalog)) != nil else {
            return nil
        }
        return catalog
    }

    func bundledCatalog() -> EquityIndexReturnCatalog? {
        guard let data = bundledData(),
              let catalog = try? Self.parse(data),
              (try? Self.validate(catalog)) != nil else {
            return nil
        }
        return catalog
    }

    static func parse(_ data: Data) throws -> EquityIndexReturnCatalog {
        guard let catalog = try? JSONDecoder().decode(EquityIndexReturnCatalog.self, from: data) else {
            throw EquityIndexReturnError.unreadable
        }
        return catalog
    }

    static func validate(_ catalog: EquityIndexReturnCatalog) throws {
        guard catalog.schemaVersion == 1 else { throw EquityIndexReturnError.unsupportedSchema }
        guard !catalog.countries.isEmpty else { throw EquityIndexReturnError.emptyBatch }
        guard !catalog.fetchedOn.isEmpty, !catalog.publishedAt.isEmpty else {
            throw EquityIndexReturnError.unreadable
        }
        for (key, quote) in catalog.countries {
            guard Country(rawValue: key) != nil, Self.isValid(quote) else {
                throw EquityIndexReturnError.invalidRate
            }
        }
    }

    private static func isValid(_ quote: EquityIndexReturnQuote) -> Bool {
        quote.rate.isFinite
            && (-0.5...0.5).contains(quote.rate)
            && !quote.sourceName.isEmpty
            && !quote.startDate.isEmpty
            && !quote.endDate.isEmpty
    }

    private func store(_ catalog: EquityIndexReturnCatalog) {
        guard let data = try? JSONEncoder().encode(catalog) else { return }
        cacheDefaults.set(data, forKey: Self.cacheKey)
    }

    private func todayString() -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: now())
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func loadBundledCatalogData() -> Data? {
        let bundles = [Bundle.main, Bundle(identifier: "app.buyorrent.BuyOrRent")].compactMap { $0 }
        for bundle in bundles {
            guard let url = bundle.url(forResource: "equity-index-returns", withExtension: "json") else { continue }
            if let data = try? Data(contentsOf: url) { return data }
        }
        return nil
    }
}
