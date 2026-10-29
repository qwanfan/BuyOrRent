import Foundation

/// 一次联网得到的房贷利率。
struct MortgageRateQuote: Equatable, Codable, Sendable {
    /// 年利率（小数，如 0.035 表示 3.5%）。
    var rate: Double
    /// 数据所属时期，如 "2026-08" 或 "2026-10-22"。
    var periodLabel: String
    /// 数据时期的起始日期，用于校验新旧。
    var periodDate: Date
    var sourceName: String
    var fetchedAt: Date

    /// 缓存 7 天内视为新鲜。
    func isCacheFresh(now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) >= 0 && now.timeIntervalSince(fetchedAt) <= 7 * 24 * 3600
    }
}

enum MortgageRateError: Error, Equatable {
    case parseFailed
    case invalidRate
    case staleData
    case futureData
    case http(Int)
}

/// 按国家直连官方数据源获取房贷利率；失败时由调用方回落内置缺省利率。
/// 香港、新加坡走「基准 + 预设利差」。中国大陆直接采用 5 年期以上 LPR，不再减利差。
/// 其余国家优先取官方实际房贷利率统计。
struct MortgageRateService {
    var now: @Sendable () -> Date = { Date() }
    var fetchData: @Sendable (URL) async throws -> Data = { url in try await RemoteFetch.fetch(url) }
    /// 缓存用的 UserDefaults；测试可注入独立 suite。
    var cacheDefaults: UserDefaults = .standard

    // MARK: - 对外入口

    func fetchQuote(for country: Country) async throws -> MortgageRateQuote {
        let quote = try await rawQuote(for: country)
        try Self.validate(quote, now: now())
        storeCached(quote, for: country)
        return quote
    }

    func cachedQuote(for country: Country) -> MortgageRateQuote? {
        guard let data = cacheDefaults.data(forKey: Self.cacheKey(for: country)),
              let quote = try? JSONDecoder().decode(MortgageRateQuote.self, from: data),
              (try? Self.validate(quote, now: now())) != nil else { return nil }
        return quote
    }

    private func storeCached(_ quote: MortgageRateQuote, for country: Country) {
        guard let data = try? JSONEncoder().encode(quote) else { return }
        cacheDefaults.set(data, forKey: Self.cacheKey(for: country))
    }

    private static func cacheKey(for country: Country) -> String {
        "mortgageRateCache.\(country.rawValue)"
    }

    /// 利率须在 (0, 20%]，数据期不得晚于当前、不得旧于 24 个月。
    static func validate(_ quote: MortgageRateQuote, now: Date) throws {
        guard quote.rate.isFinite, quote.rate > 0, quote.rate <= 0.20 else {
            throw MortgageRateError.invalidRate
        }
        if quote.periodDate > now.addingTimeInterval(31 * 24 * 3600) {
            throw MortgageRateError.futureData
        }
        let twoYearsAgo = Calendar(identifier: .gregorian).date(byAdding: .month, value: -24, to: now) ?? now
        if quote.periodDate < twoYearsAgo {
            throw MortgageRateError.staleData
        }
    }

    // MARK: - 各国取数

