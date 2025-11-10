# 🎨 Flavors Setup Guide

Complete guide for setting up and managing build flavors in this Flutter project.

## 📋 Table of Contents

- [What are Flavors?](#what-are-flavors)
- [Current Flavors](#current-flavors)
- [Android Flavor Setup](#android-flavor-setup)
- [iOS Flavor Setup](#ios-flavor-setup)
- [Adding a New Flavor](#adding-a-new-flavor)
- [Testing Flavors](#testing-flavors)
- [Troubleshooting](#troubleshooting)

---

## What are Flavors?

Flavors allow you to create multiple versions of your app from a single codebase. Each flavor can have:

- Different app name and icon
- Different package/bundle ID
- Different Firebase project
- Different backend configurations
- Separate app store listings

---

## Current Flavors

### **galeriaKazimierz** (Legacy)

|                      |                                                                       |
| -------------------- | --------------------------------------------------------------------- |
| **Company ID**       | `galeria-kazimierz`                                                   |
| **Android Package**  | `pl.a2ti.galeriakazimierz`                                            |
| **iOS Bundle ID**    | `it.2take.galeriakazimierz`                                           |
| **Firebase Project** | `galeria-kazimierz-827d4`                                             |
| **Config Source**    | `development-417611/skanuj-wygrywaj/mobile_configs/galeria-kazimierz` |
| **Type**             | Legacy (isLegacy: true)                                               |

### **galeriaKazimierzNew** (New)

|                      |                                                                        |
| -------------------- | ---------------------------------------------------------------------- |
| **Company ID**       | `kazimierz-club-new`                                                   |
| **Android Package**  | `com.skanujwygrywaj.skanuj_wygrywaj`                                   |
| **iOS Bundle ID**    | `com.skanujwygrywaj.skanujWygrywaj`                                    |
| **Firebase Project** | `development-417611`                                                   |
| **Config Source**    | `development-417611/skanuj-wygrywaj/mobile_configs/kazimierz-club-new` |
| **Type**             | New (isLegacy: false)                                                  |

---

## Android Flavor Setup

### Step 1: Configure build.gradle.kts

File: `android/app/build.gradle.kts`

```kotlin
android {
    // ... other config ...

    flavorDimensions += "company"

    productFlavors {
        create("galeriaKazimierz") {
            dimension = "company"
            applicationId = "pl.a2ti.galeriakazimierz"
            resValue("string", "app_name", "Galeria Kazimierz")
        }

        create("galeriaKazimierzNew") {
            dimension = "company"
            applicationId = "com.skanujwygrywaj.skanuj_wygrywaj"
            resValue("string", "app_name", "Galeria Kazimierz New")
        }
    }
}
```

### Step 2: Add Firebase Config Files

Each flavor needs its own `google-services.json` file:

```
android/app/src/
├── galeriaKazimierz/
│   └── google-services.json         # From galeria-kazimierz-827d4 project
└── galeriaKazimierzNew/
    └── google-services.json         # From development-417611 project
```

**How to get google-services.json:**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (galeria-kazimierz-827d4 or development-417611)
3. Go to Project Settings → Your apps
4. Find the Android app with matching package ID
5. Download `google-services.json`
6. Place in the correct flavor directory

**Important:** Make sure the `package_name` in `google-services.json` matches the `applicationId` in `build.gradle.kts`!

### Step 3: Test Android Build

```bash
# Build for specific flavor
flutter build apk --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz
flutter build apk --flavor galeriaKazimierzNew --dart-define=FLAVOR=galeriaKazimierzNew

# Run on device
./run_flavor.sh galeriaKazimierz android
```

---

## iOS Flavor Setup

iOS flavor setup requires configuring Xcode schemes and build configurations.

### Step 1: Open Xcode Project

```bash
open ios/Runner.xcworkspace
```

### Step 2: Create Build Configurations

1. In Xcode, click on the project name "Runner" in the navigator
2. Select the "Runner" project (blue icon at top)
3. Go to the **Info** tab
4. Under **Configurations**, duplicate existing configs:

**For galeriaKazimierz:**

- Duplicate `Debug` → Rename to `Debug-galeriaKazimierz`
- Duplicate `Release` → Rename to `Release-galeriaKazimierz`
- Duplicate `Profile` → Rename to `Profile-galeriaKazimierz`

**For galeriaKazimierzNew:**

- Duplicate `Debug` → Rename to `Debug-galeriaKazimierzNew`
- Duplicate `Release` → Rename to `Release-galeriaKazimierzNew`
- Duplicate `Profile` → Rename to `Profile-galeriaKazimierzNew`

### Step 3: Create Schemes

1. Click on the scheme dropdown at the top (next to "Runner")
2. Select **Manage Schemes...**
3. Click the **+** button to create a new scheme

**For galeriaKazimierz:**

- Name: `galeriaKazimierz`
- Target: `Runner`
- Click **OK**
- Click **Edit** (or Edit Scheme)
- Set configurations:
  - **Run**: Debug-galeriaKazimierz
  - **Test**: Debug-galeriaKazimierz
  - **Profile**: Profile-galeriaKazimierz
  - **Analyze**: Debug-galeriaKazimierz
  - **Archive**: Release-galeriaKazimierz
- ✅ Check "Shared" checkbox

**Repeat for galeriaKazimierzNew** with its configurations.

### Step 4: Configure Bundle IDs

1. Select the **Runner** target (not project)
2. Go to **Build Settings** tab
3. Search for "Product Bundle Identifier"
4. Set values for each configuration:

**Debug-galeriaKazimierz, Release-galeriaKazimierz, Profile-galeriaKazimierz:**

```
it.2take.galeriakazimierz
```

**Debug-galeriaKazimierzNew, Release-galeriaKazimierzNew, Profile-galeriaKazimierzNew:**

```
com.skanujwygrywaj.skanujWygrywaj
```

### Step 5: Add Firebase Config Files

Each flavor needs its own `GoogleService-Info.plist`:

```
ios/Runner/
├── galeriaKazimierz/
│   └── GoogleService-Info.plist    # From galeria-kazimierz-827d4
└── galeriaKazimierzNew/
    └── GoogleService-Info.plist    # From development-417611
```

**How to get GoogleService-Info.plist:**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to Project Settings → Your apps
4. Find the iOS app with matching Bundle ID
5. Download `GoogleService-Info.plist`
6. Place in the correct flavor directory

### Step 6: Add plist Files to Xcode

For **each flavor** directory:

1. In Xcode, right-click on **Runner** folder in the navigator
2. Select **Add Files to "Runner"...**
3. Navigate to `ios/Runner/{flavorName}/`
4. Select `GoogleService-Info.plist`
5. **IMPORTANT:** In the dialog:
   - ✅ Check **"Copy items if needed"** - UNCHECK this!
   - ✅ Check **"Create groups"**
   - ✅ Target: Check "Runner"
6. Click **Add**

### Step 7: Configure Build Phase Script

1. Select **Runner** target
2. Go to **Build Phases** tab
3. Find or add a **Run Script** phase
4. Add this script (or verify it exists):

```bash
# Copy the correct GoogleService-Info.plist for the current flavor
cp "${PROJECT_DIR}/Runner/${PRODUCT_NAME}/GoogleService-Info.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
```

This copies the flavor-specific plist to the app bundle during build.

### Step 8: Test iOS Build

```bash
# Run on simulator
./run_flavor.sh galeriaKazimierz ios
./run_flavor.sh galeriaKazimierzNew ios

# Or use Flutter command
flutter run --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz
```

---

## Adding a New Flavor

### 1. Define Flavor in Dart

File: `lib/flavor_config.dart`

```dart
enum FlavorType {
  galeriaKazimierz,
  galeriaKazimierzNew,
  yourNewFlavor,  // Add here
}

static FlavorConfig _getConfigForFlavor(FlavorType flavor) {
  switch (flavor) {
    // ... existing cases ...

    case FlavorType.yourNewFlavor:
      return FlavorConfig(
        flavor: FlavorType.yourNewFlavor,
        name: 'Your New Company',
        packageId: 'com.yourcompany.app',
        companyId: 'your-company-id',
      );
  }
}
```

### 2. Add Android Flavor

File: `android/app/build.gradle.kts`

```kotlin
productFlavors {
    // ... existing flavors ...

    create("yourNewFlavor") {
        dimension = "company"
        applicationId = "com.yourcompany.app"
        resValue("string", "app_name", "Your Company App")
    }
}
```

Create directory and add Firebase config:

```bash
mkdir -p android/app/src/yourNewFlavor
# Add google-services.json from Firebase Console
```

### 3. Add iOS Flavor

In Xcode:

1. Create build configurations: `Debug-yourNewFlavor`, `Release-yourNewFlavor`, `Profile-yourNewFlavor`
2. Create scheme: `yourNewFlavor`
3. Set Bundle ID: `com.yourcompany.app`
4. Create directory: `ios/Runner/yourNewFlavor/`
5. Add `GoogleService-Info.plist` from Firebase Console

### 4. Add Firestore Config

File: `scripts/populate_firestore_config.js`

```javascript
const configs = {
  // ... existing configs ...

  "your-company-id": {
    firebaseConfig: {
      android: {
        apiKey: "your-android-api-key",
        appId: "your-android-app-id",
        messagingSenderId: "your-sender-id",
        projectId: "your-firebase-project",
        storageBucket: "your-bucket",
        databaseURL: "your-database-url",
      },
      ios: {
        apiKey: "your-ios-api-key",
        appId: "your-ios-app-id",
        messagingSenderId: "your-sender-id",
        projectId: "your-firebase-project",
        storageBucket: "your-bucket",
        databaseURL: "your-database-url",
        iosBundleId: "com.yourcompany.app",
      },
    },
    webviewUrl: "https://your-app-url.com",
    isLegacy: false,
    firebaseProject: "your-firebase-project",
    version: 1,
  },
}
```

### 5. Populate Firestore

```bash
cd scripts
npm install
node populate_firestore_config.js
```

### 6. Update Company Mapping

File: `lib/company_mapping.dart`

```dart
const Map<String, String> packageMappings = {
  'pl.a2ti.galeriakazimierz': 'galeria-kazimierz',
  'com.skanujwygrywaj.skanuj_wygrywaj': 'kazimierz-club-new',
  'com.yourcompany.app': 'your-company-id',  // Add here
};
```

### 7. Test New Flavor

```bash
./run_flavor.sh yourNewFlavor android
./run_flavor.sh yourNewFlavor ios
```

---

## Testing Flavors

### Quick Test Checklist

✅ **App launches successfully**

```bash
./run_flavor.sh [flavorName] android
./run_flavor.sh [flavorName] ios
```

✅ **Correct app name displays** (check home screen)

✅ **Config fetches from Firestore**

```bash
# Check logs for:
flutter logs | grep "SecureConfig"
# Should see: "Config fetched successfully"
```

✅ **Firebase Messaging works**

```bash
# Check logs for:
flutter logs | grep "FCM"
# Should see token registration
```

✅ **Webview loads correct URL**

```bash
# Check logs for:
flutter logs | grep "WEBVIEW"
```

✅ **No package conflicts** (try installing both flavors)

```bash
./run_flavor.sh galeriaKazimierz android
./run_flavor.sh galeriaKazimierzNew android
# Second should auto-uninstall first
```

### Test Both Platforms

```bash
# Android
./run_flavor.sh [flavor] android debug
./run_flavor.sh [flavor] android release

# iOS
./run_flavor.sh [flavor] ios debug
./run_flavor.sh [flavor] ios release
```

---

## Troubleshooting

### Android Issues

#### ❌ "No flavor specified"

**Solution:** Always use both parameters:

```bash
flutter run --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz
```

#### ❌ "INSTALL_FAILED_CONFLICTING_PROVIDER"

**Solution:** Use the run script which auto-cleans:

```bash
./run_flavor.sh galeriaKazimierz android
```

#### ❌ "FirebaseException: com.google.firebase.auth.FirebaseAuth cannot be cast"

**Solution:** Check that `google-services.json` has correct package name

---

### iOS Issues

#### ❌ "The Xcode project does not define custom schemes"

**Solution:** Follow [Step 3: Create Schemes](#step-3-create-schemes)

#### ❌ "No provisioning profile found"

**Solution:**

1. In Xcode, select Runner target
2. Go to Signing & Capabilities
3. Select your team
4. Let Xcode create provisioning profile

#### ❌ "GoogleService-Info.plist not found"

**Solution:**

1. Check file exists in `ios/Runner/{flavor}/`
2. Verify it's added to Xcode project
3. Check Build Phase script is correct

#### ❌ "Duplicate symbols for architecture"

**Solution:**

1. Clean build: `flutter clean`
2. Delete `Pods` folder: `rm -rf ios/Pods`
3. Reinstall pods: `cd ios && pod install`

---

### Firebase Issues

#### ❌ "Firebase initialization failed"

**Causes:**

1. Missing config file
2. Wrong package/bundle ID
3. Wrong Firebase project

**Solution:**

```bash
# Verify config files exist
ls -la android/app/src/*/google-services.json
ls -la ios/Runner/*/GoogleService-Info.plist

# Check package IDs match
grep "package_name" android/app/src/*/google-services.json
grep "BUNDLE_ID" ios/Runner/*/GoogleService-Info.plist
```

#### ❌ "Config not found in Firestore"

**Solution:**

```bash
# Populate configs
cd scripts
node populate_firestore_config.js

# Verify data
node verify_firestore_data.js
```

---

## Best Practices

1. **Never commit sensitive data**

   - `google-services.json` and `GoogleService-Info.plist` should be in `.gitignore` if they contain production keys

2. **Test both flavors after changes**

   - Changes to shared code affect all flavors

3. **Use run script for development**

   - Handles cleanup automatically
   - Faster development workflow

4. **Keep configs in sync**

   - When updating Firebase, update both plist/json AND Firestore

5. **Document flavor-specific features**
   - If a flavor needs special handling, document it

---

## Summary

**Android Setup:**

1. Add flavor to `build.gradle.kts`
2. Add `google-services.json` to flavor directory
3. Build and test

**iOS Setup:**

1. Create Build Configurations
2. Create Schemes
3. Configure Bundle IDs
4. Add `GoogleService-Info.plist`
5. Add to Xcode project
6. Build and test

**Firestore Setup:**

1. Add config to `populate_firestore_config.js`
2. Run population script
3. Verify data

**Done!** 🎉

---

For more details, see:

- [README.md](../README.md) - Project overview
- [FIREBASE_CONFIG.md](FIREBASE_CONFIG.md) - Firebase configuration guide
