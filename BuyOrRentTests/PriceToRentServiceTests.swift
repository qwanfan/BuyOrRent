import XCTest
@testable import BuyOrRent

final class PriceToRentServiceTests: XCTestCase {
    func testAveragesCityAndOutsideAndReadsWrappedHeaders() throws {
        let html = """
        <html><head><title>Property Prices Index by Country 2026 Mid-Year</title></head>
        <body><table id="t2"><thead><tr>
        <th>Rank</th>
        <th>Country</th>
        <th><div>Price To Rent Ratio City Centre</div></th>
        <th><div>Price To Rent Ratio Outside Of City Centre</div></th>
        </tr></thead><tbody>
        <tr><td></td><td class="cityOrCountryInIndicesTable">Hong Kong (China)</td><td>44.1</td><td>40.6</td></tr>
        \(otherRows(city: "20.0", outside: "20.0", leadingEmpty: true))
        </tbody></table></body></html>
        """
        let fetched = Date(timeIntervalSince1970: 1_761_868_800)
        let table = try PriceToRentParser.parse(html, fetchedOn: fetched)
        XCTAssertEqual(table.periodLabel, "2026 Mid-Year")
        XCTAssertEqual(table.years["hongKong"] ?? 0, 42.4, accuracy: 0.000_1)
        XCTAssertEqual(table.years["unitedStates"] ?? 0, 20, accuracy: 0.000_1)
        XCTAssertEqual(table.years.count, Country.allCases.count)
    }

    func testPeriodFallsBackToFetchMonth() throws {
        let html = """
        <html><head><title>Property Prices Index by Country</title></head>
        <table id="t2"><tr>
        <th>Country</th><th>Price To Rent Ratio City Centre</th><th>Price To Rent Ratio Outside Of City Centre</th>
        </tr>\(allRows(city: "12.0", outside: "12.0"))</table></html>
        """
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let fetched = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31))!
        let table = try PriceToRentParser.parse(html, fetchedOn: fetched)
        XCTAssertEqual(table.periodLabel, "2026-10")
    }

    func testRejectsMissingCountry() {
        let html = """
        <html><table id="t2"><tr>
        <th>Country</th><th>Price To Rent Ratio City Centre</th><th>Price To Rent Ratio Outside Of City Centre</th>
        </tr>\(otherRows(city: "12.0", outside: "12.0"))</table></html>
        """
        XCTAssertThrowsError(try PriceToRentParser.parse(html)) { error in
            XCTAssertEqual(error as? PriceToRentError, .coverage)
        }
    }

    private func allRows(city: String, outside: String) -> String {
        [
            "China", "Hong Kong (China)", "United States", "Canada", "Singapore", "Australia",
            "Japan", "United Kingdom", "Germany", "France", "Netherlands", "Spain", "Italy", "Switzerland"
        ].map { "<tr><td>\($0)</td><td>\(city)</td><td>\(outside)</td></tr>" }.joined()
    }

    private func otherRows(city: String, outside: String, leadingEmpty: Bool = false) -> String {
        let prefix = leadingEmpty ? "<td></td>" : ""
        return [
            "China", "United States", "Canada", "Singapore", "Australia", "Japan",
            "United Kingdom", "Germany", "France", "Netherlands", "Spain", "Italy", "Switzerland"
        ].map { "<tr>\(prefix)<td>\($0)</td><td>\(city)</td><td>\(outside)</td></tr>" }.joined()
    }
}
