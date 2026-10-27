#!/bin/bash
# Build SparkClean.app from the SwiftPM package.
# Usage: ./Scripts/build-app.sh [--universal]
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="SparkClean"
BUNDLE_ID="fun.sparkclean.app"
BUILD_DIR=".build"
APP_DIR="build/SparkClean.app"
CONTENTS="$APP_DIR/Contents"

# 0. Automatically update version and build number with every build
./Scripts/update-version.sh Resources/Info.plist

echo "==> Building $CONFIGURATION binary"
if [[ "${1:-}" == "--universal" ]]; then
    echo "    (universal: arm64 + x86_64)"
    swift build -c "$CONFIGURATION" --arch arm64 --arch x86_64
else
    swift build -c "$CONFIGURATION"
fi

BIN="$BUILD_DIR/$CONFIGURATION/SparkClean"

echo "==> Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp "$BIN" "$CONTENTS/MacOS/$APP_NAME"
cp Resources/Info.plist "$CONTENTS/Info.plist"
cp Resources/GPL-3.0.txt "$CONTENTS/Resources/GPL-3.0.txt"
cp Resources/COPYRIGHT.txt "$CONTENTS/Resources/COPYRIGHT.txt"
cp Resources/THIRD_PARTY_NOTICES.txt "$CONTENTS/Resources/THIRD_PARTY_NOTICES.txt"
cp Resources/AppIcon.icns "$CONTENTS/Resources/AppIcon.icns" 2>/dev/null || {
    echo "    (no AppIcon.icns yet — run Scripts/make-icon.sh first)"
}

# Ensure bundle Info.plist matches updated version
PLIST="$CONTENTS/Info.plist"
SHORT_VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist 2>/dev/null || echo "1.0.0")"
BUILD_VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist 2>/dev/null || echo "1")"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $SHORT_VER" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_VER" "$PLIST"
echo "==> Stamped bundle version: $SHORT_VER (build $BUILD_VER)"

# Sparkle EdDSA public key (SUPublicEDKey):
# If set in environment or already saved to Keychain, embed it into bundle Info.plist.
PUBLIC_EDKEY="${SPARKLE_PUBLIC_EDKEY:-}"
if [[ -z "$PUBLIC_EDKEY" ]]; then
    GEN_KEYS="$BUILD_DIR/artifacts/sparkle/Sparkle/bin/generate_keys"
    if [[ -x "$GEN_KEYS" ]]; then
        PUBLIC_EDKEY="$("$GEN_KEYS" -p 2>/dev/null || true)"
    fi
fi
if [[ -n "$PUBLIC_EDKEY" ]]; then
    echo "==> Stamping SUPublicEDKey into bundle Info.plist"
    /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $PUBLIC_EDKEY" "$PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $PUBLIC_EDKEY" "$PLIST"
fi

# Embed Sparkle.framework. SwiftPM stages the binary target next to the
# executable but never copies it into a bundle, and the app links it via
# @executable_path/../Frameworks rpath — without this copy it won't launch.
# ditto preserves the framework's symlinks and executable bits.
SPARKLE_FW=""
for dir in "$BUILD_DIR/apple/Products/$CONFIGURATION" \
           "$BUILD_DIR/out/Products/$CONFIGURATION" \
           "$BUILD_DIR/$CONFIGURATION"; do
    if [[ -d "$dir/Sparkle.framework" ]]; then
        SPARKLE_FW="$(cd "$dir" && pwd -P)/Sparkle.framework"
        break
    fi
done
if [[ -z "$SPARKLE_FW" ]]; then
    echo "error: Sparkle.framework not found in $BUILD_DIR products" >&2
    exit 1
fi
echo "==> Embedding Sparkle.framework"
mkdir -p "$CONTENTS/Frameworks"
ditto "$SPARKLE_FW" "$CONTENTS/Frameworks/Sparkle.framework"

if [[ "${CODE_SIGN:-1}" == "1" ]]; then
    SIGN_ID="${CODE_SIGN_IDENTITY:--}"
    echo "==> Code signing (identity: $SIGN_ID)"
    SIGN_ARGS=(--force)
    # Developer ID builds get hardened runtime + timestamp; ad-hoc doesn't
    # support either. Library validation only applies with the runtime flag,
    # so the framework must carry the same identity as the app.
    if [[ "$SIGN_ID" != "-" ]]; then
        SIGN_ARGS+=(--options runtime --timestamp)
    fi
    # Sign Sparkle inside-out first (--deep signs its nested XPC services),
    # then seal the app bundle over it.
    codesign "${SIGN_ARGS[@]}" --deep --sign "$SIGN_ID" \
        "$CONTENTS/Frameworks/Sparkle.framework"
    codesign "${SIGN_ARGS[@]}" --sign "$SIGN_ID" \
        --entitlements Resources/SparkClean.entitlements \
        "$APP_DIR" 2>/dev/null || codesign "${SIGN_ARGS[@]}" --sign "$SIGN_ID" "$APP_DIR"
fi

echo "==> Done: $APP_DIR"
[[ -d "$APP_DIR" ]] && du -sh "$APP_DIR"
