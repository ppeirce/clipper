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
                "-movflags", "+faststart",
                job.outputURL.path
            ],
            outputURL: job.outputURL
        )
    }
}

enum FFmpegExecutableLocator {
    static func locate(fileManager: FileManager = .default) -> URL? {
        let candidatePaths = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg"
        ]

        for path in candidatePaths where fileManager.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        return nil
    }
}
