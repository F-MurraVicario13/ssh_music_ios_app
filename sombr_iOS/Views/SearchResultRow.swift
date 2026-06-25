import SwiftUI

struct SearchResultRow: View {

    let result: SearchResult
    @ObservedObject var job: DownloadJob
    let onDownload: () -> Void

    @State private var showLog = false

    var body: some View {
        HStack(spacing: 12) {
            artwork
            info
            Spacer(minLength: 0)
            controls
        }
        .contentShape(Rectangle())
        .sheet(isPresented: $showLog) {
            LogView(job: job)
        }
    }

    // MARK: - Sub-views

    private var artwork: some View {
        Group {
            if let url = result.artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        artworkPlaceholder
                    }
                }
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(.secondarySystemFill))
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
            }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(result.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            Text(result.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 4) {
                if !result.album.isEmpty {
                    Text(result.album)
                        .lineLimit(1)
                }
                Text("·")
                Text(result.durationFormatted)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    private var controls: some View {
        VStack(spacing: 6) {
            downloadButton
            if job.status != .idle {
                logButton
            }
        }
    }

    private var downloadButton: some View {
        Button(action: onDownload) {
            Group {
                if job.status.isActive {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 64, height: 26)
                } else {
                    Text(job.status.label)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                }
            }
            .background(buttonBackground)
            .foregroundStyle(buttonForeground)
            .clipShape(Capsule())
        }
        .disabled(job.status.isActive || job.status == .done)
        .buttonStyle(.plain)
    }

    private var logButton: some View {
        Button {
            showLog = true
        } label: {
            Image(systemName: "terminal")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var buttonBackground: Color {
        switch job.status {
        case .idle:       return Color.accentColor
        case .connecting,
             .running:    return Color(.systemFill)
        case .done:       return Color.green.opacity(0.15)
        case .failed:     return Color.red.opacity(0.15)
        }
    }

    private var buttonForeground: Color {
        switch job.status {
        case .idle:       return .white
        case .connecting,
             .running:    return .secondary
        case .done:       return .green
        case .failed:     return .red
        }
    }
}