    private func rawQuote(for country: Country) async throws -> MortgageRateQuote {
        let preset = country.preset
        switch country {
        case .germany, .france, .netherlands, .spain, .italy:
            guard let code = country.ecbCountryCode else { throw MortgageRateError.parseFailed }
            let url = URL(string: "https://data-api.ecb.europa.eu/service/data/MIR/MIR.M.\(code).B.A2C.AM.R.A.2250.EUR.N?format=jsondata&lastNObservations=1")!
            return try Self.parseECBJSON(try await fetchData(url), sourceName: preset.rateSourceName, fetchedAt: now())

        case .unitedStates:
            let url = URL(string: "https://fred.stlouisfed.org/graph/fredgraph.csv?id=MORTGAGE30US")!
            return try Self.parseFREDCSV(try await fetchData(url), sourceName: preset.rateSourceName, fetchedAt: now())

        case .unitedKingdom:
            let url = URL(string: "https://www.bankofengland.co.uk/boeapps/iadb/fromshowcolumns.asp?csv.x=yes&Datefrom=01/Jan/2020&Dateto=now&SeriesCodes=IUMBV34&CSVF=TN&UsingCodes=Y&VPD=Y&VFD=N")!
            return try Self.parseBoECSV(try await fetchData(url), sourceName: preset.rateSourceName, fetchedAt: now())

        case .canada:
            let url = URL(string: "https://www.bankofcanada.ca/valet/observations/V80691335/json?recent=4")!
            return try Self.parseBankOfCanadaJSON(try await fetchData(url), sourceName: preset.rateSourceName, fetchedAt: now())

        case .australia:
            let url = URL(string: "https://www.rba.gov.au/statistics/tables/csv/f6hist.csv")!
            return try Self.parseRBACSV(try await fetchData(url), sourceName: preset.rateSourceName, fetchedAt: now())

        case .singapore:
            let url = URL(string: "https://data.gov.sg/api/action/datastore_search?resource_id=d_5fe5a4bb4a1ecc4d8a56a095832e2b24&limit=100")!
            let benchmark = try Self.parseSORAJSON(try await fetchData(url), fetchedAt: now())
            return Self.applyingSpread(benchmark, spread: preset.benchmarkSpread, sourceName: preset.rateSourceName)

        case .switzerland:
            let url = URL(string: "https://data.snb.ch/api/cube/zikrepro/data/csv/en?D1=MV")!
            return try Self.parseSNBCSV(try await fetchData(url), sourceName: preset.rateSourceName, fetchedAt: now())

        case .chinaMainland:
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            let end = formatter.string(from: now())
            let start = formatter.string(from: now().addingTimeInterval(-120 * 24 * 3600))
            let url = URL(string: "https://www.chinamoney.com.cn/dqs/rest/cm-u-bk-currency/LprHis?lang=CN&strStartDate=\(start)&strEndDate=\(end)")!
            let benchmark = try Self.parseLPRJSON(try await fetchData(url), fetchedAt: now())
            return Self.applyingSpread(benchmark, spread: preset.benchmarkSpread, sourceName: preset.rateSourceName)

        case .hongKong:
            let url = URL(string: "https://api.hkma.gov.hk/public/market-data-and-statistics/monthly-statistical-bulletin/er-ir/hk-interbank-ir-daily?segment=hibor.fixing&pagesize=5&sortby=end_of_day&sortorder=desc")!
            let benchmark = try Self.parseHIBORJSON(try await fetchData(url), fetchedAt: now())
            return Self.applyingSpread(benchmark, spread: preset.benchmarkSpread, sourceName: preset.rateSourceName)

        case .japan:
            let url = URL(string: "https://www.flat35.com/loan/lineup/flat35/index.html")!
            return try Self.parseFlat35HTML(try await fetchData(url), sourceName: preset.rateSourceName, fetchedAt: now())
        }
    }

    private static func applyingSpread(_ benchmark: MortgageRateQuote, spread: Double, sourceName: String) -> MortgageRateQuote {
        var quote = benchmark
        quote.rate = benchmark.rate + spread
        quote.sourceName = sourceName
        return quote
    }


    // MARK: - 解析（均为纯函数，供单元测试用 fixture 验证）

    /// FRED CSV：`DATE,MORTGAGE30US`，缺测值为 `.`。
    static func parseFREDCSV(_ data: Data, sourceName: String, fetchedAt: Date) throws -> MortgageRateQuote {
        guard let text = String(data: data, encoding: .utf8) else { throw MortgageRateError.parseFailed }
        for line in text.split(whereSeparator: \.isNewline).reversed() {
            let parts = line.split(separator: ",", omittingEmptySubsequences: false)
            guard parts.count >= 2, let percent = Double(parts[1]) else { continue }
            let label = String(parts[0])
            guard let date = periodDate(from: label) else { continue }
            return MortgageRateQuote(rate: percent / 100, periodLabel: label, periodDate: date, sourceName: sourceName, fetchedAt: fetchedAt)
        }
        throw MortgageRateError.parseFailed
    }

