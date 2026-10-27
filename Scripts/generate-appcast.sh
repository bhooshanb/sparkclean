#!/bin/bash
# Generates release zip and signed appcast.xml using Sparkle's generate_appcast.
# Usage: ./Scripts/generate-appcast.sh [--universal]
set -euo pipefail

cd "$(dirname "$0")/.."

SHORT_VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist 2>/dev/null || echo "1.0.0")"
BUILD_VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist 2>/dev/null || echo "1")"
TAG="v${SHORT_VER}"

echo "==> Packaging SparkClean $SHORT_VER (build $BUILD_VER)"

DIST_DIR="build/dist"
mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR"/* 2>/dev/null || true

# Ensure app is built
if [[ ! -d "build/SparkClean.app" ]]; then
    ./Scripts/build-app.sh "${1:-}"
fi

ZIP_PATH="$DIST_DIR/SparkClean.zip"
echo "==> Creating $ZIP_PATH"
ditto -c -k --keepParent build/SparkClean.app "$ZIP_PATH"

# Locate Sparkle generate_appcast binary
GEN_APPCAST=".build/artifacts/sparkle/Sparkle/bin/generate_appcast"
if [[ ! -x "$GEN_APPCAST" ]]; then
    echo "error: generate_appcast binary not found at $GEN_APPCAST" >&2
    exit 1
fi

KEY_ARG=()
if [[ -f "sparkle_priv.key" ]]; then
    KEY_ARG=(--ed-key-file "sparkle_priv.key")
fi

DOWNLOAD_PREFIX="https://github.com/bhooshanb/sparkclean/releases/download/${TAG}/"

echo "==> Generating appcast for $DOWNLOAD_PREFIX"
"$GEN_APPCAST" "${KEY_ARG[@]}" --download-url-prefix "$DOWNLOAD_PREFIX" "$DIST_DIR"

# Copy generated appcast to repo root so it can be tracked in git
cp "$DIST_DIR/appcast.xml" "./appcast.xml"

echo "==> appcast.xml generated and updated at ./appcast.xml"
