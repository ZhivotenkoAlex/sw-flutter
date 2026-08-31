#!/bin/bash

# Run Flutter app with flavor (auto-uninstalls conflicting packages)
# Usage: ./run_flavor.sh <flavor> <platform> [mode]
# Example: ./run_flavor.sh galeriaKazimierzNew android debug

set -e

FLAVOR=$1
PLATFORM=$2
MODE=${3:-debug}

# Package IDs for all flavors
ALL_PACKAGES="pl.a2ti.galeriakazimierz com.skanujwygrywaj.skanuj_wygrywaj pl.a2ti.mojagaleria com.polbau.polbau com.polbau.polbau_demo"

if [ -z "$FLAVOR" ] || [ -z "$PLATFORM" ]; then
    echo "Usage: $0 <flavor> <platform> [mode]"
    echo ""
    echo "Flavors:"
    echo "  - galeriaKazimierz"
    echo "  - galeriaKazimierzNew"
    echo "  - polbauDemo"
    echo ""
    echo "Platforms:"
    echo "  - android"
    echo "  - ios"
    echo ""
    echo "Modes (optional, default: debug):"
    echo "  - debug"
    echo "  - release"
    echo "  - profile"
    echo ""
    echo "Example: $0 galeriaKazimierzNew android debug"
    exit 1
fi

# Validate flavor
if [[ "$FLAVOR" != "galeriaKazimierz" ]] && [[ "$FLAVOR" != "galeriaKazimierzNew" ]] && [[ "$FLAVOR" != "polbauDemo" ]]; then
    echo "❌ Invalid flavor: $FLAVOR"
    echo "Valid flavors: galeriaKazimierz, galeriaKazimierzNew, polbauDemo"
    exit 1
fi

# Validate platform
if [[ "$PLATFORM" != "android" ]] && [[ "$PLATFORM" != "ios" ]]; then
    echo "❌ Invalid platform: $PLATFORM"
    echo "Valid platforms: android, ios"
    exit 1
fi

# Clean up existing installations (Android only)
if [[ "$PLATFORM" == "android" ]]; then
    echo "🧹 Cleaning up existing flavor installations..."
    
    # Check if device is connected
    if ! adb devices | grep -q "device$"; then
        echo "⚠️  Warning: No Android device found. Skipping cleanup."
    else
        # Uninstall ALL flavor packages
        for pkg in $ALL_PACKAGES; do
            echo "  Checking $pkg..."
            if adb shell pm list packages | grep -q "^package:$pkg$"; then
                echo "  ❌ Uninstalling $pkg..."
                adb uninstall "$pkg" || echo "  ⚠️  Failed to uninstall $pkg (might be okay)"
            else
                echo "  ✓ $pkg not installed"
            fi
        done
    fi
    
    echo "✅ Cleanup complete!"
    echo ""
fi

echo "🚀 Running $FLAVOR for $PLATFORM in $MODE mode..."
echo ""

# Copy flavor-specific Firebase iOS config before build
if [[ "$PLATFORM" == "ios" ]]; then
    PLIST_SRC="ios/Runner/${FLAVOR}/GoogleService-Info.plist"
    PLIST_DST="ios/Runner/GoogleService-Info.plist"
    if [ -f "$PLIST_SRC" ]; then
        cp "$PLIST_SRC" "$PLIST_DST"
        echo "✓ Copied Firebase config: $PLIST_SRC"
    else
        echo "⚠️  Warning: $PLIST_SRC not found, using existing GoogleService-Info.plist"
    fi
    echo ""
fi

# Run the app
flutter run \
    --flavor "$FLAVOR" \
    --dart-define=FLAVOR="$FLAVOR" \
    ${MODE:+--$MODE}

echo ""
echo "✅ Done!"