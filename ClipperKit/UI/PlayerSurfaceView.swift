import AVKit
import SwiftUI

struct PlayerSurfaceView: View {
    let player: AVPlayer
    let showsPlaceholder: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.95),
                            Color(red: 0.08, green: 0.085, blue: 0.095)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.72))
                .padding(12)

            VideoPlayer(player: player)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(12)

            if showsPlaceholder {
                VStack(spacing: 14) {
                    Text("Open a source reel to start clipping")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(ConsolePalette.textPrimary)

                    Text("This console is tuned for MP4, MOV, H.264, and H.265 review workflows.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(ConsolePalette.textMuted)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 10) {
                        PlaceholderBadge(label: "I", caption: "Mark In")
                        PlaceholderBadge(label: "O", caption: "Mark Out")
                        PlaceholderBadge(label: "Space", caption: "Play")
                    }
                }
                .padding(28)
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 460)
    }
}

private struct PlaceholderBadge: View {
    let label: String
    let caption: String

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(ConsolePalette.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )

            Text(caption)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(ConsolePalette.textSubtle)
        }
    }
}
