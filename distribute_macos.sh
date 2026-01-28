#!/bin/bash
set -euo pipefail

require_env() {
    local name="$1"
    if [ -z "${!name:-}" ]; then
        echo "❌ Missing required env var: $name"
        exit 1
    fi
}

# Load configuration from .env.distribute if it exists
if [ -f .env.distribute ]; then
    set -a
    # shellcheck disable=SC1091
    source .env.distribute
    set +a
fi

require_env DEVELOPER_ID_APPLICATION_SIGNER

# Configuration
APP_NAME="ShakePin"
SCHEME="Runner"
WORKSPACE="macos/Runner.xcworkspace"
ARCHIVE_PATH="build/macos/Runner.xcarchive"
EXPORT_PATH="build/macos/Export"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
FLUTTER_APP_PATH="build/macos/Build/Products/Release/$APP_NAME.app"
DMG_PATH="dist/notarized/$APP_NAME.dmg"

# Warning for VPN
echo "⚠️  Note: If you encounter 'A timestamp was expected but was not found', please disable your VPN and try again."
echo "🚀 Starting distribution process for $APP_NAME..."

# Check if archive exists (prefer xcodebuild approach)
if [ -d "$ARCHIVE_PATH" ]; then
    echo "📦 Found existing archive, exporting app..."
    rm -rf "$EXPORT_PATH"
    xcodebuild -exportArchive \
      -archivePath "$ARCHIVE_PATH" \
      -exportPath "$EXPORT_PATH" \
      -exportOptionsPlist macos/exportOptions.plist

    if [ ! -d "$APP_PATH" ]; then
        echo "❌ Export failed. App not found at $APP_PATH"
        exit 1
    fi
elif [ -d "$FLUTTER_APP_PATH" ]; then
    echo "📦 Found Flutter build, signing app manually..."
    APP_PATH="$FLUTTER_APP_PATH"

    # Code Sign
    echo "🧹 Cleaning extended attributes..."
    xattr -cr "$APP_PATH"

    echo "✍️  Signing app with Hardened Runtime..."
    codesign --deep --force --options runtime --sign "$DEVELOPER_ID_APPLICATION_SIGNER" --entitlements macos/Runner/Release.entitlements "$APP_PATH"

    echo "🔎 Verifying code signature..."
    codesign --verify --deep --strict --verbose=2 "$APP_PATH"
else
    echo "❌ No build found."
    echo "Please either:"
    echo "  1. Run 'flutter build macos --release' to build the app"
    echo "  2. Use build_and_distribute.sh which handles everything"
    exit 1
fi

echo "🔎 Verifying code signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

# Prepare dist directory and copy app
echo "📁 Preparing distribution directory..."
mkdir -p dist/notarized
rm -rf "dist/notarized/$APP_NAME.app"
cp -R "$APP_PATH" dist/notarized/

# Create DMG with appdmg (same pattern as notarman.sh)
echo "💿 Creating styled DMG with appdmg..."
rm -rf "$DMG_PATH"
cd dist/notarized
ditto ../../macos/packaging/dmg/appdmg.json config.json
appdmg config.json "$APP_NAME.dmg"
cd ../..

# Notarize using keychain profile (same pattern as notarman.sh)
echo "☁️  Submitting DMG for notarization..."
xcrun notarytool submit "$DMG_PATH" --keychain-profile "notarytool-password" --wait

# Staple notary ticket to DMG
echo "📎 Stapling notary ticket to DMG..."
xcrun stapler staple "$DMG_PATH"

# Validate with Gatekeeper (same flags as notarman.sh)
echo "🔎 Gatekeeper assessment..."
spctl -a -vvv -t install "$DMG_PATH"

echo "✅ Done! Your app is signed, notarized, and packaged as a styled DMG."
echo "Location: $DMG_PATH"

# Open the dist directory (same pattern as notarman.sh)
open ./dist/notarized
