# Flutter Flavors - Complete Guide

## Table of Contents

- [Overview](#overview)
- [Current Flavors](#current-flavors)
- [Using Flavors](#using-flavors)
- [Adding New Companies](#adding-new-companies)
- [Troubleshooting](#troubleshooting)

## Overview

This application uses **Flutter Build Flavors** to support multiple companies from a single codebase.

Each flavor has:

- Unique package/bundle identifier
- Separate Firebase configuration
- Custom app name and branding
- Independent App Store listing

## Current Flavors

| Flavor                | Company               | Package ID                                                                                | Type   | Firebase                |
| --------------------- | --------------------- | ----------------------------------------------------------------------------------------- | ------ | ----------------------- |
| `galeriaKazimierz`    | Galeria Kazimierz     | Android: `pl.a2ti.galeriakazimierz`<br>iOS: `it.2take.galeriakazimierz`                   | Legacy | galeria-kazimierz-827d4 |
| `galeriaKazimierzNew` | Galeria Kazimierz New | Android: `com.skanujwygrywaj.skanuj_wygrywaj`<br>iOS: `com.skanujwygrywaj.skanujWygrywaj` | New    | development-417611      |

## Using Flavors

### Run Development Build

```bash
# Galeria Kazimierz
flutter run --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz

# Galeria Kazimierz New
flutter run --flavor galeriaKazimierzNew --dart-define=FLAVOR=galeriaKazimierzNew

or with

```

### Build for Release

**Using Build Scripts:**

**Build**

```bash
./build_flavor.sh galeriaKazimierz android release
./build_flavor.sh galeriaKazimierzNew ios release
```

**Run**

```bash
# Make executable (first time only)
chmod +x run_flavor.sh

# Run any flavor (auto-cleans conflicting packages)
./run_flavor.sh galeriaKazimierz android
./run_flavor.sh galeriaKazimierzNew android debug
./run_flavor.sh galeriaKazimierz ios release
```

**Manual Build:**

```bash
# Android APK
flutter build apk --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz

# Android App Bundle
flutter build appbundle --flavor galeriaKazimierzNew --dart-define=FLAVOR=galeriaKazimierzNew

# iOS
flutter build ios --flavor galeriaKazimierzNew --dart-define=FLAVOR=galeriaKazimierzNew
```

## Adding New Companies

### Step-by-Step Guide

#### 1. Android Configuration

Edit `android/app/build.gradle.kts`:

```kotlin
productFlavors {
    create("newCompany") {
        dimension = "company"
        applicationId = "com.company.appname"
        resValue("string", "app_name", "Company Name")
        buildConfigField("String", "FLAVOR_NAME", "\"newCompany\"")
    }
}
```

#### 2. Add Firebase Configuration

**Android:**

```bash
mkdir android/app/src/newCompany
cp ~/Downloads/google-services.json android/app/src/newCompany/
```

**iOS:**

```bash
mkdir ios/newCompany ios/Runner/newCompany
cp ~/Downloads/GoogleService-Info.plist ios/newCompany/
cp ~/Downloads/GoogleService-Info.plist ios/Runner/newCompany/
```

#### 3. Create iOS Configuration Files

**App Name** (`ios/Runner/newCompany/Info.plist`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Company Name</string>
</dict>
</plist>
```

**Bundle ID** (`ios/Flutter/Debug-newCompany.xcconfig`):

```
#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
#include "Generated.xcconfig"
PRODUCT_BUNDLE_IDENTIFIER = com.company.appname
FLUTTER_FLAVOR = newCompany
```

**Release Config** (`ios/Flutter/Release-newCompany.xcconfig`):

```
#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"
#include "Generated.xcconfig"
PRODUCT_BUNDLE_IDENTIFIER = com.company.appname
FLUTTER_FLAVOR = newCompany
```

#### 4. Add Dart Configuration

Edit `lib/flavor_config.dart`:

**Add to enum:**

```dart
enum FlavorType {
  galeriaKazimierz,
  galeriaKazimierzNew,
  galeriaKazimierzNew,
  newCompany,  // ADD
  unknown,
}
```

**Add to \_stringToFlavorType:**

```dart
case 'newCompany':
  return FlavorType.newCompany;
```

**Add to \_createFlavorConfig:**

```dart
case FlavorType.newCompany:
  return FlavorConfig(
    flavorType: FlavorType.newCompany,
    name: 'Company Name',
    companyId: 'company-id',
    webviewUrl: 'https://your-url.com',
    isLegacy: true,  // or false
    firebaseProject: 'firebase-project-id',
    backendUrl: 'https://backend-url.com',
  );
```

#### 5. Update Company Mapping

Edit `lib/company_mapping.dart`:

```dart
const Map<String, String> packageMappings = {
  'pl.a2ti.galeriakazimierz': 'galeria-kazimierz',
  'pl.a2ti.kazimierzclub': 'kazimierz-club',
  'com.skanujwygrywaj.skanuj_wygrywaj': 'kazimierz-club-new',
  'com.company.appname': 'company-id',  // ADD
};
```

#### 6. iOS Xcode Setup

1. Open `ios/Runner.xcworkspace`
2. Create build configurations (Debug-newCompany, Release-newCompany)
3. Link xcconfig files
4. Create scheme: `Product` > `Scheme` > `Manage Schemes` > `+`
5. Configure scheme settings

**See `docs/IOS_FLAVOR_SETUP.md` for detailed steps**

#### 7. Test

```bash
flutter run --flavor newCompany --dart-define=FLAVOR=newCompany
./build_flavor.sh newCompany android release
```

### Verification Checklist

- [ ] Builds successfully
- [ ] Correct package ID
- [ ] Firebase initializes correctly
- [ ] App shows correct name
- [ ] WebView loads correct URL
- [ ] Push notifications work
- [ ] iOS builds (after Xcode setup)

## Troubleshooting

### "No flavor specified"

**Problem:** Missing `--dart-define`

**Solution:**

```bash
flutter run --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz
```

### Firebase Initialization Failed

**Check:**

```bash
# Verify Firebase config exists
ls android/app/src/galeriaKazimierz/google-services.json
ls ios/galeriaKazimierz/GoogleService-Info.plist

# Check package name
grep "package_name" android/app/src/galeriaKazimierz/google-services.json
```

### Wrong URL Loads

**Debug:**

```bash
flutter run --verbose --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz
# Look for: [Flavor] Initialized: Galeria Kazimierz
```

**Fix:**

1. Check `lib/flavor_config.dart`
2. Verify company mapping
3. Clear cache and reinstall

### iOS Build Fails

**Solution:** Follow `docs/IOS_FLAVOR_SETUP.md` to configure Xcode

### App Name Not Changing

**Android:** Check `resValue` in `build.gradle.kts`
**iOS:** Check `Info.plist` in `ios/Runner/{flavor}/`

Uninstall app and reinstall after changes.

## Quick Reference

### Commands

```bash
# Run
flutter run --flavor FLAVOR --dart-define=FLAVOR=FLAVOR

# Build
./build_flavor.sh FLAVOR android release
./build_flavor.sh FLAVOR ios release

# Clean
flutter clean && flutter pub get
```

### Key Files

```
Android Config:   android/app/build.gradle.kts
Android Firebase: android/app/src/{flavor}/google-services.json
iOS Bundle:       ios/Flutter/{Debug|Release}-{flavor}.xcconfig
iOS Firebase:     ios/{flavor}/GoogleService-Info.plist
iOS App Name:     ios/Runner/{flavor}/Info.plist
Dart Config:      lib/flavor_config.dart
Company Map:      lib/company_mapping.dart
iOS Guide:        docs/IOS_FLAVOR_SETUP.md
```

## Resources

- [README.md](README.md) - Main documentation
- [docs/IOS_FLAVOR_SETUP.md](docs/IOS_FLAVOR_SETUP.md) - iOS setup
- [build_flavor.sh](build_flavor.sh) - Build script