    /// 英格兰银行 CSV：首列日期、次列利率（百分点）。
    static func parseBoECSV(_ data: Data, sourceName: String, fetchedAt: Date) throws -> MortgageRateQuote {
        guard let text = String(data: data, encoding: .utf8), !text.contains("<html") else { throw MortgageRateError.parseFailed }
        for line in text.split(whereSeparator: \.isNewline).reversed() {
            let parts = csvFields(String(line))
            guard parts.count >= 2, let percent = Double(parts[1]),
                  let date = periodDate(from: parts[0]) else { continue }
            return MortgageRateQuote(rate: percent / 100, periodLabel: parts[0], periodDate: date, sourceName: sourceName, fetchedAt: fetchedAt)
        }
        throw MortgageRateError.parseFailed
    }

    /// 加拿大央行 Valet JSON：observations[].d 与 V80691335.v。
    static func parseBankOfCanadaJSON(_ data: Data, sourceName: String, fetchedAt: Date) throws -> MortgageRateQuote {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let observations = root["observations"] as? [[String: Any]] else { throw MortgageRateError.parseFailed }
        for observation in observations.reversed() {
            guard let label = observation["d"] as? String,
                  let series = observation["V80691335"] as? [String: Any],
                  let raw = series["v"] as? String, let percent = Double(raw),
                  let date = periodDate(from: label) else { continue }
            return MortgageRateQuote(rate: percent / 100, periodLabel: label, periodDate: date, sourceName: sourceName, fetchedAt: fetchedAt)
        }
        throw MortgageRateError.parseFailed
    }

    /// ECB SDMX JSON：取第一条序列的最新观测与其时间期。
    static func parseECBJSON(_ data: Data, sourceName: String, fetchedAt: Date) throws -> MortgageRateQuote {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataSets = root["dataSets"] as? [[String: Any]],
              let series = dataSets.first?["series"] as? [String: Any],
              let firstSeries = series.values.first as? [String: Any],
              let observations = firstSeries["observations"] as? [String: Any],
              let structure = root["structure"] as? [String: Any],
              let dimensions = structure["dimensions"] as? [String: Any],
              let observationDims = dimensions["observation"] as? [[String: Any]],
              let timeDim = observationDims.first(where: { ($0["id"] as? String) == "TIME_PERIOD" }),
              let periods = timeDim["values"] as? [[String: Any]] else { throw MortgageRateError.parseFailed }

        var best: (index: Int, percent: Double)?
        for (key, raw) in observations {
            guard let index = Int(key),
                  let values = raw as? [Any],
                  let percent = (values.first as? NSNumber)?.doubleValue else { continue }
            if best == nil || index > best!.index { best = (index, percent) }
        }
        guard let best, periods.indices.contains(best.index),
              let label = periods[best.index]["id"] as? String,
              let date = periodDate(from: label) else { throw MortgageRateError.parseFailed }
        return MortgageRateQuote(rate: best.percent / 100, periodLabel: label, periodDate: date, sourceName: sourceName, fetchedAt: fetchedAt)
    }

