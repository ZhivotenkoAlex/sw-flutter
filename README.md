# Skanuj Wygrywaj - Multi-Flavor Flutter App

A Flutter application supporting multiple companies through build flavors, featuring dynamic Firebase configuration, secure config fetching, and WebView-based content delivery.

## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [Project Structure](#-project-structure)
- [Available Flavors](#-available-flavors)
- [Running the App](#-running-the-app)
- [Building for Production](#-building-for-production)
- [Documentation](#-documentation)
- [Troubleshooting](#-troubleshooting)

---

## 🚀 Quick Start

### Prerequisites

- **Flutter SDK**: 3.32.0 or higher
- **Dart SDK**: 3.5.0 or higher
- **Android Studio**: For Android development
- **Xcode**: For iOS development (macOS only)
- **Firebase CLI**: For updating configs (optional)
- **Node.js**: 14+ (for Firestore scripts)

### Installation

```bash
# 1. Clone the repository
git clone <repository-url>
cd skanuj-wygrywaj-flutter

# 2. Install dependencies
flutter pub get

# 3. Run the app (recommended method)
./run_flavor.sh galeriaKazimierz android
```

---

## 📁 Project Structure

```
skanuj-wygrywaj-flutter/
├── lib/                          # Dart source code
│   ├── main.dart                 # App entry point
│   ├── flavor_config.dart        # Flavor definitions
│   ├── services/
│   │   └── secure_config_service.dart  # Firebase config fetching
│   └── ...
├── android/                      # Android-specific code
│   └── app/src/
│       ├── galeriaKazimierz/    # Legacy flavor configs
│       └── galeriaKazimierzNew/ # New flavor configs
├── ios/                          # iOS-specific code
│   └── Runner/
│       ├── galeriaKazimierz/    # Legacy flavor configs
│       └── galeriaKazimierzNew/ # New flavor configs
├── scripts/                      # Utility scripts
│   ├── populate_firestore_config.js  # Populate Firestore configs
│   └── verify_firestore_data.js      # Verify Firestore data
├── FLAVORS_GUIDE.md             # Complete flavor setup guide
├── FIREBASE_CONFIG.md           # Firebase configuration guide
└── run_flavor.sh                # Development run script
```

---

## 🏢 Available Flavors

| Flavor                  | Company Name          | Package ID (Android)                 | Bundle ID (iOS)                     | Type   |
| ----------------------- | --------------------- | ------------------------------------ | ----------------------------------- | ------ |
| **galeriaKazimierz**    | Galeria Kazimierz     | `pl.a2ti.galeriakazimierz`           | `it.2take.galeriakazimierz`         | Legacy |
| **galeriaKazimierzNew** | Galeria Kazimierz New | `com.skanujwygrywaj.skanuj_wygrywaj` | `com.skanujwygrywaj.skanujWygrywaj` | New    |

---

## 🏃 Running the App

### Method 1: Using Run Script (Recommended)

The run script automatically handles package conflicts and device selection:

```bash
# Make executable (first time only)
chmod +x run_flavor.sh

# Run on Android
./run_flavor.sh galeriaKazimierz android
./run_flavor.sh galeriaKazimierzNew android debug

# Run on iOS
./run_flavor.sh galeriaKazimierz ios
./run_flavor.sh galeriaKazimierzNew ios release
```

**Features:**

- ✅ Auto-cleans conflicting packages
- ✅ Interactive device selection
- ✅ Supports debug/release/profile modes
- ✅ Works on both platforms

### Method 2: Using Flutter Commands

```bash
# Android
flutter run --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz

# iOS
flutter run --flavor galeriaKazimierzNew --dart-define=FLAVOR=galeriaKazimierzNew
```

**Important:** Always include both `--flavor` and `--dart-define=FLAVOR=` parameters!

---

## 📦 Building for Production

### Android APK/App Bundle

```bash
# Build APK (for testing)
flutter build apk --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz --release

# Build App Bundle (for Play Store)
flutter build appbundle --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz --release
```

### iOS

```bash
# Build for iOS
flutter build ios --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz --release

# Then open Xcode to archive and submit to App Store
open ios/Runner.xcworkspace
```

In Xcode:

1. Select the correct scheme (galeriaKazimierz or galeriaKazimierzNew)
2. Product → Archive
3. Distribute App → App Store Connect

---

## 📚 Documentation

| Document                                                                          | Description                                                      |
| --------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **[FLAVORS_GUIDE.md](docs/FLAVORS_GUIDE.md)**                                     | Complete guide for Android & iOS flavor setup                    |
| **[FIREBASE_CONFIG.md](docs/FIREBASE_CONFIG.md)**                                 | How to update and manage Firebase configs                        |
| **[DYNAMIC_CONFIGURATION.md](docs/DYNAMIC_CONFIGURATION.md)**                     | Dynamic app configuration via Firestore (no release)             |
| **[ANDROID_FIREBASE_PROJECT_SWITCH.md](docs/ANDROID_FIREBASE_PROJECT_SWITCH.md)** | Android: How to switch Firebase projects (flavor-specific files) |
| **[GOOGLE_SIGNIN_WEB_CLIENT_ID.md](docs/GOOGLE_SIGNIN_WEB_CLIENT_ID.md)**         | Find and verify Google Sign In Web Client ID                     |
| **[DOCUMENTATION.md](docs/DOCUMENTATION.md)**                                     | Complete documentation index and guide                           |
| **[scripts/README.md](scripts/README.md)**                                        | Firestore population scripts documentation                       |

---

## 🔧 Troubleshooting

### Common Issues

#### ❌ "INSTALL_FAILED_CONFLICTING_PROVIDER"

**Error:**

```
INSTALL_FAILED_CONFLICTING_PROVIDER: Scanning Failed.: Can't install because provider name
com.facebook.app.FacebookContentProvider683312195062841 is already used
```

**Solution:**

```bash
# Use the run script - it automatically fixes this
./run_flavor.sh galeriaKazimierz android

# OR manually uninstall conflicting packages
adb uninstall pl.a2ti.galeriakazimierz
adb uninstall com.skanujwygrywaj.skanuj_wygrywaj
```

**Why:** Both flavors share the same Facebook App ID. Only one can be installed at a time.

---

#### ❌ "No flavor specified" / "Flavor not found"

**Solution:** Always include both parameters:

```bash
flutter run --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz
#            ^^^^^^^^^^^^^^^^^^^^   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#            Required #1            Required #2
```

---

#### ❌ iOS: "The Xcode project does not define custom schemes"

**Solution:** You need to set up Xcode schemes first. See [FLAVORS_GUIDE.md](docs/FLAVORS_GUIDE.md#ios-flavor-setup) for step-by-step instructions.

---

#### ❌ "Firebase initialization failed"

**Causes:**

1. Missing `google-services.json` or `GoogleService-Info.plist`
2. Package ID mismatch
3. Wrong Firebase project

**Solution:**

1. Check files exist:
   - Android: `android/app/src/{flavor}/google-services.json`
   - iOS: `ios/Runner/{flavor}/GoogleService-Info.plist`
2. Verify package ID matches in:
   - Android: `android/app/build.gradle.kts`
   - iOS: Xcode project settings
3. See [FIREBASE_CONFIG.md](docs/FIREBASE_CONFIG.md) for details

---

#### ❌ "Infinite loading configuration"

**Solution:**

1. Check internet connection
2. Verify Firestore database has configs:
   ```bash
   node scripts/verify_firestore_data.js
   ```
3. Check logs for errors:
   ```bash
   flutter logs | grep "SecureConfig\|Firestore"
   ```

---

## 🏗️ Architecture Overview

### Dual Firebase App System

The app uses **two Firebase apps simultaneously**:

1. **DEFAULT App** (from plist/google-services.json)

   - **Purpose:** Firebase Messaging, Analytics
   - **Project:** Flavor-specific (galeria-kazimierz-827d4 or development-417611)

2. **NAMED "config" App** (created programmatically)
   - **Purpose:** Firestore config fetching only
   - **Project:** Always `development-417611`
   - **Database:** `skanuj-wygrywaj`

### Configuration Flow

```
App Start
   ↓
Detect Flavor (galeriaKazimierz or galeriaKazimierzNew)
   ↓
Initialize Bootstrap Firebase (development-417611)
   ↓
Fetch Config from Firestore (mobile_configs/{companyId})
   ↓
Check isLegacy flag → Apply Legacy or Modern theme
   ↓
Initialize Firebase Messaging (flavor-specific project)
   ↓
Load WebView with dynamic URL
```

### Dynamic Configuration

The app loads configuration from Firestore at runtime, allowing changes **without releasing a new version**:

- **`companyId`** → Company ID for API calls (can switch databases!)
- **`webviewUrl`** → URL to load in WebView
- **`isLegacy`** → UI theme (blue = legacy, purple = modern)
- **Firebase credentials** → Can be updated dynamically

**Benefits:**

- ✅ Change configuration without app release
- ✅ Switch companies/databases instantly
- ✅ Gradual rollout to users
- ✅ Instant rollback if issues occur
- ✅ A/B testing capabilities

See [DYNAMIC_CONFIGURATION.md](docs/DYNAMIC_CONFIGURATION.md) for complete guide.

---

## 🔐 Security

- ✅ No hardcoded API keys in source code
- ✅ Configs fetched securely from Firestore
- ✅ Firebase App Check enabled
- ✅ No authentication tokens in URLs
- ✅ Platform-specific API keys

---

## 🆘 Support

If you encounter issues:

1. **Check documentation:**

   - [FLAVORS_GUIDE.md](docs/FLAVORS_GUIDE.md) - Setup instructions
   - [FIREBASE_CONFIG.md](docs/FIREBASE_CONFIG.md) - Config management
   - [DOCUMENTATION.md](docs/DOCUMENTATION.md) - Complete guide index

2. **Verify configuration:**

   ```bash
   # Check Firebase configs exist
   ls -la android/app/src/*/google-services.json
   ls -la ios/Runner/*/GoogleService-Info.plist

   # Verify Firestore data
   node scripts/verify_firestore_data.js
   ```

3. **Clean build:**
   ```bash
   flutter clean
   flutter pub get
   flutter run --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz
   ```

---

## 🤝 Contributing

When adding new features:

1. Test on both Android and iOS
2. Test both flavors (legacy and new)
3. Update documentation if needed
4. Ensure Firebase configs are not committed with sensitive data

---

**Built with Flutter** 💙 | **Multi-Flavor Architecture** 🏢 | **Production Ready** ✅
