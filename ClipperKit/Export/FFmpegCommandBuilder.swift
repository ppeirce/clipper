import Foundation

struct FFmpegCommand: Equatable {
    let executableURL: URL
    let arguments: [String]
    let outputURL: URL
}

struct FFmpegCommandBuilder {
    let executableURL: URL

    func command(for job: ExportJob, preset: ExportPreset) -> FFmpegCommand {
        FFmpegCommand(
            executableURL: executableURL,
            arguments: [
                "-hide_banner",
                "-loglevel", "error",
                "-i", job.inputURL.path,
                "-ss", TimecodeFormatter.ffmpegTimestamp(for: job.clip.start),
                "-t", TimecodeFormatter.ffmpegTimestamp(for: job.clip.duration),
                "-map", "0:v:0",
                "-map", "0:a?",
            ] + preset.ffmpegArguments + [
                "-movflags", "+faststart+negative_cts_offsets",
                "-avoid_negative_ts", "make_zero",
                "-use_editlist", "0",
                job.outputURL.path
            ],
            outputURL: job.outputURL
        )
    }
}

enum FFmpegExecutableLocator {
    static func locate(
        fileManager: FileManager = .default,
        bundleURL: URL = Bundle.main.bundleURL,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        systemCandidatePaths: [String] = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg"
        ]
    ) -> URL? {
        for candidateURL in candidateURLs(
            bundleURL: bundleURL,
            environment: environment,
            systemCandidatePaths: systemCandidatePaths
        ) where fileManager.isExecutableFile(atPath: candidateURL.path) {
            return candidateURL
        }

        return nil
    }

    static func candidateURLs(
        bundleURL: URL,
        environment: [String: String],
        systemCandidatePaths: [String]
    ) -> [URL] {
        var candidates: [URL] = []

        if let overridePath = environment["CLIPPER_FFMPEG_BIN"], !overridePath.isEmpty {
            candidates.append(URL(fileURLWithPath: overridePath))
        }

        candidates.append(
            bundleURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Helpers", isDirectory: true)
                .appendingPathComponent("ffmpeg", isDirectory: false)
        )

        candidates.append(contentsOf: systemCandidatePaths.map(URL.init(fileURLWithPath:)))
        return candidates
    }
}
