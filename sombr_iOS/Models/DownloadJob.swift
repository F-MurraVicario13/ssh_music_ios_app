import Foundation

enum DownloadStatus: Equatable {
    case idle
    case connecting
    case running
    case done
    case failed(String)

    var label: String {
        switch self {
        case .idle:           return "Download"
        case .connecting:     return "Connecting…"
        case .running:        return "Running…"
        case .done:           return "Done ✓"
        case .failed:         return "Error"
        }
    }

    var isActive: Bool {
        self == .connecting || self == .running
    }
}

/// Tracks one somedl invocation for a specific search result.
@MainActor
final class DownloadJob: ObservableObject, Identifiable {
    let id: UUID
    let result: SearchResult
    @Published var status: DownloadStatus = .idle
    @Published var log: String = ""

    init(result: SearchResult) {
        self.id = UUID()
        self.result = result
    }

    func appendLog(_ text: String) {
        log += text
    }
}
