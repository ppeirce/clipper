import AVKit
import SwiftUI

struct PlayerSurfaceView: View {
    let player: AVPlayer
    let showsPlaceholder: Bool

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
        }
        .overlay(
            Rectangle()
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
