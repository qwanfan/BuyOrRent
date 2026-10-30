import Foundation

/// 一个国家的买入成本、卖出成本和年度房产税（小数费率）。
struct PropertyCostRates: Equatable, Codable, Sendable {
    var buyingCostRate: Double
    var sellingCostRate: Double
    var propertyTaxRate: Double
}

struct PropertyCostSource: Equatable, Codable, Sendable {
    var name: String
    var url: String
}

struct PropertyCostRecord: Equatable, Codable, Sendable {
    var propertyTaxRate: Double
    var buyingCostRate: Double
    var sellingCostRate: Double
    var verifiedAt: String
    var confidence: String
    var methodologyNote: String
    var sources: [PropertyCostSource]
    /// 旧缓存没有这三项时仍能解析，调用方回落到出厂种子。
    var mortgageRate: MarketObservation?
    var rentGrowth: MarketObservation?
    var appreciation: MarketObservation?

    var rates: PropertyCostRates {
        PropertyCostRates(
            buyingCostRate: buyingCostRate,
            sellingCostRate: sellingCostRate,
            propertyTaxRate: propertyTaxRate
        )
    }
}

struct InvestmentReturnRecord: Equatable, Codable, Sendable {
    var rate: Double
    var method: String
    var startDate: String
    var endDate: String
    var startLevel: Double
    var endLevel: Double
    var sourceName: String
    var sourceUrl: String
}

struct PropertyCostCatalog: Equatable, Codable, Sendable {
    var schemaVersion: Int
    var datasetVersion: String
    var publishedAt: String
    var checkedAt: String
    var nextReviewAt: String
    var methodology: String
    var contentDigest: String
    var countries: [String: PropertyCostRecord]
    var investmentReturn: InvestmentReturnRecord?
}

struct MarketObservation: Equatable, Codable, Sendable {
    var rate: Double
    var periodLabel: String
    var sourceName: String
    var sourceUrl: String
}

struct MarketObservationResolution: Equatable, Sendable {
    var rate: Double
    var origin: PropertyCostDataOrigin
    var sourceName: String
    var periodLabel: String
}

struct InvestmentReturnResolution: Equatable, Sendable {
    var rate: Double
    var origin: PropertyCostDataOrigin
    var sourceName: String
    var startDate: String?
    var endDate: String?
}

enum PropertyCostError: Error, Equatable {
    case parseFailed
    case unsupportedSchema
    case invalidCountry
    case invalidRate
    case invalidDate
    case insecureSource
}

enum PropertyCostDataOrigin: Equatable, Sendable {
    case seed
    case cache
    case remote
}

struct PropertyCostResolution: Equatable, Sendable {
    var rates: PropertyCostRates
    var origin: PropertyCostDataOrigin
    var datasetVersion: String?
    var publishedAt: String?
    var sourceNames: [String]
}

/// 自住普通住宅的国家级代表成本。远程表只覆盖这些默认值，用户输入始终优先。
struct PropertyCostService {
    static let catalogURL = URL(string: "https://qwanfan.github.io/BuyOrRent/v1/property-costs.json")!
    static let cacheLifetime: TimeInterval = 30 * 24 * 3600

    var now: @Sendable () -> Date = { Date() }
    var fetchData: @Sendable (URL) async throws -> Data = { url in try await RemoteFetch.fetch(url) }
    var bundledData: @Sendable () -> Data? = { Self.loadBundledCatalogData() }
    var cacheDefaults: UserDefaults = .standard
    var remoteURL: URL = Self.catalogURL

