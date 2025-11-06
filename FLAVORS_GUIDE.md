# Flutter Flavors Implementation Guide

## Overview

This app uses **Flutter Flavors** to support multiple companies/apps from a single codebase. Each flavor has:

- Unique package/bundle ID
- Separate Firebase configuration
- Company-specific branding
- Independent app store listing

## Current Flavors

| Flavor               | Package ID                           | Company           | Type   | Firebase Project        |
| -------------------- | ------------------------------------ | ----------------- | ------ | ----------------------- |
| **galeriaKazimierz** | `pl.a2ti.galeriakazimierz`           | Galeria Kazimierz | Legacy | galeria-kazimierz-827d4 |
| **kazimierzClub**    | `pl.a2ti.kazimierzclub`              | Kazimierz Club    | Legacy | galeria-kazimierz-827d4 |
| **skanujNew**        | `com.skanujwygrywaj.skanuj_wygrywaj` | Skanuj Wygrywaj   | New    | development-417611      |

---

## Building with Flavors

### Quick Build Commands

```bash
# Galeria Kazimierz (Legacy)
flutter run --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz

# Kazimierz Club (Legacy)
flutter run --flavor kazimierzClub --dart-define=FLAVOR=kazimierzClub

# Skanuj New (New App)
flutter run --flavor skanujNew --dart-define=FLAVOR=skanujNew
```

### Using the Build Script

We provide a convenient build script:

```bash
# Make it executable (first time only)
chmod +x build_flavor.sh

# Build release APK
./build_flavor.sh galeriaKazimierz android release

# Build debug APK
./build_flavor.sh skanujNew android debug

# Build iOS
./build_flavor.sh kazimierzClub ios release
```

### Release Builds

**Android APK:**

```bash
flutter build apk --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz
```

**Android AAB (for Play Store):**

```bash
flutter build appbundle --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz
```

**iOS:**

```bash
flutter build ios --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz
# Then create archive in Xcode
```

---

## How Flavors Work

### 1. Android Configuration

**File:** `android/app/build.gradle.kts`

```kotlin
productFlavors {
    create("galeriaKazimierz") {
        dimension = "company"
        applicationId = "pl.a2ti.galeriakazimierz"
        resValue("string", "app_name", "Galeria Kazimierz")
    }
}
```

### 2. Firebase Configs

Each flavor has its own Firebase configuration:

```
android/app/src/
├── galeriaKazimierz/
│   └── google-services.json    # Legacy Firebase
├── kazimierzClub/
│   └── google-services.json    # Legacy Firebase
└── skanujNew/
    └── google-services.json    # New Firebase
```

### 3. Dart Flavor Configuration

**File:** `lib/flavor_config.dart`

Defines flavor-specific settings:

- Company ID
- Default URLs
- Firebase project
- Backend endpoints

### 4. Automatic Detection

On app startup:

1. Flavor is detected via `--dart-define=FLAVOR`
2. FlavorConfig loads appropriate settings
3. ConfigService uses flavor defaults
4. Firebase initializes with correct project

---

## Adding a New Company/Flavor

### Step 1: Android Configuration

**Edit:** `android/app/build.gradle.kts`

```kotlin
productFlavors {
    // ... existing flavors ...

    create("newCompany") {
        dimension = "company"
        applicationId = "com.yourcompany.appname"
        resValue("string", "app_name", "Company Name")
        buildConfigField("String", "FLAVOR_NAME", "\"newCompany\"")
    }
}
```

### Step 2: Add Firebase Config

1. Create Firebase project or add app to existing project
2. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
3. Place configs:

```bash
# Android
mkdir android/app/src/newCompany
cp ~/Downloads/google-services.json android/app/src/newCompany/

# iOS
cp ~/Downloads/GoogleService-Info.plist ios/Runner/GoogleService-Info-newCompany.plist
```

### Step 3: Add Dart Configuration

**Edit:** `lib/flavor_config.dart`

```dart
enum FlavorType {
  // ... existing flavors ...
  newCompany,
}

static FlavorConfig _getConfigForFlavor(FlavorType flavor) {
  switch (flavor) {
    // ... existing cases ...

    case FlavorType.newCompany:
      return FlavorConfig(
        flavor: FlavorType.newCompany,
        name: 'Company Name',
        packageId: 'com.yourcompany.appname',
        companyId: 'company-id',
        isLegacyByDefault: true, // or false for new app
        firebaseProject: 'firebase-project-id',
        defaultWebviewUrl: 'https://your-webview-url.com',
        defaultBackendUrl: 'https://your-backend-url.com',
      );
  }
}
```

