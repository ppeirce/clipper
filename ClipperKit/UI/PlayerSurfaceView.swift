import AVKit
import SwiftUI
import UniformTypeIdentifiers

struct PlayerSurfaceView: View {
    let player: AVPlayer
    let showsPlaceholder: Bool
    let onOpenDroppedFile: (URL) -> Void

    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.96),
                            Color(red: 0.08, green: 0.085, blue: 0.095)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            NativePlayerView(player: player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))

            if showsPlaceholder {
                VStack(spacing: 12) {
                    Text("No Source")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(ConsolePalette.textPrimary)

                    Text("MP4  MOV  H.264  H.265")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(ConsolePalette.textMuted)

                    HStack(spacing: 8) {
                        PlaceholderBadge(label: "Space")
                        PlaceholderBadge(label: "I")
                        PlaceholderBadge(label: "O")
                    }
                }
                .padding(24)
                .allowsHitTesting(false)
            }

            if isDropTargeted {
                Rectangle()
                    .fill(Color.black.opacity(0.42))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 28, weight: .semibold))
                            Text("Drop Video to Open")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(ConsolePalette.textPrimary)
                    }
                    .allowsHitTesting(false)
            }
        }
        .overlay(
            Rectangle()
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted, perform: handleDrop(providers:))
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let url = Self.extractURL(from: item) else {
                return
            }

            Task { @MainActor in
                onOpenDroppedFile(url)
            }
        }

        return true
    }

    private nonisolated static func extractURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let url = item as? NSURL {
            return url as URL
        }

        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }

        if let text = item as? String, let url = URL(string: text), url.isFileURL {
            return url
        }

        return nil
    }
}

private struct NativePlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
        nsView.controlsStyle = .none
        nsView.videoGravity = .resizeAspect
    }
}

private struct PlaceholderBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(ConsolePalette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}
