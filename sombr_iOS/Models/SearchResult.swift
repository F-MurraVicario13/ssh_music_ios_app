import Foundation

/// One track returned by the iTunes Search API.
struct SearchResult: Identifiable, Equatable {
    let id: String          // String-cast trackId from iTunes
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval  // seconds
    let artworkURL: URL?

    /// Shell-safe query string passed verbatim to somedl.
    /// Format: "Artist - Title" — recognised by yt-dlp's search heuristic.
    var someDLQuery: String { "\(artist) - \(title)" }

    var durationFormatted: String {
        let total = Int(duration)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - iTunes API decoding

struct iTunesSearchResponse: Decodable {
    let results: [iTunesTrack]
}

struct iTunesTrack: Decodable {
    let trackId: Int?
    let trackName: String?
    let artistName: String?
    let collectionName: String?
    let trackTimeMillis: Double?
    let artworkUrl100: String?

    func toSearchResult() -> SearchResult? {
        guard
            let id = trackId,
            let title = trackName, !title.isEmpty,
            let artist = artistName, !artist.isEmpty
        else { return nil }

        return SearchResult(
            id: String(id),
            title: title,
            artist: artist,
            album: collectionName ?? "",
            duration: (trackTimeMillis ?? 0) / 1000,
            artworkURL: artworkUrl100.flatMap { URL(string: $0) }
        )
    }
}
