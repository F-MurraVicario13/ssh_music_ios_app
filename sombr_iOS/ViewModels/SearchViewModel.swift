import Foundation
import SwiftUI

@MainActor
final class SearchViewModel: ObservableObject {

    @Published var query: String = ""
    @Published var results: [SearchResult] = []
    @Published var isSearching = false
    @Published var searchError: String?

    /// One DownloadJob per result ID, keyed by SearchResult.id.
    @Published var jobs: [String: DownloadJob] = [:]

    private var searchTask: Task<Void, Never>?

    // MARK: - Search

    func search() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            results = []
            return
        }
        isSearching = true
        searchError = nil

        searchTask = Task {
            do {
                let found = try await MetadataService.search(query: q)
                guard !Task.isCancelled else { return }
                results = found
                let visibleIDs = Set(found.map(\.id))
                jobs = jobs.filter { visibleIDs.contains($0.key) || $0.value.status.isActive }
                // Pre-create idle jobs for each result
                for r in found where jobs[r.id] == nil {
                    jobs[r.id] = DownloadJob(result: r)
                }
            } catch {
                guard !Task.isCancelled else { return }
                searchError = error.localizedDescription
                results = []
            }
            isSearching = false
        }
    }

    // MARK: - Download

    func download(result: SearchResult) {
        guard let config = KeychainService.loadConfig() else {
            let job = jobs[result.id] ?? DownloadJob(result: result)
            job.status = .failed("SSH is not configured. Go to Settings first.")
            jobs[result.id] = job
            return
        }

        let job: DownloadJob
        if let existing = jobs[result.id] {
            job = existing
        } else {
            job = DownloadJob(result: result)
            jobs[result.id] = job
        }

        // Prevent double-tapping while active
        guard !job.status.isActive else { return }

        job.log = ""
        job.status = .connecting

        Task {
            do {
                let stream = await SSHManager.shared.runSomeDL(
                    query: result.someDLQuery,
                    config: config
                )

                job.status = .running

                for try await chunk in stream {
                    job.appendLog(chunk)
                }

                job.status = .done
            } catch {
                job.status = .failed(error.localizedDescription)
                job.appendLog("\n[Error] \(error.localizedDescription)\n")
            }
        }
    }

    /// Returns the job for a given result, creating an idle one if missing.
    func job(for result: SearchResult) -> DownloadJob {
        if let j = jobs[result.id] { return j }
        let j = DownloadJob(result: result)
        jobs[result.id] = j
        return j
    }
}
