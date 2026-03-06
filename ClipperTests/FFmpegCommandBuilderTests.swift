import AVFoundation
import XCTest
@testable import ClipperKit

final class FFmpegCommandBuilderTests: XCTestCase {
    func testBuilderProducesAnAccurateReencodeCommand() {
        let builder = FFmpegCommandBuilder(executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"))
        let job = ExportJob(
            clip: ClipSegment(start: .clipperSeconds(5), end: .clipperSeconds(12.5)),
            index: 1,
            inputURL: URL(fileURLWithPath: "/tmp/My Source.mov"),
            outputURL: URL(fileURLWithPath: "/tmp/output.mp4")
        )

        let command = builder.command(for: job, preset: .fastH264)

        XCTAssertEqual(command.arguments, [
            "-hide_banner",
            "-loglevel", "error",
            "-i", "/tmp/My Source.mov",
            "-ss", "00:00:05.000",
            "-t", "00:00:07.500",
            "-map", "0:v:0",
            "-map", "0:a?",
            "-c:v", "libx264",
            "-preset", "veryfast",
            "-crf", "23",
            "-c:a", "aac",
            "-b:a", "192k",
            "-movflags", "+faststart",
            "/tmp/output.mp4"
        ])
    }

    func testBuilderSupportsCompactHEVCPreset() {
        let builder = FFmpegCommandBuilder(executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"))
        let job = ExportJob(
            clip: ClipSegment(start: .clipperSeconds(2), end: .clipperSeconds(6)),
            index: 1,
            inputURL: URL(fileURLWithPath: "/tmp/My Source.mov"),
            outputURL: URL(fileURLWithPath: "/tmp/output.mp4")
        )

        let command = builder.command(for: job, preset: .compactHEVC)

        XCTAssertTrue(command.arguments.contains("libx265"))
        XCTAssertTrue(command.arguments.contains("hvc1"))
        XCTAssertTrue(command.arguments.contains("28"))
    }

    func testPlannerAvoidsExistingFilenames() {
        let jobs = ClipExportPlanner.plan(
            sourceURL: URL(fileURLWithPath: "/tmp/source.mov"),
            clips: [
                ClipSegment(start: .clipperSeconds(1), end: .clipperSeconds(2)),
                ClipSegment(start: .clipperSeconds(3), end: .clipperSeconds(4))
            ],
            outputDirectory: URL(fileURLWithPath: "/tmp/export"),
            existingFilenames: ["source_clip_01.mp4"]
        )

        XCTAssertEqual(jobs.map(\.outputURL.lastPathComponent), [
            "source_clip_01_2.mp4",
            "source_clip_02.mp4"
        ])
    }
}