    /// 澳洲央行宽表 CSV：含 "Series ID" 行，取 FLR 开头自住系列的最新值。
    static func parseRBACSV(_ data: Data, sourceName: String, fetchedAt: Date) throws -> MortgageRateQuote {
        guard let text = String(data: data, encoding: .utf8), !text.contains("<HTML") else { throw MortgageRateError.parseFailed }
        let rows = text.split(whereSeparator: \.isNewline).map { csvFields(String($0)) }
        guard let idRowIndex = rows.firstIndex(where: { $0.first?.trimmingCharacters(in: .whitespaces) == "Series ID" }) else {
            throw MortgageRateError.parseFailed
        }
        let ids = rows[idRowIndex]
        let column = ids.firstIndex(where: { $0.hasPrefix("FLRHOO") }) ?? ids.firstIndex(where: { $0.hasPrefix("FLR") })
        guard let column, column > 0 else { throw MortgageRateError.parseFailed }
        for row in rows[(idRowIndex + 1)...].reversed() {
            guard row.count > column, let percent = Double(row[column]),
                  let date = periodDate(from: row[0]) else { continue }
            return MortgageRateQuote(rate: percent / 100, periodLabel: row[0], periodDate: date, sourceName: sourceName, fetchedAt: fetchedAt)
        }
        throw MortgageRateError.parseFailed
    }

