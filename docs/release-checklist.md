# Release Checklist

This checklist is for shipping a signed and notarized `Clipper` build outside the Mac App Store.

## Preconditions

- Xcode command-line tools are working on the release machine
- `xcodegen` is installed
- `ffmpeg` is installed on the release machine for bundling
- a `Developer ID Application` certificate for team `U8A4E46MT9` is installed in the login keychain
- a notarization keychain profile exists for `notarytool`

## Release build command

```sh
CLIPPER_CODESIGN_IDENTITY="Developer ID Application: Peter Peirce (U8A4E46MT9)" \
CLIPPER_NOTARY_PROFILE="Clipper" \
./scripts/package-release.sh
```

Expected result:

- `dist/Clipper.app`
- `dist/Clipper-macOS.zip`
- script summary ends with `Signing: Developer ID with notarization.`

## Required validation

Run the automated suite:

```sh
xcodebuild \
  -project Clipper.xcodeproj \
  -scheme Clipper \
  -destination 'platform=macOS' \
  -derivedDataPath .deriveddata \
  test
```

Verify the packaged app bundle:

```sh
codesign --verify --deep --strict dist/Clipper.app
codesign -dv --verbose=4 dist/Clipper.app
```

Expected signals:

- `TeamIdentifier=U8A4E46MT9`
- `flags=0x10000(runtime)`
- `Notarization Ticket=stapled`

Verify the embedded `ffmpeg` linkage:

```sh
otool -L dist/Clipper.app/Contents/Helpers/ffmpeg
find dist/Clipper.app/Contents/Frameworks -maxdepth 1 -name '*.dylib' -print0 \
  | xargs -0 otool -L
```

Expected result:

- no `/opt/homebrew` references
- no `/usr/local` references

## Smoke test

Open the packaged app and confirm:

- the app launches outside Xcode
- a local source video opens successfully
- playback, clip marking, and export still work
- exported clips succeed without a system-installed `ffmpeg`

## Release payload

Share:

- `dist/Clipper-macOS.zip`

Keep for records:

- notarized `dist/Clipper.app`
- release notes in `CHANGELOG.md`
