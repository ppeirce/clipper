import AVFoundation
import XCTest
@testable import ClipperKit

final class EditorReducerTests: XCTestCase {
    func testVideoLoadedResetsStateAndEmitsInitialEffects() {
        let asset = makeAsset()
        var state = EditorState(
            asset: nil,
            currentTime: .clipperSeconds(12),
            isPlaying: true,
            pendingInPoint: .clipperSeconds(8),
            clips: [ClipSegment(start: .clipperSeconds(1), end: .clipperSeconds(2))],
            lastError: "Previous error"
        )

        let effects = EditorReducer.reduce(state: &state, action: .videoLoaded(asset))

        XCTAssertEqual(state, EditorState(asset: asset))
        XCTAssertEqual(effects, [.seek(.zero), .setPlaying(false)])
    }

    func testSeekSecondsClampsInsideTheLoadedAsset() {
        var state = EditorState(asset: makeAsset(duration: 20), currentTime: .clipperSeconds(18))

        let effects = EditorReducer.reduce(state: &state, action: .seekSeconds(5))

        XCTAssertTrue(state.currentTime.isEqualTo(.clipperSeconds(20)))
        XCTAssertEqual(effects, [.seek(.clipperSeconds(20))])
    }

    func testSeekFramesUsesFrameDuration() {
        var state = EditorState(
            asset: makeAsset(duration: 20, frameDuration: 1.0 / 24.0),
            currentTime: .clipperSeconds(10)
        )

        let effects = EditorReducer.reduce(state: &state, action: .seekFrames(-1))

        XCTAssertEqual(state.currentTime.secondsValue, 10.0 - (1.0 / 24.0), accuracy: 0.0001)
        XCTAssertEqual(effects.count, 1)
    }

    func testMarkInThenMarkOutCreatesAClip() {
        let asset = makeAsset(duration: 60)
        var state = EditorState(asset: asset, currentTime: .clipperSeconds(5))

        _ = EditorReducer.reduce(state: &state, action: .markIn)
        state.currentTime = .clipperSeconds(12)
        _ = EditorReducer.reduce(state: &state, action: .markOut)

        XCTAssertNil(state.pendingInPoint)
        XCTAssertEqual(state.clips.count, 1)
        XCTAssertTrue(state.clips[0].start.isEqualTo(.clipperSeconds(5)))
        XCTAssertTrue(state.clips[0].end.isEqualTo(.clipperSeconds(12)))
    }

    func testMarkOutBeforeMarkInReportsAnError() {
        let asset = makeAsset(duration: 60)
        var state = EditorState(asset: asset, currentTime: .clipperSeconds(10))

        _ = EditorReducer.reduce(state: &state, action: .markIn)
        state.currentTime = .clipperSeconds(9)
        _ = EditorReducer.reduce(state: &state, action: .markOut)

        XCTAssertEqual(state.lastError, "End point must be after the start point.")
        XCTAssertTrue(state.pendingInPoint?.isEqualTo(.clipperSeconds(10)) ?? false)
        XCTAssertTrue(state.clips.isEmpty)
    }

    private func makeAsset(duration: Double = 120, frameDuration: Double = 1.0 / 30.0) -> VideoAssetContext {
        VideoAssetContext(
            url: URL(fileURLWithPath: "/tmp/source.mov"),
            duration: .clipperSeconds(duration),
            frameDuration: .clipperSeconds(frameDuration)
        )
    }
}
