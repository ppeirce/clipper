import XCTest
@testable import ClipperKit

final class FFmpegExecutableLocatorTests: XCTestCase {
    func testLocatorPrefersExplicitEnvironmentOverride() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let overrideURL = tempDirectory.appendingPathComponent("override-ffmpeg")
        let bundledURL = tempDirectory
            .appendingPathComponent("Fake.app")
            .appendingPathComponent("Contents")
            .appendingPathComponent("Helpers")
            .appendingPathComponent("ffmpeg")
        try makeExecutable(at: overrideURL)
        try makeExecutable(at: bundledURL)

        let located = FFmpegExecutableLocator.locate(
            bundleURL: tempDirectory.appendingPathComponent("Fake.app"),
            environment: ["CLIPPER_FFMPEG_BIN": overrideURL.path],
            systemCandidatePaths: []
        )

        XCTAssertEqual(located, overrideURL)
    }

    func testLocatorFindsBundledHelperBeforeSystemFallback() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let bundleURL = tempDirectory.appendingPathComponent("Clipper.app")
        let bundledURL = bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Helpers")
            .appendingPathComponent("ffmpeg")
        let fallbackURL = tempDirectory.appendingPathComponent("system-ffmpeg")
        try makeExecutable(at: bundledURL)
        try makeExecutable(at: fallbackURL)

        let located = FFmpegExecutableLocator.locate(
            bundleURL: bundleURL,
            environment: [:],
            systemCandidatePaths: [fallbackURL.path]
        )

        XCTAssertEqual(located, bundledURL)
    }

    func testLocatorFallsBackToSystemPathWhenBundleDoesNotContainFFmpeg() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let fallbackURL = tempDirectory.appendingPathComponent("system-ffmpeg")
        try makeExecutable(at: fallbackURL)

        let located = FFmpegExecutableLocator.locate(
            bundleURL: tempDirectory.appendingPathComponent("Missing.app"),
            environment: [:],
            systemCandidatePaths: [fallbackURL.path]
        )

        XCTAssertEqual(located, fallbackURL)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeExecutable(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
}
