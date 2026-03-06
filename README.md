# Clipper

`Clipper` is a macOS SwiftUI utility for reviewing a source video, marking multiple clip ranges, and exporting each range through `ffmpeg`.

The current implementation is intentionally narrow and testable:

- Single-source editing session per window.
- Keyboard-first transport and clip marking.
- Non-overlapping clip ranges only.
- One export run emits one output file per saved clip.
- Export behavior is explicit through named presets instead of hidden defaults.
- Runtime diagnostics are available both in the UI and in a JSONL trace log.

Deeper reference material lives in [`docs/architecture.md`](docs/architecture.md) and [`docs/testing-and-observability.md`](docs/testing-and-observability.md).

## Product workflow

1. Open a local source video from the toolbar, `File > Open...`, `File > Open Recent`, or by dragging a file onto the player.
2. Review playback in the main player surface.
3. Use the keyboard to seek, step, and mark clip boundaries.
4. Save one or more clips into the ribbon timeline.
5. Optionally select a clip and retime its start or end to the current playhead.
6. Choose an export preset.
7. Export all saved clips to a destination folder.

## Current operator controls

| Input | Behavior |
| --- | --- |
| `Space` | Toggle play/pause |
| `Left Arrow` | Seek backward 5 seconds |
| `Right Arrow` | Seek forward 5 seconds |
| `Shift + Left Arrow` | Step backward 1 frame |
| `Shift + Right Arrow` | Step forward 1 frame |
| `I` | Mark clip start at the current playhead |
| `O` | Mark clip end and create a clip |
| `Cmd + O` | Open a source video |
| `Cmd + N` | Open a new window |
| `Cmd + T` | Open a new tab in the current window |
| `Cmd + Z` | Undo the last clip-definition change |
| `Shift + Cmd + Z` | Redo the last undone clip-definition change |

The footer mirrors these controls in the running app.

Open paths currently supported in the app:

- toolbar `Open` button
- `File > Open...`
- `File > Open Recent`
- drag-and-drop onto the player surface

## Editing rules

- Clips are normalized against the loaded asset duration.
- A clip end must be strictly after its start.
- Saved clips are kept sorted by start time.
- Clip edits that would overlap another saved clip are rejected.
- Undo and redo only track clip-definition mutations: in/out marking, clip creation, clip edits, clip deletion, and clear-all.
- Creating or editing a clip updates the current selection.
- Deleting a clip keeps the selection on the next valid clip when possible.

## Export presets

`Clipper` currently ships with three export presets:

| Preset | Codec path | Intended tradeoff |
| --- | --- | --- |
| `Fast H.264` | `libx264`, `veryfast`, `crf 23`, AAC 192k | Fast turnaround for iteration |
| `Quality H.264` | `libx264`, `slow`, `crf 18`, AAC 256k | Higher visual quality |
| `Compact HEVC` | `libx265`, `medium`, `crf 28`, `hvc1`, AAC 160k | Smaller files for Apple-friendly playback |

The exporter always adds:

- `-hide_banner`
- `-loglevel error`
- `-map 0:v:0`
- `-map 0:a?`
- `-movflags +faststart+negative_cts_offsets`
- `-avoid_negative_ts make_zero`
- `-use_editlist 0`

These flags keep the exported MP4s zero-based and avoid MP4 edit-list lead-ins that can show up as black first frames in Apple playback stacks.

Output filenames are deterministic and collision-safe:

- Primary pattern: `<source>_clip_01.mp4`
- Collision pattern: `<source>_clip_01_2.mp4`, `<source>_clip_01_3.mp4`, and so on

## Supported media scope

The product target is local video review for `mp4`, `mov`, `h264`, and `h265` sources.

Current implementation detail:

- The open workflow accepts `mp4`, `mov`, `m4v`, `h264`, `h265`, and `hevc` extensions.
- Successful opens are recorded into the app's recent-file menu.
- Export always emits `.mp4` files through `ffmpeg`.
- Raw stream handling depends on what AVFoundation can open and what `ffmpeg` can later remux or transcode on the machine.

## Runtime diagnostics

Runtime verification is part of the product, not an afterthought:

- `OSLog` categories exist for `app`, `playback`, and `export`.
- High-value playback, clip, export, and diagnostics events are appended to a JSONL trace file.
- The running app shows the trace file path and the most recent events in a dedicated `Runtime Trace` panel.
- The trace store also keeps an in-memory ring buffer for immediate UI visibility.

Default trace log location:

- `FileManager.default.temporaryDirectory.appendingPathComponent("clipper-runtime-trace.jsonl")`

## Project layout

```text
Clipper/                App entry point
ClipperKit/             Framework with editor, playback, export, support, and UI code
ClipperTests/           Unit tests for pure logic and protocol-driven services
ClipperUITests/         macOS UI tests using a fixture launch mode
project.yml             XcodeGen project definition
Clipper.xcodeproj/      Generated Xcode project
docs/                   Architecture and verification reference docs
```

## Build and run

Prerequisites:

- macOS 14+
- Xcode 15+
- `xcodegen`
- `ffmpeg` installed at `/opt/homebrew/bin/ffmpeg` or `/usr/local/bin/ffmpeg`

Generate the Xcode project:

```sh
xcodegen generate
```

Run the full automated suite:

```sh
xcodebuild \
  -project Clipper.xcodeproj \
  -scheme Clipper \
  -destination 'platform=macOS' \
  -derivedDataPath .deriveddata \
  test
```

Open the project in Xcode if you want to drive the app interactively:

```sh
open Clipper.xcodeproj
```

## Verification philosophy

This project is being built with robust TDD and runtime verification in mind:

- Core editing behavior lives in a reducer that is cheap to unit test.
- Side effects are isolated behind protocols so command generation and export orchestration can be tested without launching `ffmpeg`.
- UI tests cover critical interaction flows through a deterministic launch fixture instead of depending on real media files.
- Runtime tracing captures enough operational detail to investigate failures outside the debugger.

The deeper verification plan and current suite inventory are documented in [`docs/testing-and-observability.md`](docs/testing-and-observability.md).

## Known limits

- Only a single source asset is editable at a time.
- There is no persisted project/session format yet.
- The open panel still uses post-selection validation instead of filtering unsupported files before selection.
- Export success is based on `ffmpeg` process completion; post-export validation with `ffprobe` is not implemented yet.
- There is no clip rename, reorder, or batch preset-per-clip support.
