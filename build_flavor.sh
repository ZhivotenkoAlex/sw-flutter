#!/bin/bash

# Build script for different flavors
# Usage: ./build_flavor.sh [flavor] [platform] [mode]
# Example: ./build_flavor.sh galeriaKazimierz android release

FLAVOR=$1
PLATFORM=$2
MODE=${3:-release}

if [ -z "$FLAVOR" ] || [ -z "$PLATFORM" ]; then
    echo "Usage: ./build_flavor.sh [flavor] [platform] [mode]"
    echo ""
    echo "Flavors:"
    echo "  galeriaKazimierz     - Galeria Kazimierz (Legacy)"
    echo "  galeriaKazimierzNew  - Galeria Kazimierz New"
    echo ""
    echo "Platforms:"
    echo "  android - Build APK/AAB"
    echo "  ios     - Build IPA"
    echo ""
    echo "Modes:"
    echo "  debug   - Debug build"
    echo "  release - Release build (default)"
    echo ""
    echo "Examples:"
    echo "  ./build_flavor.sh galeriaKazimierz android release"
    echo "  ./build_flavor.sh galeriaKazimierzNew ios debug"
    exit 1
fi

echo "🚀 Building $FLAVOR for $PLATFORM ($MODE mode)..."
echo ""

if [[ "$PLATFORM" == "ios" ]]; then
    PLIST_SRC="ios/Runner/${FLAVOR}/GoogleService-Info.plist"
    PLIST_DST="ios/Runner/GoogleService-Info.plist"
    if [ -f "$PLIST_SRC" ]; then
        cp "$PLIST_SRC" "$PLIST_DST"
        echo "✓ Copied Firebase config: $PLIST_SRC"
        echo ""
    fi
fi

# Set flavor as environment variable
export FLUTTER_FLAVOR=$FLAVOR

case $PLATFORM in
    android)
        if [ "$MODE" = "release" ]; then
            echo "📦 Building release APK..."
            flutter build apk --flavor $FLAVOR --dart-define=FLAVOR=$FLAVOR
            echo ""
            echo "✅ APK built: build/app/outputs/flutter-apk/app-$FLAVOR-release.apk"
        else
            echo "🐛 Building debug APK..."
            flutter build apk --flavor $FLAVOR --debug --dart-define=FLAVOR=$FLAVOR
            echo ""
            echo "✅ APK built: build/app/outputs/flutter-apk/app-$FLAVOR-debug.apk"
        fi
        ;;
    
    ios)
        if [ "$MODE" = "release" ]; then
            echo "📦 Building release IPA..."
            flutter build ios --flavor $FLAVOR --release --dart-define=FLAVOR=$FLAVOR
            echo ""
            echo "✅ IPA built - Create archive in Xcode for distribution"
        else
            echo "🐛 Building debug iOS..."
            flutter build ios --flavor $FLAVOR --debug --dart-define=FLAVOR=$FLAVOR
            echo ""
            echo "✅ iOS build complete"
        fi
        ;;
    
    *)
        echo "❌ Unknown platform: $PLATFORM"
        echo "   Use: android or ios"
        exit 1
        ;;
esac

echo ""
echo "🎉 Build complete!"

