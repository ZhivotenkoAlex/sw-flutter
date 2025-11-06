# Critical Issues Found and Fixed

## ✅ FIXED Issues

### 1. Hardcoded Company Name ✅

**Problem:** Company was hardcoded as `"kazimierz-club-new"` in firebase_messaging_service.dart

**Fix:** Changed to use the `company` parameter passed to the function

```dart
// Before
'company': "kazimierz-club-new",

// After
if (company != null) 'company': company,
```

### 2. Hardcoded App/Package ID ✅

**Problem:** Package ID was hardcoded as `'pl.a2ti.galeriakazimierz'`

**Fix:** Now dynamically reads from PackageInfo

```dart
static Future<String> _getPackageId() async {
  if (_cachedPackageId != null) return _cachedPackageId!;
  final packageInfo = await PackageInfo.fromPlatform();
  _cachedPackageId = packageInfo.packageName;
  return _cachedPackageId!;
}
```

### 3. Duplicate Platform Key ✅

**Fix:** Changed `platform: "mobile"` to `'device_type': "mobile"` to avoid key collision

---

## ⚠️ REMAINING CRITICAL ISSUE: Package/Bundle ID Mismatch

### The Problem

Your app is **currently built** with these identifiers:

- **Android:** `pl.a2ti.galeriakazimierz`
- **iOS:** `it.2take.galeriakazimierz`

But the **Firebase configs expect**:

| Mode       | Android Package                         | iOS Bundle                             |
| ---------- | --------------------------------------- | -------------------------------------- |
| **Legacy** | `pl.a2ti.galeriakazimierz` ✅           | `it.2take.galeriakazimierz` ✅         |
| **New**    | `com.skanujwygrywaj.skanuj_wygrywaj` ❌ | `com.skanujwygrywaj.skanujWygrywaj` ❌ |

### What This Means

When you switch to the new app (`isLegacy: false`):

1. ❌ Firebase initialization will **FAIL** because the package IDs don't match
2. ❌ Push notifications won't work
3. ❌ Firebase Auth won't work
4. ❌ Any Firebase service will be broken

### Why This Happens

The `google-services-new.json` file from the `main` branch was configured for a **different app** with different package identifiers. You cannot use this Firebase config with the current app build.

---

## 🔧 SOLUTIONS (Choose One)

### Option 1: Build Different Apps for Each Company (RECOMMENDED)

This is what you originally planned - have **separate builds** for each company/mode.

**Steps:**

1. **For Legacy Mode:**

   - Keep current package IDs
   - Use existing Firebase configs
   - Build with: `flutter build apk --flavor legacy`

2. **For New Mode:**

   - **Change package IDs** in build configs:
     ```kotlin
     // android/app/build.gradle.kts
     applicationId = "com.skanujwygrywaj.skanuj_wygrywaj"
     ```
     ```xml
     <!-- ios/Runner.xcodeproj -->
     PRODUCT_BUNDLE_IDENTIFIER = com.skanujwygrywaj.skanujWygrywaj
     ```
   - Use new Firebase configs
   - Build with: `flutter build apk --flavor new`

3. **Use Flutter Flavors** to manage different builds:
   - Create `android/app/src/legacy/` with legacy configs
   - Create `android/app/src/new/` with new configs
   - Each flavor uses appropriate Firebase config automatically

### Option 2: Update Firebase Configs to Match Current Package

**If all companies will use the same package ID:**

1. Go to Firebase Console for `development-417611` project
2. Add new Android app with package: `pl.a2ti.galeriakazimierz`
3. Add new iOS app with bundle: `it.2take.galeriakazimierz`
4. Download new `google-services.json` and `GoogleService-Info.plist`
5. Replace the files in `android/app/src/main/assets/` and `ios/Runner/`

This way both Firebase projects will work with the same package IDs.

### Option 3: Single App ID with Firebase Multi-Project (COMPLEX)

Configure Firebase to accept multiple package IDs per project, but this gets messy.

---

## 📋 RECOMMENDED APPROACH

