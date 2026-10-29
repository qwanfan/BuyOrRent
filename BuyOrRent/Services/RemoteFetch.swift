import Foundation

enum RemoteFetchError: Error, Equatable {
    case http(Int)
}

/// 共享的联网抓取：浏览器 UA（部分官方站点会拦截无 UA 请求）、10 秒超时、校验 HTTP 状态。
enum RemoteFetch {
    static func fetch(_ url: URL, timeout: TimeInterval = 10) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("text/csv, application/json, text/html", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RemoteFetchError.http(http.statusCode)
        }
        return data
    }
}