### Step 4: Update Company Mapping

**Edit:** `lib/company_mapping.dart`

```dart
const Map<String, String> packageMappings = {
  // ... existing mappings ...
  'com.yourcompany.appname': 'company-id',
};
```

### Step 5: iOS Configuration (If Needed)

**Edit:** `ios/Runner.xcodeproj/project.pbxproj`

Or use Xcode:

1. Open `ios/Runner.xcodeproj` in Xcode
2. Select Runner target
3. Duplicate existing scheme
4. Rename to match flavor
5. Update bundle ID in Build Settings

### Step 6: Test the New Flavor

```bash
# Test debug build
flutter run --flavor newCompany --dart-define=FLAVOR=newCompany

# Test release build
./build_flavor.sh newCompany android release
```

---

## iOS Setup (Required Once)

For iOS flavors to work properly, you need to configure schemes in Xcode:

### Option 1: Manual Xcode Configuration

1. Open `ios/Runner.xcodeproj` in Xcode
2. Select `Product` > `Scheme` > `Manage Schemes`
3. For each flavor:

   - Duplicate the `Runner` scheme
   - Name it matching the flavor (e.g., `galeriaKazimierz`)
   - Edit scheme > Build Configuration > Select appropriate config

4. Update Bundle IDs in Build Settings:
   - Select Runner target
   - Build Settings tab
   - Search for "Product Bundle Identifier"
   - Add per-configuration values

### Option 2: Automated Setup (TODO)

We can create a script to automate iOS configuration. For now, manual setup is required.

---

## Flavor-Specific Customization

### App Icons

Place flavor-specific icons:

```
android/app/src/galeriaKazimierz/res/
├── mipmap-hdpi/ic_launcher.png
├── mipmap-mdpi/ic_launcher.png
├── mipmap-xhdpi/ic_launcher.png
└── ...
```

### Splash Screens

```
android/app/src/galeriaKazimierz/res/
└── drawable/launch_background.xml
```

### Strings/Resources

```
android/app/src/galeriaKazimierz/res/values/
└── strings.xml
```

---

## Troubleshooting

### Issue: "No flavor specified"

**Solution:** Always use `--dart-define=FLAVOR=<flavorName>`:

```bash
flutter run --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz
```

### Issue: "Firebase initialization failed"

**Causes:**

1. Missing `google-services.json` in flavor directory
2. Package ID mismatch between build and Firebase config

**Solution:**

1. Verify file exists: `android/app/src/<flavor>/google-services.json`
2. Check package ID in Firebase config matches `applicationId` in build.gradle

### Issue: "Flavor not found"

**Solution:** Ensure flavor name matches exactly (case-sensitive):

- Build config: `galeriaKazimierz`
- Command: `--flavor galeriaKazimierz`
- Dart define: `--dart-define=FLAVOR=galeriaKazimierz`

### Issue: iOS build fails

**Causes:**

1. Missing iOS scheme configuration
2. Bundle ID not set per configuration

**Solution:** Follow iOS Setup section above

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build Flavors

on: [push]

jobs:
  build-android:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        flavor: [galeriaKazimierz, kazimierzClub, skanujNew]
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: |
          flutter build apk \
            --flavor ${{ matrix.flavor }} \
            --dart-define=FLAVOR=${{ matrix.flavor }}
```

---

## Best Practices

1. **Always use --dart-define:** Ensures flavor is properly detected
2. **Test each flavor:** Before releasing, test all flavors
3. **Keep Firebase configs secure:** Don't commit sensitive keys (use .gitignore)
4. **Document company-specific settings:** Add notes in flavor config
5. **Use build script:** Consistent builds across team

---

## Quick Reference

### Default Testing (No Flavor)

```bash
flutter run
# Uses galeriaKazimierz by default
```

### Build All Flavors

```bash
for flavor in galeriaKazimierz kazimierzClub skanujNew; do
  ./build_flavor.sh $flavor android release
done
```

### Check Current Flavor

```bash
# In app logs, look for:
[Flavor] Initialized: <flavor-name>
```

---

## Migration from Old System

If migrating from the previous setup:

1. ✅ Android flavors configured
2. ✅ Firebase configs placed
3. ✅ Dart flavor system created
4. ⚠️ iOS needs manual setup (see iOS Setup section)
5. ⚠️ Update CI/CD pipelines to use flavors

---

## Support

For issues or questions:

1. Check troubleshooting section above
2. Review flavor configuration in `lib/flavor_config.dart`
3. Verify Firebase configs match package IDs
4. Test with `flutter run --verbose` for detailed logs