    /// 公开官方来源校准后的离线底线；远程失败时仍可完成计算。
    static let seed: [Country: PropertyCostRates] = [
        .chinaMainland: PropertyCostRates(buyingCostRate: 0.025, sellingCostRate: 0.025, propertyTaxRate: 0),
        .hongKong: PropertyCostRates(buyingCostRate: 0.0325, sellingCostRate: 0.012, propertyTaxRate: 0.003),
        .unitedStates: PropertyCostRates(buyingCostRate: 0.030, sellingCostRate: 0.055, propertyTaxRate: 0.011),
        .canada: PropertyCostRates(buyingCostRate: 0.030, sellingCostRate: 0.050, propertyTaxRate: 0.010),
        .singapore: PropertyCostRates(buyingCostRate: 0.040, sellingCostRate: 0.020, propertyTaxRate: 0.003),
        .australia: PropertyCostRates(buyingCostRate: 0.050, sellingCostRate: 0.030, propertyTaxRate: 0.006),
        .japan: PropertyCostRates(buyingCostRate: 0.060, sellingCostRate: 0.035, propertyTaxRate: 0.007),
        .unitedKingdom: PropertyCostRates(buyingCostRate: 0.040, sellingCostRate: 0.020, propertyTaxRate: 0.006),
        .germany: PropertyCostRates(buyingCostRate: 0.080, sellingCostRate: 0.030, propertyTaxRate: 0.0035),
        .france: PropertyCostRates(buyingCostRate: 0.075, sellingCostRate: 0.050, propertyTaxRate: 0.010),
        .netherlands: PropertyCostRates(buyingCostRate: 0.025, sellingCostRate: 0.020, propertyTaxRate: 0.001),
        .spain: PropertyCostRates(buyingCostRate: 0.100, sellingCostRate: 0.050, propertyTaxRate: 0.006),
        .italy: PropertyCostRates(buyingCostRate: 0.060, sellingCostRate: 0.030, propertyTaxRate: 0),
        .switzerland: PropertyCostRates(buyingCostRate: 0.035, sellingCostRate: 0.030, propertyTaxRate: 0.002),
    ]

    /// 标普 500 过去 10 年价格年化回报。远程表缺这一项时使用。
    /// 2016-10-31 的 2126.15 到 2026-10-29 的 7720.39，年化后保留 1 个基点。
    static let seedInvestmentReturn = 0.1377
    static let seedInvestmentReturnSource = "FRED：S&P 500"

    static func seedRates(for country: Country) -> PropertyCostRates {
        seed[country] ?? PropertyCostRates(buyingCostRate: 0, sellingCostRate: 0, propertyTaxRate: 0)
    }

    func fetchCatalog() async throws -> PropertyCostCatalog {
        let data = try await fetchData(remoteURL)
        let catalog = try Self.parse(data)
        try Self.validate(catalog, now: now())
        store(catalog)
        cacheDefaults.set(now(), forKey: Self.lastCheckedKey)
        return catalog
    }

    func cachedCatalog() -> PropertyCostCatalog? {
        guard let data = cacheDefaults.data(forKey: Self.catalogCacheKey),
              let catalog = try? Self.parse(data),
              (try? Self.validate(catalog, now: now())) != nil else {
            return nil
        }
        return catalog
    }

    func isCheckDue(for country: Country) -> Bool {
        guard localRecord(for: country) != nil else { return true }
        guard let baseline = lastCheckedAt ?? bundledCatalog().flatMap({ Self.isoDateTime($0.checkedAt) }) else {
            return true
        }
        return now().timeIntervalSince(baseline) >= Self.cacheLifetime
    }

    func resolvedRates(for country: Country) -> PropertyCostResolution {
        if let catalog = cachedCatalog(),
           let record = catalog.countries[country.rawValue] {
            return Self.resolution(record: record, catalog: catalog, origin: .cache)
        }
        if let catalog = bundledCatalog(),
           let record = catalog.countries[country.rawValue] {
            return Self.resolution(record: record, catalog: catalog, origin: .seed)
        }
        return PropertyCostResolution(
            rates: Self.seedRates(for: country),
            origin: .seed,
            datasetVersion: nil,
            publishedAt: nil,
            sourceNames: []
        )
    }

    /// 远程缓存优先，其次安装包里的表。缺字段、越界或来源不是 https 时返回 nil。
    func resolvedMortgageRate(for country: Country) -> MarketObservationResolution? {
        resolvedObservation(\.mortgageRate, for: country, allowsZero: false, bounds: 0...0.20)
    }