Based on your original requirements ("we will have several apps for different companies"), I recommend:

### Strategy: One Codebase, Multiple Build Configurations

```
flutter-app/
├── android/app/src/
│   ├── galeria-kazimierz/    # Legacy company 1
│   │   └── google-services.json
│   ├── kazimierz-club/        # Legacy company 2
│   │   └── google-services.json
│   ├── skanuj-new/            # New app
│   │   └── google-services.json
│
├── ios/Runner/configs/
│   ├── GaleriaKazimierz-Info.plist
│   ├── KazimierzClub-Info.plist
│   └── SkanujNew-Info.plist
```

**Build commands:**

```bash
# Build legacy for company 1
flutter build apk --flavor galeriaKazimierz --dart-define=COMPANY_ID=galeria-kazimierz

# Build new app
flutter build apk --flavor skanujNew --dart-define=COMPANY_ID=skanuj-new
```

Each flavor:

- Has its own package ID
- Uses correct Firebase config
- App can still fetch additional config from API
- Single codebase, multiple deployments

---

## 🚨 IMMEDIATE ACTION REQUIRED

**Before testing the new app mode:**

1. ✅ The code fixes are already applied
2. ⚠️ You MUST either:

   - Update Firebase config to match current package IDs (Option 2), OR
   - Set up build flavors (Option 1), OR
   - Change the app's package IDs to match Firebase config

3. 📝 Update `IMPLEMENTATION_SUMMARY.md` with chosen approach

**Current Status:**

- ✅ Legacy mode works (package IDs match)
- ❌ New mode will NOT work until Firebase config mismatch is resolved

### 4. Android Build Configuration Issues ✅

**Problems:**
- NDK version mismatch (plugins require 27.0.12077973)
- minSdkVersion too low (Firebase Auth requires 23)
- BuildConfig fields not enabled for flavors
- MainActivity had complex Facebook SDK code

**Fixes Applied:**

```kotlin
// android/app/build.gradle.kts
android {
    ndkVersion = "27.0.12077973"  // Was: flutter.ndkVersion
    
    buildFeatures {
        buildConfig = true  // Required for flavor BuildConfig fields
    }
    
    defaultConfig {
        minSdk = 23  // Was: 21, Required by Firebase Auth
    }
}
```

**Simplified MainActivity.kt:**
```kotlin
package pl.a2ti.galeriakazimierz

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
}
```

**Deleted:** `MyApp.kt` (Facebook SDK handled by plugin)

---

## ✅ ISSUE RESOLVED: Build Flavors Implemented

**Solution Chosen:** Option 1 - Build Flavors

The app now uses Flutter/Gradle flavors to build different versions:

- ✅ `galeriaKazimierz` - Legacy mode, pl.a2ti.galeriakazimierz
- ✅ `kazimierzClub` - Legacy mode, pl.a2ti.kazimierzclub  
- ✅ `skanujNew` - New mode, com.skanujwygrywaj.skanuj_wygrywaj

Each flavor has its own:
- Package/Bundle ID
- Firebase configuration
- App name
- Default settings

See `FLAVORS_GUIDE.md` for complete documentation.

---

## Testing After Fixes

### Test Legacy Mode (Galeria Kazimierz)

```bash
flutter run --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz
# Package: pl.a2ti.galeriakazimierz + galeria-kazimierz Firebase
```

### Test Legacy Mode (Kazimierz Club)

```bash
flutter run --flavor kazimierzClub --dart-define=FLAVOR=kazimierzClub
# Package: pl.a2ti.kazimierzclub + galeria-kazimierz Firebase
```

### Test New Mode (Skanuj Wygrywaj)

```bash
flutter run --flavor skanujNew --dart-define=FLAVOR=skanujNew
# Package: com.skanujwygrywaj.skanuj_wygrywaj + development-417611 Firebase
```

---

## Files Modified in This Fix

- `lib/firebase_messaging_service.dart` - Fixed hardcoded values
- `CRITICAL_ISSUES_AND_SOLUTIONS.md` - This document
