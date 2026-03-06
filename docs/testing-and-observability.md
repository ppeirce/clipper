# Testing And Observability

## Development posture

This project is intended to follow a strict verification loop:

1. define behavior in a reducer, formatter, planner, or protocol-driven service
2. write or extend tests around that behavior
3. implement the minimum code needed to satisfy the test
4. keep runtime traces in place for anything that becomes harder to observe from tests alone

The goal is not just "some tests." The goal is fast, repeatable evidence that editing and export behavior are correct.

## Automated suite

### Unit tests

`ClipperTests` currently covers:

- `EditorReducerTests.swift`: reducer transport and clip marking behavior
- `EditorWorkflowTests.swift`: clip selection, deletion, boundary editing, overlap rejection, and undo/redo flows
- `KeyboardShortcutInterpreterTests.swift`: keyboard command mapping
- `OpenWorkflowTests.swift`: supported-source filtering, direct URL opens, and recent-file bookkeeping
- `TimelineProjectorTests.swift`: ribbon geometry projection
- `FFmpegCommandBuilderTests.swift`: deterministic ffmpeg argument construction
- `FFmpegClipExporterTests.swift`: export orchestration, naming collisions, and failure propagation
- `RuntimeTraceStoreTests.swift`: trace buffering and JSONL persistence behavior

### UI tests

`ClipperUITests` currently covers:

- deleting a selected clip in fixture mode
- surfacing an overlap error when a selected clip edit would collide with another clip

## Test command

Run the full suite with:

```sh
xcodebuild \
  -project Clipper.xcodeproj \
  -scheme Clipper \
  -destination 'platform=macOS' \
  -derivedDataPath .deriveddata \
  test
```

## Fixture-mode test harness

UI tests launch the app with:

```text
--ui-test-fixture
```

That fixture path avoids the two biggest sources of flakiness in media apps:

- dependency on real video assets
- dependency on a live `ffmpeg` binary during UI interaction tests

Fixture-mode guarantees:

- fixed asset metadata
- fixed initial clip state
- stable accessibility identifiers
- predictable export filenames

## Runtime observability

### OSLog

The app defines three logging categories:

- `app`
- `playback`
- `export`

These are intended for Console.app and system log inspection.

### JSONL trace log

The runtime trace store writes line-delimited JSON events to:

```text
<temporary-directory>/clipper-runtime-trace.jsonl
```

Each event captures:

- event id
- timestamp
- category
- message
- optional details

Trace categories:

- `playback`
- `clip`
- `export`
- `diagnostics`

The trace store also keeps an in-memory event buffer so the latest activity can be rendered directly in the app.

### What is traced now

Current high-value traces include:

- app startup / fixture bootstrap
- video load success and failure
- play/pause, seek, and frame stepping
- clip selection, creation, edit success, edit rejection, deletion, and clear-all
- clip undo and redo operations with the restored boundary state
- export preset changes
- export queueing, per-clip export progress, final completion, and failures

## Failure investigation workflow

When behavior is wrong, use the signals in this order:

1. failing unit or UI test
2. app status message in the footer
3. recent events in the `Runtime Trace` panel
4. JSONL trace file contents
5. Console.app output for `com.peter.clipper`

This ordering keeps the fastest and most deterministic feedback first.

## Current verification gaps

The current suite is a strong starting point, but it is not complete.

Not yet covered:

- persistence and project reload
- post-export validation with `ffprobe`
- malformed or unsupported source-file handling at the file picker layer
- long-running export cancellation
- performance thresholds for very large clip sets
- broader UI automation around preset switching and export status handling

## Practical standards for future changes

When adding behavior:

- add or update reducer/service tests first when the logic is deterministic
- use the fixture launch path for UI-visible workflows
- add tracing for operations that cross async, process, or AVFoundation boundaries
- avoid hiding rules in SwiftUI views when those rules can live in the reducer
