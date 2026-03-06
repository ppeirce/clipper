import AVFoundation
import Foundation

enum TimecodeFormatter {
    static func displayString(for time: CMTime) -> String {
        let totalMilliseconds = max(0, Int((time.secondsValue * 1000).rounded()))
        let hours = totalMilliseconds / 3_600_000
        let minutes = (totalMilliseconds % 3_600_000) / 60_000
        let seconds = (totalMilliseconds % 60_000) / 1000
        let milliseconds = totalMilliseconds % 1000
        return String(
            format: "%02d:%02d:%02d.%03d",
            hours,
            minutes,
            seconds,
            milliseconds
        )
    }

    static func ffmpegTimestamp(for time: CMTime) -> String {
        displayString(for: time)
    }
}
