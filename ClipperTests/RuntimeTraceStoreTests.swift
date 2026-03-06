import XCTest
@testable import ClipperKit

final class RuntimeTraceStoreTests: XCTestCase {
    func testTraceStoreKeepsRecentEventsAndWritesJSONLines() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jsonl")
        let store = RuntimeTraceStore(traceFileURL: fileURL, maxEventCount: 2)

        await store.record(category: .playback, message: "Loaded video", details: "fixture.mov")
        await store.record(category: .clip, message: "Selected clip", details: "Clip 1")
        await store.record(category: .export, message: "Finished export", details: "2 clips")

        let events = await store.recentEvents()
        let fileContents = try String(contentsOf: fileURL)

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.map(\.message), ["Selected clip", "Finished export"])
        XCTAssertTrue(fileContents.contains("\"category\":\"playback\""))
        XCTAssertTrue(fileContents.contains("\"category\":\"export\""))
    }
}
