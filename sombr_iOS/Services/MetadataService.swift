import Foundation

/// Queries the iTunes Search API for music metadata.
/// No audio is fetched — artwork thumbnails are the only media downloaded.
enum MetadataService {

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 45
        return URLSession(configuration: cfg)
    }()

    /// Search iTunes for tracks matching `query`. Returns up to `limit` results.
    static func search(query: String, limit: Int = 15) async throws -> [SearchResult] {
        return try await search(query: query, limit: limit, retriesRemaining: 1)
    }

    private static func search(query: String, limit: Int, retriesRemaining: Int) async throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term",   value: query),
            URLQueryItem(name: "media",  value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit",  value: String(limit))
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let decoded = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)
            return decoded.results.compactMap { $0.toSearchResult() }
        } catch let error as URLError where retriesRemaining > 0 {
            if error.code == .timedOut || error.code == .networkConnectionLost {
                return try await search(query: query, limit: limit, retriesRemaining: retriesRemaining - 1)
            }
            throw error
        }
    }
}
