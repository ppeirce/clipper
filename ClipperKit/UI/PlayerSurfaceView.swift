import AVKit
import SwiftUI

struct PlayerSurfaceView: View {
    let player: AVPlayer
    let showsPlaceholder: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.9))

            VideoPlayer(player: player)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            if showsPlaceholder {
                VStack(spacing: 12) {
                    Text("Open a video to start clipping")
                        .font(.title3.weight(.semibold))
                    Text("Supported workflows target MP4, MOV, H.264, and H.265 sources.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(24)
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 420)
    }
}
