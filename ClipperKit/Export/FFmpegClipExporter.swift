import Foundation

protocol ProcessRunning: Sendable {
    func run(executableURL: URL, arguments: [String]) async throws
}

protocol ClipExporting: Sendable {
    func export(sourceURL: URL, clips: [ClipSegment], outputDirectory: URL, preset: ExportPreset) async throws -> [URL]
}

enum ExportError: LocalizedError, Equatable {
    case missingFFmpeg
    case noClips
    case processFailed(status: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .missingFFmpeg:
            return "ffmpeg was not found. Use a packaged Clipper.app that includes ffmpeg, or install it at /opt/homebrew/bin/ffmpeg or /usr/local/bin/ffmpeg."
        case .noClips:
            return "Create at least one clip before exporting."
        case let .processFailed(status, stderr):
            let detail = stderr.isEmpty ? "Unknown ffmpeg failure." : stderr
            return "ffmpeg exited with status \(status): \(detail)"
        }
    }
}

final class FFmpegClipExporter: ClipExporting, @unchecked Sendable {
    private let executableURL: URL?
    private let processRunner: ProcessRunning
    private let directoryContents: @Sendable (URL) throws -> Set<String>
    private let tracer: RuntimeTraceRecording?

    init(
        executableURL: URL? = FFmpegExecutableLocator.locate(),
        processRunner: ProcessRunning = LiveProcessRunner(),
        directoryContents: @escaping @Sendable (URL) throws -> Set<String> = FFmpegClipExporter.liveDirectoryContents,
        tracer: RuntimeTraceRecording? = nil
    ) {
        self.executableURL = executableURL
        self.processRunner = processRunner
        self.directoryContents = directoryContents
        self.tracer = tracer
    }

    func export(sourceURL: URL, clips: [ClipSegment], outputDirectory: URL, preset: ExportPreset) async throws -> [URL] {
        guard !clips.isEmpty else {
            throw ExportError.noClips
        }
        guard let executableURL else {
            throw ExportError.missingFFmpeg
        }

        let existingFilenames = try directoryContents(outputDirectory)
        let jobs = ClipExportPlanner.plan(
            sourceURL: sourceURL,
            clips: clips,
            outputDirectory: outputDirectory,
            existingFilenames: existingFilenames
        )
        let builder = FFmpegCommandBuilder(executableURL: executableURL)
        await tracer?.record(
            category: .export,
            message: "Starting export",
            details: "\(jobs.count) clip(s) using \(preset.displayName)"
        )

        do {
            for job in jobs {
                let command = builder.command(for: job, preset: preset)
                AppLogger.export.info(
                    "Exporting clip \(job.index, privacy: .public) to \(job.outputURL.lastPathComponent, privacy: .public)"
                )
                await tracer?.record(
                    category: .export,
                    message: "Exporting clip",
                    details: "Clip \(job.index) -> \(job.outputURL.lastPathComponent)"
                )
                try await processRunner.run(
                    executableURL: command.executableURL,
                    arguments: command.arguments
                )
            }
            await tracer?.record(
                category: .export,
                message: "Finished export",
                details: "\(jobs.count) clip(s)"
            )
        } catch {
            await tracer?.record(
                category: .export,
                message: "Export failed",
                details: error.localizedDescription
            )
            throw error
        }

        return jobs.map(\.outputURL)
    }

    private static func liveDirectoryContents(_ url: URL) throws -> Set<String> {
        Set(try FileManager.default.contentsOfDirectory(atPath: url.path))
    }
}

final class LiveProcessRunner: ProcessRunning, @unchecked Sendable {
    func run(executableURL: URL, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stderrPipe = Pipe()

            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = stderrPipe
            process.terminationHandler = { completedProcess in
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = String(data: stderrData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if completedProcess.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: ExportError.processFailed(
                            status: completedProcess.terminationStatus,
                            stderr: stderr
                        )
                    )
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
