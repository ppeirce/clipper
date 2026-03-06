import Foundation

enum ExportPreset: String, CaseIterable, Identifiable, Sendable {
    case fastH264 = "fast-h264"
    case qualityH264 = "quality-h264"
    case compactHEVC = "compact-hevc"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .fastH264:
            return "Fast H.264"
        case .qualityH264:
            return "Quality H.264"
        case .compactHEVC:
            return "Compact HEVC"
        }
    }

    var summary: String {
        switch self {
        case .fastH264:
            return "Fast turnaround H.264 export with balanced quality."
        case .qualityH264:
            return "Higher-quality H.264 export for review or delivery."
        case .compactHEVC:
            return "Smaller HEVC export tagged for broad Apple playback."
        }
    }

    var buttonIdentifier: String {
        "preset-\(rawValue)"
    }

    var ffmpegArguments: [String] {
        switch self {
        case .fastH264:
            return [
                "-c:v", "libx264",
                "-preset", "veryfast",
                "-crf", "23",
                "-c:a", "aac",
                "-b:a", "192k"
            ]
        case .qualityH264:
            return [
                "-c:v", "libx264",
                "-preset", "slow",
                "-crf", "18",
                "-c:a", "aac",
                "-b:a", "256k"
            ]
        case .compactHEVC:
            return [
                "-c:v", "libx265",
                "-preset", "medium",
                "-crf", "28",
                "-tag:v", "hvc1",
                "-c:a", "aac",
                "-b:a", "160k"
            ]
        }
    }
}
