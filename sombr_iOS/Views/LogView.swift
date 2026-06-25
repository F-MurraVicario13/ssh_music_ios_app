import SwiftUI

/// Full-screen live log for a single download job.
struct LogView: View {

    @ObservedObject var job: DownloadJob

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(job.log.isEmpty ? "Waiting for output…" : job.log)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id("bottom")
                        .onChange(of: job.log) { _, _ in
                            withAnimation {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(job.result.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    statusBadge
                }
            }
        }
    }

    private var statusBadge: some View {
        Group {
            switch job.status {
            case .idle:
                Label("Idle", systemImage: "circle")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
            case .connecting:
                ProgressView()
            case .running:
                Label("Running", systemImage: "waveform")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse)
            case .done:
                Label("Done", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.green)
            case .failed:
                Label("Error", systemImage: "xmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.red)
            }
        }
    }
}
