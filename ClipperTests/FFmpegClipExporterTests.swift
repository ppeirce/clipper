import AVFoundation
import XCTest
@testable import ClipperKit

final class FFmpegClipExporterTests: XCTestCase {
    func testExporterRunsOneCommandPerClip() async throws {
        let processRunner = RecordingProcessRunner()
        let traceStore = RuntimeTraceStore(traceFileURL: makeTraceURL())
        let exporter = FFmpegClipExporter(
            executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"),
            processRunner: processRunner,
            directoryContents: { _ in ["source_clip_01.mp4"] },
            tracer: traceStore
        )

        let outputs = try await exporter.export(
            sourceURL: URL(fileURLWithPath: "/tmp/source.mov"),
            clips: [
                ClipSegment(start: .clipperSeconds(1), end: .clipperSeconds(4)),
                ClipSegment(start: .clipperSeconds(5), end: .clipperSeconds(8))
            ],
            outputDirectory: URL(fileURLWithPath: "/tmp/export"),
            preset: .qualityH264
        )

        let traces = await traceStore.recentEvents()

        XCTAssertEqual(processRunner.invocations.count, 2)
        XCTAssertEqual(outputs.map(\.lastPathComponent), [
            "source_clip_01_2.mp4",
            "source_clip_02.mp4"
        ])
        XCTAssertEqual(traces.last?.message, "Finished export")
    }

    func testExporterThrowsWhenFFmpegIsMissing() async {
        let exporter = FFmpegClipExporter(
            executableURL: nil,
            processRunner: RecordingProcessRunner(),
            directoryContents: { _ in [] }
        )

        do {
            _ = try await exporter.export(
                sourceURL: URL(fileURLWithPath: "/tmp/source.mov"),
                clips: [ClipSegment(start: .clipperSeconds(1), end: .clipperSeconds(2))],
                outputDirectory: URL(fileURLWithPath: "/tmp/export"),
                preset: .fastH264
            )
            XCTFail("Expected export to throw when ffmpeg is missing")
        } catch let error as ExportError {
            XCTAssertEqual(error, .missingFFmpeg)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testExporterPropagatesProcessFailures() async {
        let processRunner = RecordingProcessRunner()
        processRunner.error = ExportError.processFailed(status: 1, stderr: "boom")
        let traceStore = RuntimeTraceStore(traceFileURL: makeTraceURL())
        let exporter = FFmpegClipExporter(
            executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"),
            processRunner: processRunner,
            directoryContents: { _ in [] },
            tracer: traceStore
        )

        do {
            _ = try await exporter.export(
                sourceURL: URL(fileURLWithPath: "/tmp/source.mov"),
                clips: [ClipSegment(start: .clipperSeconds(1), end: .clipperSeconds(2))],
                outputDirectory: URL(fileURLWithPath: "/tmp/export"),
                preset: .fastH264
            )
            XCTFail("Expected export to propagate the process failure")
        } catch let error as ExportError {
            XCTAssertEqual(error, .processFailed(status: 1, stderr: "boom"))
            let traces = await traceStore.recentEvents()
            XCTAssertEqual(traces.last?.message, "Export failed")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeTraceURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jsonl")
    }
}

private final class RecordingProcessRunner: ProcessRunning, @unchecked Sendable {
    struct Invocation: Equatable {
        let executableURL: URL
        let arguments: [String]
    }

    var invocations: [Invocation] = []
    var error: Error?

    func run(executableURL: URL, arguments: [String]) async throws {
        invocations.append(Invocation(executableURL: executableURL, arguments: arguments))

        if let error {
            throw error
        }
    }
}
