import AVFoundation

extension CMTime {
    static let clipperTimescale: CMTimeScale = 600

    static func clipperSeconds(_ seconds: Double) -> CMTime {
        CMTime(seconds: seconds, preferredTimescale: clipperTimescale)
    }

    var rawSecondsValue: Double {
        CMTimeGetSeconds(self)
    }

    var secondsValue: Double {
        let value = rawSecondsValue
        return value.isFinite ? value : 0
    }

    func clamped(lower: CMTime, upper: CMTime) -> CMTime {
        if CMTimeCompare(self, lower) < 0 {
            return lower
        }
        if CMTimeCompare(self, upper) > 0 {
            return upper
        }
        return self
    }

    func isEqualTo(_ other: CMTime) -> Bool {
        CMTimeCompare(self, other) == 0
    }
}
