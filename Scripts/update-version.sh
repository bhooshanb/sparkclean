#!/bin/bash
# Updates CFBundleVersion and CFBundleShortVersionString automatically with every build.
# Usage: ./Scripts/update-version.sh [PATH_TO_PLIST]
set -euo pipefail

cd "$(dirname "$0")/.."

PLIST="${1:-Resources/Info.plist}"

if [[ ! -f "$PLIST" ]]; then
    echo "error: plist not found at $PLIST" >&2
    exit 1
fi

# 1. Marketing version (CFBundleShortVersionString)
# Priority:
#   a) $VERSION environment variable
#   b) Latest git tag (stripped of leading 'v')
#   c) Existing CFBundleShortVersionString in plist
SHORT_VER="${VERSION:-}"
if [[ -z "$SHORT_VER" ]] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    TAG_VER="$(git describe --tags --abbrev=0 2>/dev/null || true)"
    TAG_VER="${TAG_VER#v}"
    if [[ "$TAG_VER" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
        SHORT_VER="$TAG_VER"
    fi
fi
if [[ -z "$SHORT_VER" ]]; then
    SHORT_VER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" 2>/dev/null || echo "1.0.0")"
fi
if [[ ! "$SHORT_VER" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    SHORT_VER="1.0.0"
fi

# 2. Build version (CFBundleVersion)
# Monotonically increasing integer required by Sparkle and macOS.
# Priority:
#   a) $BUILD_NUMBER environment variable
#   b) Auto-increment: max(git commit count, existing build number) + 1 on rebuilds
CURRENT_BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST" 2>/dev/null || echo "0")"
if [[ ! "$CURRENT_BUILD" =~ ^[0-9]+$ ]]; then
    CURRENT_BUILD="0"
fi

GIT_COMMITS="0"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    GIT_COMMITS="$(git rev-list --count HEAD 2>/dev/null || echo "0")"
fi

if [[ -n "${BUILD_NUMBER:-}" && "${BUILD_NUMBER}" =~ ^[0-9]+$ ]]; then
    NEW_BUILD="$BUILD_NUMBER"
else
    if (( GIT_COMMITS > CURRENT_BUILD )); then
        NEW_BUILD="$GIT_COMMITS"
    else
        NEW_BUILD=$((CURRENT_BUILD + 1))
    fi
fi

# Stamp the plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $SHORT_VER" "$PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $SHORT_VER" "$PLIST"

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $NEW_BUILD" "$PLIST"

echo "==> Version: $SHORT_VER (build $NEW_BUILD) in $PLIST"
