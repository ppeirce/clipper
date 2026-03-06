# Architecture

## Design goals

The project is structured around a simple rule: keep business logic deterministic and keep system integration replaceable.

That leads to four main constraints:

- Editing logic should be testable without AVFoundation or SwiftUI.
- Playback and export side effects should sit behind protocols.
- Runtime behavior should leave an inspectable trace when something goes wrong.
- The app target should stay thin and delegate most work to a reusable framework target.

## Target map

### `Clipper`

- Application target.
- Hosts `ClipperApp` and the main window.
- Depends on `ClipperKit`.

### `ClipperKit`

- Framework target containing almost all product logic.
- Owns editor state, reducer behavior, playback adapters, export services, tracing, and SwiftUI presentation.

### `ClipperTests`

- Unit test bundle.
- Exercises reducer rules, keyboard mapping, timeline projection, command generation, exporter orchestration, editor workflows, and trace store behavior.

### `ClipperUITests`

- UI test bundle.
- Launches the app in a deterministic fixture mode to verify user-visible editing flows.

## Source map

### `ClipperKit/App`

- `ClipperViewModel.swift`: main orchestration layer.
- `AppLaunchOptions.swift`: launch argument parsing and fixture-mode bootstrapping.

### `ClipperKit/Editor`

- `EditorState.swift`: editor data model, clip-definition history, actions, and reducer effects.
- `EditorReducer.swift`: clip creation, transport, selection, editing, and error rules.
- `ClipSegment.swift`: clip identity, normalization, and duration.
- `TimelineProjector.swift`: timeline math for ribbon rendering.

### `ClipperKit/Playback`

- `AVPlayerPlaybackController.swift`: live AVFoundation-backed playback adapter.

### `ClipperKit/Export`

- `ExportPreset.swift`: user-facing export presets and ffmpeg argument bundles.
- `ClipExportPlanner.swift`: output planning and filename collision handling.
- `FFmpegCommandBuilder.swift`: deterministic command construction.
- `FFmpegClipExporter.swift`: process orchestration and export tracing.

### `ClipperKit/Support`

- `RuntimeTraceStore.swift`: actor-backed trace recorder with JSONL persistence.
- `KeyboardShortcutInterpreter.swift`: key-to-command mapping.
- `TimecodeFormatter.swift`: display and ffmpeg timestamp formatting.
- `CMTime+Helpers.swift`: normalization and comparison helpers.
- `AppLogger.swift`: centralized OSLog categories.

### `ClipperKit/UI`

- `ContentView.swift`: main layout and operator controls.
- `PlayerSurfaceView.swift`: AVPlayer hosting surface and file drop target.
- `RibbonView.swift`: playback position and clip visualization.
- `KeyboardCaptureView.swift`: key event capture for keyboard-first editing.

## State flow

The core data path is:

1. `ClipperViewModel` receives a user intent.
2. The view model translates that intent into an `EditorAction`.
3. `EditorReducer` mutates `EditorState` and returns any playback side effects.
4. The view model executes side effects through `PlaybackControlling`.
5. The view model refreshes status text and records trace events.

This split matters because the reducer owns correctness, while the view model owns integration.

## Playback flow

1. The user opens a file.
   This can come from the toolbar, the File menu, the recent-file submenu, or a drag-and-drop action on the player.
2. `PlaybackControlling.loadVideo` resolves a `VideoAssetContext`.
3. The reducer resets state with the new asset.
4. Live playback snapshots flow back through `PlaybackSnapshot`.
5. The reducer keeps `currentTime`, `duration`, and `isPlaying` synchronized with the player.

The live adapter is `AVPlayerPlaybackController`. Recent-file bookkeeping is isolated behind `RecentDocumentManaging`. Tests can swap in `FixturePlaybackController` and recent-document spies.

## Clip creation and editing flow

### Creating a clip

1. `I` stores `pendingInPoint`.
2. Transport moves the playhead.
3. `O` attempts to create a normalized `ClipSegment`.
4. The reducer rejects invalid or overlapping ranges.
5. A successful clip is inserted, sorted, selected, and traced.

### Editing a selected clip

1. The user selects a chip in the ribbon scroller.
2. The playhead is moved to the desired boundary.
3. `Set Start To Playhead` or `Set End To Playhead` rewrites that boundary.
4. The reducer normalizes the candidate clip and re-checks overlap constraints.
5. Success or rejection is surfaced in both status text and runtime traces.

### Undo and redo

1. Clip-definition mutations push a `ClipDefinitionSnapshot` into reducer-owned undo history.
2. Non-editing actions like playback seeks and transport updates do not enter that history.
3. `Undo` and `Redo` in the Edit menu replay only clip-definition state: pending in-point, saved clips, and clip selection.
4. Loading a new video resets the clip-definition history with the rest of the editor state.

## Export flow

1. The user chooses an export preset.
2. The user starts export and selects an output directory.
3. `ClipExportPlanner` derives stable output filenames.
4. `FFmpegCommandBuilder` constructs one command per clip.
5. `FFmpegClipExporter` runs commands serially through `ProcessRunning`.
6. Export progress and failures are traced.

`ffmpeg` resolution order is explicit:

- `CLIPPER_FFMPEG_BIN` override
- bundled `Clipper.app/Contents/Helpers/ffmpeg`
- `/opt/homebrew/bin/ffmpeg`
- `/usr/local/bin/ffmpeg`

The exporter does not currently parallelize jobs. That is deliberate for the first iteration:

- serial execution keeps trace ordering obvious
- failure propagation is simpler
- output naming behavior is easier to reason about

## Fixture mode for UI tests

The app supports a deterministic launch path through the `--ui-test-fixture` argument.

Fixture mode injects:

- a fake source asset at `/tmp/fixture.mov`
- a fixed duration and frame rate
- two prebuilt clips
- a fixture playback controller
- a fixture exporter that returns predictable output filenames

This lets UI tests verify editing behavior without depending on real media files or a live `ffmpeg` binary.

## Concurrency boundaries

- `ClipperViewModel` is `@MainActor` because it coordinates UI state.
- `RuntimeTraceStore` is an `actor` so trace writes are serialized.
- Export process execution is async and protocol-driven.
- The codebase is already shaped around Swift 6 sendability rules.

## Why this structure

This is not an abstraction-heavy design for its own sake.

It exists to make the expensive parts of the app replaceable:

- AVFoundation can be substituted in tests.
- `ffmpeg` execution can be simulated.
- UI tests can launch a fixture without real assets.
- diagnostics remain available when the UI and live processes disagree.
