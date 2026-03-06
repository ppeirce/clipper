import Foundation

struct ExportJob: Equatable {
    let clip: ClipSegment
    let index: Int
    let inputURL: URL
    let outputURL: URL
}

enum ClipExportPlanner {
    static func plan(
        sourceURL: URL,
        clips: [ClipSegment],
        outputDirectory: URL,
        existingFilenames: Set<String> = []
    ) -> [ExportJob] {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        var occupiedNames = existingFilenames

        return clips.enumerated().map { offset, clip in
            let fileRoot = "\(baseName)_clip_\(String(format: "%02d", offset + 1))"
            var filename = "\(fileRoot).mp4"
            var collisionIndex = 2

            while occupiedNames.contains(filename) {
                filename = "\(fileRoot)_\(collisionIndex).mp4"
                collisionIndex += 1
            }

            occupiedNames.insert(filename)

            return ExportJob(
                clip: clip,
                index: offset + 1,
                inputURL: sourceURL,
                outputURL: outputDirectory.appendingPathComponent(filename)
            )
        }
    }
}
