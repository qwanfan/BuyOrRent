import Foundation

struct PriceToRentTable: Equatable, Codable, Sendable {
    var periodLabel: String
    var years: [String: Double]
}

enum PriceToRentError: Error, Equatable {
    case unreadable
    case tableNotFound
    case missingColumn
    case invalidNumber
    case coverage
}

/// 从 Numbeo 国家排名页读取市中心与市郊租售比的平均值。
enum PriceToRentParser {
    static let sourceName = "Numbeo"
    static let rankingsURL = URL(string: "https://www.numbeo.com/property-investment/rankings_by_country.jsp")!

    private static let names: [String: String] = [
        "China": "chinaMainland",
        "Hong Kong (China)": "hongKong",
        "United States": "unitedStates",
        "Canada": "canada",
        "Singapore": "singapore",
        "Australia": "australia",
        "Japan": "japan",
        "United Kingdom": "unitedKingdom",
        "Germany": "germany",
        "France": "france",
        "Netherlands": "netherlands",
        "Spain": "spain",
        "Italy": "italy",
        "Switzerland": "switzerland",
    ]

    static func parse(_ html: String, fetchedOn: Date = Date()) throws -> PriceToRentTable {
        let rows = try tableRows(in: html)
        guard let header = rows.first else { throw PriceToRentError.tableNotFound }
        guard let countryIndex = header.firstIndex(of: "Country"),
              let cityIndex = header.firstIndex(of: "Price To Rent Ratio City Centre"),
              let outsideIndex = header.firstIndex(of: "Price To Rent Ratio Outside Of City Centre") else {
            throw PriceToRentError.missingColumn
        }

        var found: [String: Double] = [:]
        for row in rows.dropFirst() {
            let last = max(countryIndex, cityIndex, outsideIndex)
            guard row.count > last else { continue }
            guard let country = names[row[countryIndex]] else { continue }
            guard found[country] == nil else { throw PriceToRentError.coverage }
            guard let city = Double(row[cityIndex]), let outside = Double(row[outsideIndex]) else {
                throw PriceToRentError.invalidNumber
            }
            let years = ((city + outside) / 2 * 10).rounded() / 10
            guard (5...80).contains(years) else { throw PriceToRentError.invalidNumber }
            found[country] = years
        }

        let expected = Set(Country.allCases.map(\.rawValue))
        guard Set(found.keys) == expected else { throw PriceToRentError.coverage }
        return PriceToRentTable(periodLabel: periodLabel(in: html, fetchedOn: fetchedOn), years: found)
    }

    private static func tableRows(in html: String) throws -> [[String]] {
        guard let start = html.range(of: "<table id=\"t2\"") ?? html.range(of: "<table id='t2'") else {
            throw PriceToRentError.tableNotFound
        }
        let rest = html[start.lowerBound...]
        guard let end = rest.range(of: "</table>") else { throw PriceToRentError.tableNotFound }
        let table = String(rest[..<end.upperBound])
        var rows: [[String]] = []
        var search = table.startIndex
        while let rowStart = table.range(of: "<tr", range: search..<table.endIndex) {
            guard let rowEnd = table.range(of: "</tr>", range: rowStart.upperBound..<table.endIndex) else { break }
            let rowHTML = String(table[rowStart.lowerBound..<rowEnd.upperBound])
            let cells = cellTexts(in: rowHTML)
            if !cells.isEmpty { rows.append(cells) }
            search = rowEnd.upperBound
        }
        guard !rows.isEmpty else { throw PriceToRentError.tableNotFound }
        return rows
    }

    private static func cellTexts(in rowHTML: String) -> [String] {
        var cells: [String] = []
        var search = rowHTML.startIndex
        while let open = rowHTML.range(of: "<t", options: .caseInsensitive, range: search..<rowHTML.endIndex) {
            let tagStart = rowHTML[open.lowerBound...].prefix(3).lowercased()
            if tagStart == "<tr" {
                search = open.upperBound
                continue
            }
            guard tagStart == "<td" || tagStart == "<th" else { break }
            guard let close = rowHTML.range(of: ">", range: open.upperBound..<rowHTML.endIndex) else { break }
            let endTag = tagStart == "<td" ? "</td>" : "</th>"
            guard let cellEnd = rowHTML.range(of: endTag, options: .caseInsensitive, range: close.upperBound..<rowHTML.endIndex) else {
                break
            }
            cells.append(plainText(String(rowHTML[close.upperBound..<cellEnd.lowerBound])))
            search = cellEnd.upperBound
        }
        return cells
    }

    private static func plainText(_ html: String) -> String {
        var text = ""
        var inTag = false
        for character in html {
            if character == "<" {
                inTag = true
            } else if character == ">" {
                inTag = false
            } else if !inTag {
                text.append(character)
            }
        }
        text = text.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        return text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func periodLabel(in html: String, fetchedOn: Date) -> String {
        let title: String
        if let open = html.range(of: "<title>", options: .caseInsensitive),
           let close = html.range(of: "</title>", options: .caseInsensitive, range: open.upperBound..<html.endIndex) {
            title = plainText(String(html[open.upperBound..<close.lowerBound]))
        } else {
            title = ""
        }
        if let match = title.range(of: #"20\d{2}(?:\s+Mid-Year)?"#, options: .regularExpression) {
            return String(title[match])
        }
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: fetchedOn)
        let month = calendar.component(.month, from: fetchedOn)
        return String(format: "%04d-%02d", year, month)
    }
}

final class PriceToRentService {
    private static let cacheKey = "priceToRent.v1"

    private let now: () -> Date
    private let fetchData: (URL) async throws -> Data
    private let cacheDefaults: UserDefaults

    init(
        now: @escaping () -> Date = Date.init,
        fetchData: @escaping (URL) async throws -> Data = { try await RemoteFetch.fetch($0, timeout: 20) },
        cacheDefaults: UserDefaults = .standard
    ) {
        self.now = now
        self.fetchData = fetchData
        self.cacheDefaults = cacheDefaults
    }

    func fetchTable() async throws -> PriceToRentTable {
        let data = try await fetchData(PriceToRentParser.rankingsURL)
        guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
            throw PriceToRentError.unreadable
        }
        let table = try PriceToRentParser.parse(html, fetchedOn: now())
        if let encoded = try? JSONEncoder().encode(table) {
            cacheDefaults.set(encoded, forKey: Self.cacheKey)
        }
        return table
    }

    func cachedTable() -> PriceToRentTable? {
        guard let data = cacheDefaults.data(forKey: Self.cacheKey) else { return nil }
        return try? JSONDecoder().decode(PriceToRentTable.self, from: data)
    }
}