    /// 瑞士央行 CSV（分号分隔、带引号）：取 D1=MV（浮动房贷公布利率）的最新值。
    static func parseSNBCSV(_ data: Data, sourceName: String, fetchedAt: Date) throws -> MortgageRateQuote {
        guard let text = String(data: data, encoding: .utf8) else { throw MortgageRateError.parseFailed }
        var result: MortgageRateQuote?
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: ";", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\" \t")) }
            guard fields.count >= 4, fields[2] == "MV", let percent = Double(fields[3]),
                  let date = periodDate(from: fields[0]) else { continue }
            result = MortgageRateQuote(rate: percent / 100, periodLabel: fields[0], periodDate: date, sourceName: sourceName, fetchedAt: fetchedAt)
        }
        guard let result else { throw MortgageRateError.parseFailed }
        return result
    }

    /// data.gov.sg datastore JSON：取 3 个月复利 SORA 记录的最新月份值（百分点）。
    static func parseSORAJSON(_ data: Data, fetchedAt: Date) throws -> MortgageRateQuote {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["result"] as? [String: Any],
              let records = result["records"] as? [[String: Any]],
              let record = records.first(where: { ($0["DataSeries"] as? String)?.contains("SORA) - 3 Month") == true }) else {
            throw MortgageRateError.parseFailed
        }
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        var best: (label: String, percent: Double, sortKey: Int)?
        for (key, value) in record {
            // 形如 "2026Aug"
            guard key.count == 7, let year = Int(key.prefix(4)),
                  let monthIndex = monthNames.firstIndex(of: String(key.suffix(3))) else { continue }
            let percent: Double?
            if let number = value as? NSNumber { percent = number.doubleValue }
            else if let string = value as? String { percent = Double(string) }
            else { percent = nil }
            guard let percent else { continue }
            let sortKey = year * 100 + monthIndex
            if best == nil || sortKey > best!.sortKey { best = (key, percent, sortKey) }
        }
        guard let best, let date = periodDate(from: best.label) else { throw MortgageRateError.parseFailed }
        return MortgageRateQuote(rate: best.percent / 100, periodLabel: best.label, periodDate: date, sourceName: "3 个月 SORA", fetchedAt: fetchedAt)
    }

    /// 中国货币网 LPR JSON：最新一条记录的 "5Y" 与 showDateCN。
    /// 现行接口把 `records` 放在根上；旧示例放在 `data.records`，两种都认。
    static func parseLPRJSON(_ data: Data, fetchedAt: Date) throws -> MortgageRateQuote {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MortgageRateError.parseFailed
        }
        let records = (root["records"] as? [[String: Any]])
            ?? ((root["data"] as? [String: Any])?["records"] as? [[String: Any]])
        guard let records else { throw MortgageRateError.parseFailed }
        var latest: (date: Date, label: String, percent: Double)?
        for record in records {
            guard let raw = record["5Y"] as? String, let percent = Double(raw),
                  let label = record["showDateCN"] as? String,
                  let date = periodDate(from: label) else { continue }
            if latest == nil || date > latest!.date {
                latest = (date, label, percent)
            }
        }
        guard let latest else { throw MortgageRateError.parseFailed }
        return MortgageRateQuote(
            rate: latest.percent / 100,
            periodLabel: latest.label,
            periodDate: latest.date,
            sourceName: "5 年期以上 LPR",
            fetchedAt: fetchedAt
        )
    }

    /// 金管局 HIBOR JSON：result.records 中最新一条的 ir_1m。
    static func parseHIBORJSON(_ data: Data, fetchedAt: Date) throws -> MortgageRateQuote {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["result"] as? [String: Any],
              let records = result["records"] as? [[String: Any]] else { throw MortgageRateError.parseFailed }
        for record in records {
            guard let label = record["end_of_day"] as? String,
                  let percent = (record["ir_1m"] as? NSNumber)?.doubleValue,
                  let date = periodDate(from: label) else { continue }
            return MortgageRateQuote(rate: percent / 100, periodLabel: label, periodDate: date, sourceName: "1 个月 HIBOR", fetchedAt: fetchedAt)
        }
        throw MortgageRateError.parseFailed
    }

    /// Flat 35 页面：去标签后取「21 年 ～ 35 年」区间的首个利率（最频利率与其一致），时期取「※YYYY年M月現在」。
    static func parseFlat35HTML(_ data: Data, sourceName: String, fetchedAt: Date) throws -> MortgageRateQuote {
        guard let html = String(data: data, encoding: .utf8) else { throw MortgageRateError.parseFailed }
        let text = html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
        let fullRange = NSRange(text.startIndex..., in: text)
        guard let rateRegex = try? NSRegularExpression(pattern: #"21\s*年\s*[～~]\s*35\s*年\s*年\s*([\d.]+)\s*%"#),
              let rateMatch = rateRegex.firstMatch(in: text, range: fullRange),
              let rateCapture = Range(rateMatch.range(at: 1), in: text),
              let percent = Double(text[rateCapture]) else { throw MortgageRateError.parseFailed }

        var periodLabel = ""
        var date: Date?
        if let periodRegex = try? NSRegularExpression(pattern: #"(\d{4})\s*年\s*(\d{1,2})\s*月現在"#),
           let periodMatch = periodRegex.firstMatch(in: text, range: fullRange),
           let yearCapture = Range(periodMatch.range(at: 1), in: text),
           let monthCapture = Range(periodMatch.range(at: 2), in: text),
           let year = Int(text[yearCapture]), let month = Int(text[monthCapture]) {
            periodLabel = String(format: "%04d-%02d", year, month)
            date = periodDate(from: periodLabel)
        }
        guard let date else { throw MortgageRateError.parseFailed }
        return MortgageRateQuote(rate: percent / 100, periodLabel: periodLabel, periodDate: date, sourceName: sourceName, fetchedAt: fetchedAt)
    }

    // MARK: - 小工具

    /// 简易 CSV 切分（处理双引号包裹）。
    static func csvFields(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for character in line {
            if character == "\"" {
                inQuotes.toggle()
            } else if character == ",", !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(character)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    /// 把各种来源的时期写法统一成日期（取期初）。
    static func periodDate(from label: String) -> Date? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let patterns: [(String, Locale)] = [
            ("yyyy-MM-dd", Locale(identifier: "en_US_POSIX")),
            ("yyyy-MM", Locale(identifier: "en_US_POSIX")),
            ("dd MMM yyyy", Locale(identifier: "en_GB")),
            ("d MMM yyyy", Locale(identifier: "en_GB")),
            ("MMM yyyy", Locale(identifier: "en_US_POSIX")),
            ("dd/MM/yyyy", Locale(identifier: "en_GB")),
        ]
        for (pattern, locale) in patterns {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = locale
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = pattern
            if let date = formatter.date(from: trimmed) { return date }
        }
        // "2026Aug" 形式
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        if trimmed.count == 7, let year = Int(trimmed.prefix(4)),
           let month = monthNames.firstIndex(of: String(trimmed.suffix(3))) {
            return calendar.date(from: DateComponents(year: year, month: month + 1, day: 1))
        }
        return nil
    }
}