    func resolvedRentGrowth(for country: Country) -> MarketObservationResolution? {
        resolvedObservation(\.rentGrowth, for: country, allowsZero: true, bounds: -0.05...0.15)
    }

    func resolvedAppreciation(for country: Country) -> MarketObservationResolution? {
        resolvedObservation(\.appreciation, for: country, allowsZero: true, bounds: -0.20...0.20)
    }

    func resolvedInvestmentReturn() -> InvestmentReturnResolution {
        if let record = cachedCatalog()?.investmentReturn {
            return Self.investmentResolution(record, origin: .cache)
        }
        if let record = bundledCatalog()?.investmentReturn {
            return Self.investmentResolution(record, origin: .seed)
        }
        return InvestmentReturnResolution(
            rate: Self.seedInvestmentReturn,
            origin: .seed,
            sourceName: Self.seedInvestmentReturnSource,
            startDate: nil,
            endDate: nil
        )
    }

    func bundledCatalog() -> PropertyCostCatalog? {
        guard let data = bundledData(),
              let catalog = try? Self.parse(data),
              (try? Self.validate(catalog, now: now())) != nil else {
            return nil
        }
        return catalog
    }

    static func resolution(
        for country: Country,
        in catalog: PropertyCostCatalog,
        origin: PropertyCostDataOrigin
    ) -> PropertyCostResolution? {
        guard let record = catalog.countries[country.rawValue] else { return nil }
        return resolution(record: record, catalog: catalog, origin: origin)
    }

    static func parse(_ data: Data) throws -> PropertyCostCatalog {
        let decoder = JSONDecoder()
        guard let catalog = try? decoder.decode(PropertyCostCatalog.self, from: data) else {
            throw PropertyCostError.parseFailed
        }
        return catalog
    }

    static func validate(_ catalog: PropertyCostCatalog, now: Date) throws {
        guard catalog.schemaVersion == 1 else { throw PropertyCostError.unsupportedSchema }
        guard !catalog.countries.isEmpty else { throw PropertyCostError.invalidCountry }
        guard catalog.contentDigest.count == 64,
              catalog.contentDigest.allSatisfy({ $0.isHexDigit }) else {
            throw PropertyCostError.parseFailed
        }
        guard let published = isoDateTime(catalog.publishedAt),
              let checked = isoDateTime(catalog.checkedAt),
              published <= now.addingTimeInterval(24 * 3600),
              checked <= now.addingTimeInterval(24 * 3600),
              checked >= published,
              dateOnly(catalog.nextReviewAt) != nil else {
            throw PropertyCostError.invalidDate
        }

        for (key, record) in catalog.countries {
            guard Country(rawValue: key) != nil else { throw PropertyCostError.invalidCountry }
            guard record.propertyTaxRate.isFinite,
                  (0...0.06).contains(record.propertyTaxRate),
                  record.buyingCostRate.isFinite,
                  (0...0.80).contains(record.buyingCostRate),
                  record.sellingCostRate.isFinite,
                  (0...0.30).contains(record.sellingCostRate) else {
                throw PropertyCostError.invalidRate
            }
            guard let verified = dateOnly(record.verifiedAt),
                  verified <= now.addingTimeInterval(24 * 3600) else {
                throw PropertyCostError.invalidDate
            }
            guard !record.sources.isEmpty,
                  record.sources.allSatisfy({
                      guard let url = URL(string: $0.url) else { return false }
                      return url.scheme == "https" && url.host != nil && !$0.name.isEmpty
                  }) else {
                throw PropertyCostError.insecureSource
            }
        }
        if let investment = catalog.investmentReturn {
            guard investment.method == "spxPriceCagr10Y",
                  investment.rate.isFinite,
                  (-0.5...0.5).contains(investment.rate),
                  investment.startLevel > 0,
                  investment.endLevel > 0 else {
                throw PropertyCostError.invalidRate
            }
            guard let start = dateOnly(investment.startDate),
                  let end = dateOnly(investment.endDate),
                  start <= end,
                  end <= now.addingTimeInterval(24 * 3600) else {
                throw PropertyCostError.invalidDate
            }
            guard let url = URL(string: investment.sourceUrl),
                  url.scheme == "https",
                  url.host != nil,
                  !investment.sourceName.isEmpty else {
                throw PropertyCostError.insecureSource
            }
        }
    }

