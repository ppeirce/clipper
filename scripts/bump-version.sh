#!/bin/zsh

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
PROJECT_YML="$REPO_ROOT/project.yml"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"

usage() {
    printf 'Usage: %s <version>\n' "$(basename -- "$0")"
    printf 'Example: %s 1.1.0\n' "$(basename -- "$0")"
    exit 1
}

[[ $# -eq 1 ]] || usage

NEW_VERSION="$1"

if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'error: version must be semver (e.g. 1.2.3)\n' >&2
    exit 1
fi

CURRENT_VERSION="$(grep 'MARKETING_VERSION:' "$PROJECT_YML" | awk '{print $2}')"

if [[ "$CURRENT_VERSION" == "$NEW_VERSION" ]]; then
    printf 'error: version is already %s\n' "$NEW_VERSION" >&2
    exit 1
fi

log() {
    printf '==> %s\n' "$1"
}

log "Bumping version: $CURRENT_VERSION -> $NEW_VERSION"

# Update project.yml
sed -i '' "s/MARKETING_VERSION: $CURRENT_VERSION/MARKETING_VERSION: $NEW_VERSION/" "$PROJECT_YML"

# Increment build number
CURRENT_BUILD="$(grep 'CURRENT_PROJECT_VERSION:' "$PROJECT_YML" | awk '{print $2}')"
NEW_BUILD=$((CURRENT_BUILD + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION: $CURRENT_BUILD/CURRENT_PROJECT_VERSION: $NEW_BUILD/" "$PROJECT_YML"

# Add new section to CHANGELOG
TODAY="$(date +%Y-%m-%d)"
sed -i '' "s/^# Changelog$/# Changelog\n\n## $NEW_VERSION - $TODAY\n/" "$CHANGELOG"

# Regenerate Xcode project
log "Regenerating Xcode project"
(cd "$REPO_ROOT" && xcodegen generate)

log "Done. Updated:"
printf '  project.yml:  MARKETING_VERSION=%s  CURRENT_PROJECT_VERSION=%s\n' "$NEW_VERSION" "$NEW_BUILD"
printf '  CHANGELOG.md: added %s section\n' "$NEW_VERSION"
printf '  Clipper.xcodeproj: regenerated\n'
printf '\nNext steps:\n'
printf '  1. Add release notes to the %s section in CHANGELOG.md\n' "$NEW_VERSION"
printf '  2. Commit: git commit -am "Bump version to %s"\n' "$NEW_VERSION"
printf '  3. Tag:    git tag -a v%s -m "v%s"\n' "$NEW_VERSION" "$NEW_VERSION"
printf '  4. Push:   git push origin main v%s\n' "$NEW_VERSION"
