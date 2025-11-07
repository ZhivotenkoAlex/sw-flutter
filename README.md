# Skanuj Wygrywaj - Multi-Company Flutter Application

A unified Flutter application supporting multiple companies through build flavors, featuring dynamic configuration, Firebase integration, and WebView-based content delivery.

## Overview

This application serves multiple companies from a single codebase using Flutter's build flavor system. Each company gets a unique app identity with separate Firebase projects, custom branding, and independent app store listings.

### Key Features

- **Multi-Company Support** - Deploy separate branded apps for different companies
- **Dynamic Configuration** - Runtime configuration via API with intelligent caching
- **Dual Mode Operation** - Support for both legacy and new application versions
- **Firebase Integration** - Automatic project selection based on company and mode
- **WebView Architecture** - Flexible content delivery with native bridge support
- **Cross-Platform** - Full support for Android and iOS

## Quick Start

### Prerequisites

- Flutter SDK 3.x or higher
- Android Studio / Xcode
- Firebase projects configured
- Company-specific configuration API endpoint

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd skanuj-wygrywaj-flutter

# Install dependencies
flutter pub get

# Run for specific company
flutter run --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz
```

### Available Companies (Flavors)

| Company | Flavor Name | Package ID | Type |
|---------|-------------|------------|------|
| Galeria Kazimierz | `galeriaKazimierz` | `pl.a2ti.galeriakazimierz` (Android)<br>`it.2take.galeriakazimierz` (iOS) | Legacy |
| Kazimierz Club | `kazimierzClub` | `pl.a2ti.kazimierzclub` | Legacy |
| Skanuj Wygrywaj | `skanujNew` | `com.skanujwygrywaj.skanuj_wygrywaj` (Android)<br>`com.skanujwygrywaj.skanujWygrywaj` (iOS) | New |

## Building for Production

### Android

```bash
# Build APK
flutter build apk --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz

# Build App Bundle (for Play Store)
flutter build appbundle --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz
```

### iOS

```bash
# Build iOS app
flutter build ios --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz

# Then create archive in Xcode for App Store submission
```

### Build Script

For convenience, use the included build script:

```bash
# Make executable (first time only)
chmod +x build_flavor.sh

# Build release
./build_flavor.sh galeriaKazimierz android release
./build_flavor.sh skanujNew ios release
```

## Project Architecture

### Configuration System

The app uses a three-tier configuration approach:

1. **Flavor Configuration** (`lib/flavor_config.dart`)
   - Compile-time company identification
   - Default URLs and Firebase projects
   - Bundle ID management

2. **Dynamic Configuration** (`lib/config_service.dart`)
   - Runtime API-based configuration
   - 1-hour intelligent caching
   - Offline fallback support

3. **Firebase Configuration** (`lib/firebase_config_loader.dart`)
   - Dynamic Firebase project selection
   - Platform-specific credential loading
   - Secure bundled configurations

### Application Flow

```
App Launch
    ↓
Flavor Detection (--dart-define)
    ↓
Configuration Fetch (API + Cache)
    ↓
Firebase Initialization (Correct Project)
    ↓
WebView Load (Company-Specific URL)
    ↓
Runtime Operation (Native Bridges Active)
```

### Directory Structure

```
lib/
├── main.dart                      # Application entry point
├── flavor_config.dart             # Flavor definitions and detection
├── config_service.dart            # Dynamic configuration management
├── company_mapping.dart           # Package ID to company ID mapping
├── firebase_config_loader.dart    # Dynamic Firebase initialization
├── firebase_messaging_service.dart # Push notification handling
├── webview_screen_mobile.dart     # Mobile WebView implementation
├── webview_screen_web.dart        # Web platform implementation
└── app_config.dart                # Configuration data model

android/app/src/
├── galeriaKazimierz/              # Firebase config for Galeria Kazimierz
├── kazimierzClub/                 # Firebase config for Kazimierz Club
└── skanujNew/                     # Firebase config for Skanuj New

ios/
├── galeriaKazimierz/              # iOS Firebase configs
├── kazimierzClub/                 # iOS Firebase configs
├── skanujNew/                     # iOS Firebase configs
└── Flutter/                       # xcconfig files for bundle IDs
```

## Documentation

- **[FLAVORS.md](FLAVORS.md)** - Complete flavor system guide
- **[ios/IOS_FLAVOR_SETUP.md](ios/IOS_FLAVOR_SETUP.md)** - iOS configuration guide
- **[build_flavor.sh](build_flavor.sh)** - Build automation script

## Quick Commands

```bash
# Run specific flavor
flutter run --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz

# Build release APK
./build_flavor.sh galeriaKazimierz android release

# Build all flavors
for flavor in galeriaKazimierz kazimierzClub skanujNew; do
  ./build_flavor.sh $flavor android release
done
```

## Troubleshooting

### Common Issues

**"No flavor specified"**
- Always include `--dart-define=FLAVOR=flavorName` with `--flavor`

**"Firebase initialization failed"**
- Verify `google-services.json` exists in `android/app/src/{flavor}/`
- Check package ID matches between build config and Firebase

**"Wrong URL loads"**
- Check flavor configuration in `lib/flavor_config.dart`
- Verify API response if using real endpoint

See [FLAVORS.md](FLAVORS.md) for comprehensive troubleshooting.

## iOS Setup

iOS flavors require one-time Xcode configuration. See `ios/IOS_FLAVOR_SETUP.md` for complete instructions.

## Adding New Companies

See [FLAVORS.md](FLAVORS.md) for step-by-step guide on adding new companies/flavors.

## Support

For issues or questions:
1. Check [FLAVORS.md](FLAVORS.md) troubleshooting section
2. Review flavor configuration files
3. Verify Firebase configs match package IDs
4. Test with verbose logging enabled

---

**Built with Flutter** 💙 | **Multi-Company Architecture** 🏢 | **Production Ready** ✅