    private static func investmentResolution(
        _ record: InvestmentReturnRecord,
        origin: PropertyCostDataOrigin
    ) -> InvestmentReturnResolution {
        InvestmentReturnResolution(
            rate: record.rate,
            origin: origin,
            sourceName: record.sourceName,
            startDate: record.startDate,
            endDate: record.endDate
        )
    }

    private func resolvedObservation(
        _ keyPath: KeyPath<PropertyCostRecord, MarketObservation?>,
        for country: Country,
        allowsZero: Bool,
        bounds: ClosedRange<Double>
    ) -> MarketObservationResolution? {
        if let catalog = cachedCatalog(),
           let record = catalog.countries[country.rawValue],
           let resolution = Self.observationResolution(
               record[keyPath: keyPath],
               origin: .cache,
               allowsZero: allowsZero,
               bounds: bounds
           ) {
            return resolution
        }
        if let catalog = bundledCatalog(),
           let record = catalog.countries[country.rawValue],
           let resolution = Self.observationResolution(
               record[keyPath: keyPath],
               origin: .seed,
               allowsZero: allowsZero,
               bounds: bounds
           ) {
            return resolution
        }
        return nil
    }

    private static func observationResolution(
        _ record: MarketObservation?,
        origin: PropertyCostDataOrigin,
        allowsZero: Bool,
        bounds: ClosedRange<Double>
    ) -> MarketObservationResolution? {
        guard let record,
              record.rate.isFinite,
              bounds.contains(record.rate),
              allowsZero || record.rate > 0,
              let url = URL(string: record.sourceUrl),
              url.scheme == "https",
              url.host != nil,
              !record.sourceName.isEmpty,
              !record.periodLabel.isEmpty else {
            return nil
        }
        return MarketObservationResolution(
            rate: record.rate,
            origin: origin,
            sourceName: record.sourceName,
            periodLabel: record.periodLabel
        )
    }

    private func localRecord(for country: Country) -> PropertyCostRecord? {
        cachedCatalog()?.countries[country.rawValue] ?? bundledCatalog()?.countries[country.rawValue]
    }

    private var lastCheckedAt: Date? {
        cacheDefaults.object(forKey: Self.lastCheckedKey) as? Date
    }

    static func loadBundledCatalogData() -> Data? {
        let bundles = [Bundle.main, Bundle(identifier: "app.buyorrent.BuyOrRent")].compactMap { $0 }
        for bundle in bundles {
            guard let url = bundle.url(forResource: "property-costs", withExtension: "json") else { continue }
            if let data = try? Data(contentsOf: url) { return data }
        }
        return nil
    }

    private func store(_ catalog: PropertyCostCatalog) {
        guard let data = try? JSONEncoder().encode(catalog) else { return }
        cacheDefaults.set(data, forKey: Self.catalogCacheKey)
    }

    private static func resolution(
        record: PropertyCostRecord,
        catalog: PropertyCostCatalog,
        origin: PropertyCostDataOrigin
    ) -> PropertyCostResolution {
        PropertyCostResolution(
            rates: record.rates,
            origin: origin,
            datasetVersion: catalog.datasetVersion,
            publishedAt: catalog.publishedAt,
            sourceNames: record.sources.map(\.name)
        )
    }

    private static func isoDateTime(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }

    private static func dateOnly(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private static let catalogCacheKey = "propertyCostCatalog.v1"
    private static let lastCheckedKey = "propertyCostCatalog.lastCheckedAt.v1"
}
