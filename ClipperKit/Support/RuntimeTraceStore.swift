import Foundation

enum TraceCategory: String, Codable, Sendable {
    case playback
    case clip
    case export
    case diagnostics

    var displayName: String {
        rawValue.capitalized
    }
}

struct RuntimeTraceEvent: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let category: TraceCategory
    let message: String
    let details: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: TraceCategory,
        message: String,
        details: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.message = message
        self.details = details
    }

    var displayLine: String {
        if let details, !details.isEmpty {
            return "\(category.displayName): \(message) (\(details))"
        }
        return "\(category.displayName): \(message)"
    }
}

protocol RuntimeTraceRecording: Sendable {
    var traceFileURL: URL { get }

    func record(category: TraceCategory, message: String, details: String?) async
    func recentEvents() async -> [RuntimeTraceEvent]
}

actor RuntimeTraceStore: RuntimeTraceRecording {
    let traceFileURL: URL

    private let maxEventCount: Int
    private var events: [RuntimeTraceEvent] = []
    private let encoder = JSONEncoder()

    init(
        traceFileURL: URL = FileManager.default.temporaryDirectory.appendingPathComponent("clipper-runtime-trace.jsonl"),
        maxEventCount: Int = 30
    ) {
        self.traceFileURL = traceFileURL
        self.maxEventCount = max(1, maxEventCount)
        encoder.dateEncodingStrategy = .iso8601
        try? Data().write(to: traceFileURL, options: .atomic)
    }

    func record(category: TraceCategory, message: String, details: String? = nil) async {
        let event = RuntimeTraceEvent(category: category, message: message, details: details)
        events.append(event)

        if events.count > maxEventCount {
            events.removeFirst(events.count - maxEventCount)
        }

        guard var data = try? encoder.encode(event) else {
            return
        }
        data.append(0x0A)

        do {
            let handle = try FileHandle(forWritingTo: traceFileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } catch {
            AppLogger.app.error("Trace write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func recentEvents() async -> [RuntimeTraceEvent] {
        events
    }
}
