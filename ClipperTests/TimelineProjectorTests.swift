import AVFoundation
import XCTest
@testable import ClipperKit

final class TimelineProjectorTests: XCTestCase {
    func testProjectMapsClipsAndPlayheadIntoTheRibbon() {
        let clips = [
            ClipSegment(id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!, start: .clipperSeconds(10), end: .clipperSeconds(20)),
            ClipSegment(id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!, start: .clipperSeconds(30), end: .clipperSeconds(60))
        ]

        let layout = TimelineProjector.project(
            duration: .clipperSeconds(100),
            currentTime: .clipperSeconds(25),
            clips: clips,
            width: 500
        )

        XCTAssertEqual(layout.playheadX, 125, accuracy: 0.001)
        XCTAssertEqual(layout.segments[0].x, 50, accuracy: 0.001)
        XCTAssertEqual(layout.segments[0].width, 50, accuracy: 0.001)
        XCTAssertEqual(layout.segments[1].x, 150, accuracy: 0.001)
        XCTAssertEqual(layout.segments[1].width, 150, accuracy: 0.001)
    }

    func testProjectReturnsEmptyLayoutForZeroDuration() {
        let layout = TimelineProjector.project(duration: .zero, currentTime: .clipperSeconds(1), clips: [], width: 300)

        XCTAssertEqual(layout.playheadX, 0)
        XCTAssertTrue(layout.segments.isEmpty)
    }
}
