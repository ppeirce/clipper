import AVFoundation
import XCTest
@testable import ClipperKit

final class EditorWorkflowTests: XCTestCase {
    func testMarkOutRejectsOverlappingClip() {
        let existing = ClipSegment(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            start: .clipperSeconds(10),
            end: .clipperSeconds(20)
        )
        var state = EditorState(
            asset: makeAsset(),
            currentTime: .clipperSeconds(18),
            isPlaying: false,
            pendingInPoint: .clipperSeconds(5),
            clips: [existing],
            selectedClipID: existing.id,
            exportPreset: .fastH264,
            lastError: nil
        )

        _ = EditorReducer.reduce(state: &state, action: .markOut)

        XCTAssertEqual(state.lastError, "Clips cannot overlap existing ranges.")
        XCTAssertEqual(state.clips.count, 1)
        XCTAssertTrue(state.pendingInPoint?.isEqualTo(.clipperSeconds(5)) ?? false)
    }

    func testDeleteSelectedClipRemovesItAndSelectsNeighbor() {
        let first = ClipSegment(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            start: .clipperSeconds(1),
            end: .clipperSeconds(4)
        )
        let second = ClipSegment(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            start: .clipperSeconds(6),
            end: .clipperSeconds(9)
        )
        var state = EditorState(
            asset: makeAsset(),
            currentTime: .clipperSeconds(6),
            isPlaying: false,
            pendingInPoint: nil,
            clips: [first, second],
            selectedClipID: first.id,
            exportPreset: .fastH264,
            lastError: nil
        )

        _ = EditorReducer.reduce(state: &state, action: .deleteSelectedClip)

        XCTAssertEqual(state.clips, [second])
        XCTAssertEqual(state.selectedClipID, second.id)
    }

    func testAdjustingSelectedClipBoundaryRejectsOverlap() {
        let first = ClipSegment(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            start: .clipperSeconds(1),
            end: .clipperSeconds(4)
        )
        let second = ClipSegment(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            start: .clipperSeconds(6),
            end: .clipperSeconds(9)
        )
        var state = EditorState(
            asset: makeAsset(),
            currentTime: .clipperSeconds(3),
            isPlaying: false,
            pendingInPoint: nil,
            clips: [first, second],
            selectedClipID: second.id,
            exportPreset: .fastH264,
            lastError: nil
        )

        _ = EditorReducer.reduce(state: &state, action: .setSelectedClipBoundary(.start, to: .clipperSeconds(3)))

        XCTAssertEqual(state.lastError, "Clips cannot overlap existing ranges.")
        XCTAssertTrue(state.clips[1].start.isEqualTo(.clipperSeconds(6)))
    }

    func testAdjustingSelectedClipBoundaryUpdatesTheClip() {
        let clip = ClipSegment(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            start: .clipperSeconds(6),
            end: .clipperSeconds(9)
        )
        var state = EditorState(
            asset: makeAsset(),
            currentTime: .clipperSeconds(7),
            isPlaying: false,
            pendingInPoint: nil,
            clips: [clip],
            selectedClipID: clip.id,
            exportPreset: .fastH264,
            lastError: nil
        )

        _ = EditorReducer.reduce(state: &state, action: .setSelectedClipBoundary(.start, to: .clipperSeconds(7)))

        XCTAssertTrue(state.clips[0].start.isEqualTo(.clipperSeconds(7)))
        XCTAssertNil(state.lastError)
    }

    func testSetExportPresetStoresSelection() {
        var state = EditorState(asset: makeAsset())

        _ = EditorReducer.reduce(state: &state, action: .setExportPreset(.compactHEVC))

        XCTAssertEqual(state.exportPreset, .compactHEVC)
    }

    private func makeAsset() -> VideoAssetContext {
        VideoAssetContext(
            url: URL(fileURLWithPath: "/tmp/source.mov"),
            duration: .clipperSeconds(60),
            frameDuration: .clipperSeconds(1.0 / 30.0)
        )
    }
}
