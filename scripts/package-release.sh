#!/bin/zsh

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
APP_NAME="Clipper"
PROJECT_PATH="$REPO_ROOT/Clipper.xcodeproj"
DERIVED_DATA_PATH="${CLIPPER_DERIVED_DATA_PATH:-$REPO_ROOT/.deriveddata-release}"
DIST_DIR="${CLIPPER_DIST_DIR:-$REPO_ROOT/dist}"
BUILT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/$APP_NAME.app"
PACKAGED_APP_PATH="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$APP_NAME-macOS.zip"
HELPERS_DIR="$PACKAGED_APP_PATH/Contents/Helpers"
FRAMEWORKS_DIR="$PACKAGED_APP_PATH/Contents/Frameworks"
FFMPEG_SOURCE="${CLIPPER_FFMPEG_BIN:-}"
TEAM_ID="${CLIPPER_TEAM_ID:-U8A4E46MT9}"
SIGNING_IDENTITY="${CLIPPER_CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${CLIPPER_NOTARY_PROFILE:-}"

typeset -A COPIED_DEPENDENCIES

log() {
    printf '==> %s\n' "$1"
}

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

run_install_name_tool() {
    local stderr_file

    stderr_file="$(mktemp)"
    if ! install_name_tool "$@" 2>"$stderr_file"; then
        cat "$stderr_file" >&2
        rm -f "$stderr_file"
        return 1
    fi

    rg -v 'warning: changes being made to the file will invalidate the code signature in:' "$stderr_file" >&2 || true
    rm -f "$stderr_file"
}

resolve_ffmpeg_source() {
    if [[ -z "$FFMPEG_SOURCE" ]]; then
        FFMPEG_SOURCE="$(command -v ffmpeg || true)"
    fi

    [[ -n "$FFMPEG_SOURCE" ]] || fail "ffmpeg was not found. Set CLIPPER_FFMPEG_BIN or install ffmpeg first."
    [[ -x "$FFMPEG_SOURCE" ]] || fail "ffmpeg is not executable at $FFMPEG_SOURCE"
}

resolve_signing_identity() {
    local discovered_identity

    if [[ -n "$SIGNING_IDENTITY" ]]; then
        return 0
    fi

    discovered_identity="$(
        security find-identity -v -p codesigning 2>/dev/null \
            | sed -n "s/.*\"\\(Developer ID Application: .* (${TEAM_ID})\\)\"/\\1/p" \
            | head -n 1
    )"

    if [[ -n "$discovered_identity" ]]; then
        SIGNING_IDENTITY="$discovered_identity"
    else
        SIGNING_IDENTITY="-"
    fi
}

build_release_app() {
    log "Building Release app"
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$APP_NAME" \
        -configuration Release \
        -destination 'platform=macOS' \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY=- \
        CODE_SIGNING_ALLOWED=YES \
        CODE_SIGNING_REQUIRED=NO \
        build

    [[ -d "$BUILT_APP_PATH" ]] || fail "expected Release app at $BUILT_APP_PATH"
}

prepare_distribution_bundle() {
    log "Preparing distribution bundle"
    rm -rf "$PACKAGED_APP_PATH" "$ZIP_PATH"
    mkdir -p "$DIST_DIR"
    ditto "$BUILT_APP_PATH" "$PACKAGED_APP_PATH"
    mkdir -p "$HELPERS_DIR" "$FRAMEWORKS_DIR"
}

dependency_paths() {
    local binary_path="$1"
    otool -L "$binary_path" | tail -n +2 | awk '{print $1}'
}

is_external_dependency() {
    local dependency_path="$1"
    [[ "$dependency_path" == /opt/homebrew/* || "$dependency_path" == /usr/local/* ]]
}

canonical_path() {
    local input_path="$1"
    local directory_path

    directory_path="$(cd -- "$(dirname -- "$input_path")" && pwd -P)"
    printf '%s/%s\n' "$directory_path" "$(basename -- "$input_path")"
}

copy_dependency_tree() {
    local dependency_path="$1"
    local real_path dependency_name destination_path nested_dependency

    is_external_dependency "$dependency_path" || return 0

    real_path="$(canonical_path "$dependency_path")"
    [[ -e "$real_path" ]] || fail "missing dependency $real_path"

    if [[ -n "${COPIED_DEPENDENCIES[$real_path]:-}" ]]; then
        return 0
    fi

    dependency_name="$(basename -- "$real_path")"
    destination_path="$FRAMEWORKS_DIR/$dependency_name"

    cp -fL "$real_path" "$destination_path"
    chmod 755 "$destination_path"
    COPIED_DEPENDENCIES[$real_path]="$destination_path"

    while IFS= read -r nested_dependency; do
        copy_dependency_tree "$nested_dependency"
    done < <(dependency_paths "$real_path")
}

embed_ffmpeg() {
    local dependency_path

    log "Embedding ffmpeg"
    cp -fL "$FFMPEG_SOURCE" "$HELPERS_DIR/ffmpeg"
    chmod 755 "$HELPERS_DIR/ffmpeg"

    while IFS= read -r dependency_path; do
        copy_dependency_tree "$dependency_path"
    done < <(dependency_paths "$FFMPEG_SOURCE")
}

rewrite_framework_links() {
    local framework_path dependency_path dependency_name

    log "Rewriting embedded library paths"
    for framework_path in "$FRAMEWORKS_DIR"/*.dylib(N); do
        chmod u+w "$framework_path"
        run_install_name_tool -id "@rpath/$(basename -- "$framework_path")" "$framework_path"

        while IFS= read -r dependency_path; do
            is_external_dependency "$dependency_path" || continue
            dependency_name="$(basename -- "$(canonical_path "$dependency_path")")"
            run_install_name_tool -change "$dependency_path" "@loader_path/$dependency_name" "$framework_path"
        done < <(dependency_paths "$framework_path")
    done
}

rewrite_helper_links() {
    local dependency_path dependency_name helper_path

    helper_path="$HELPERS_DIR/ffmpeg"
    chmod u+w "$helper_path"

    while IFS= read -r dependency_path; do
        is_external_dependency "$dependency_path" || continue
        dependency_name="$(basename -- "$(canonical_path "$dependency_path")")"
        run_install_name_tool -change "$dependency_path" "@loader_path/../Frameworks/$dependency_name" "$helper_path"
    done < <(dependency_paths "$helper_path")
}

codesign_bundle() {
    local framework_path
    local -a codesign_args

    log "Codesigning distribution bundle"
    codesign_args=(--force --sign "$SIGNING_IDENTITY")

    if [[ "$SIGNING_IDENTITY" == "-" ]]; then
        codesign_args+=(--timestamp=none)
    else
        codesign_args+=(--options runtime --timestamp)
    fi

    for framework_path in "$FRAMEWORKS_DIR"/*.dylib(N); do
        codesign "${codesign_args[@]}" "$framework_path"
    done

    for framework_path in "$PACKAGED_APP_PATH"/Contents/Frameworks/*.framework(N); do
        codesign --deep "${codesign_args[@]}" "$framework_path"
    done

    codesign "${codesign_args[@]}" "$HELPERS_DIR/ffmpeg"
    codesign "${codesign_args[@]}" "$PACKAGED_APP_PATH"
}

verify_bundle() {
    local helper_path framework_path bad_references

    log "Verifying embedded ffmpeg"
    helper_path="$HELPERS_DIR/ffmpeg"
    "$helper_path" -version >/dev/null

    bad_references="$(
        {
            dependency_paths "$helper_path"
            for framework_path in "$FRAMEWORKS_DIR"/*.dylib(N); do
                dependency_paths "$framework_path"
            done
        } | rg '^(/opt/homebrew|/usr/local)/' || true
    )"

    [[ -z "$bad_references" ]] || fail "external Homebrew references remain in the packaged bundle:\n$bad_references"
}

zip_bundle() {
    log "Creating distribution zip"
    ditto -c -k --keepParent "$PACKAGED_APP_PATH" "$ZIP_PATH"
}

notarize_bundle_if_configured() {
    [[ "$SIGNING_IDENTITY" != "-" ]] || return 0
    [[ -n "$NOTARY_PROFILE" ]] || return 0

    log "Submitting zip for notarization"
    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$PACKAGED_APP_PATH"
}

print_summary() {
    log "Packaged app"
    printf 'App: %s\n' "$PACKAGED_APP_PATH"
    printf 'Zip: %s\n' "$ZIP_PATH"

    if [[ "$SIGNING_IDENTITY" == "-" ]]; then
        printf '%s\n' "Signing: ad hoc only. Install a Developer ID certificate and set CLIPPER_CODESIGN_IDENTITY to remove Gatekeeper warnings for downloaded builds."
    elif [[ -z "$NOTARY_PROFILE" ]]; then
        printf '%s\n' "Signing: Developer ID. Set CLIPPER_NOTARY_PROFILE to notarize and staple automatically."
    else
        printf '%s\n' "Signing: Developer ID with notarization."
    fi
}

main() {
    resolve_ffmpeg_source
    resolve_signing_identity
    build_release_app
    prepare_distribution_bundle
    embed_ffmpeg
    rewrite_framework_links
    rewrite_helper_links
    codesign_bundle
    verify_bundle
    zip_bundle
    notarize_bundle_if_configured
    print_summary
}

main "$@"
