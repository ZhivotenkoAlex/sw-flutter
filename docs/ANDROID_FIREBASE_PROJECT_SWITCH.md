# Android: Switching Firebase Projects

This guide explains how to switch Firebase projects for an existing Android flavor.

## Problem

On Android, Firebase auto-initializes from `google-services.json` before Dart code runs. Once initialized, the default Firebase app **cannot be deleted** at runtime. This means:

- ✅ iOS: Can switch Firebase projects dynamically via Firestore config
- ❌ Android: Requires new build with updated `google-services.json`

## Why This Limitation Exists

### Android Firebase Initialization Flow

```
App Starts
  ↓
1. Native Android code reads google-services.json
  ↓
2. Firebase auto-initializes with project from google-services.json
  ↓
3. Default Firebase app is created and LOCKED
  ↓
4. Dart code starts (main.dart)
  ↓
5. Code fetches config from Firestore
  ↓
6. ❌ Cannot delete default Firebase app (Android restriction)
  ↓
7. Firebase Messaging uses ORIGINAL project (from google-services.json)
```

### What Works Without Rebuild

Even with Firebase project mismatch, these features work dynamically via Firestore config:
- ✅ UI theme switching (Legacy/Modern)
- ✅ WebView URL updates
- ✅ Company ID changes
- ✅ Google Sign In (uses Web Client ID from Firestore)
- ❌ Firebase Messaging (stuck with original project)

## Solution: Update Flavor-Specific google-services.json

### File Structure

```
android/app/
├── google-services.json                           ← Main file (fallback)
└── src/
    ├── galeriaKazimierz/
    │   └── google-services.json                   ← For legacy flavor
    └── galeriaKazimierzNew/
        └── google-services.json                   ← For new flavor
```

### Why Flavor-Specific Files?

Flutter's Gradle plugin searches for `google-services.json` in this order:

1. **First Priority:** `/android/app/src/{flavorName}/google-services.json`
2. **Fallback:** `/android/app/google-services.json`

When you build with a flavor:
```bash
flutter build apk --flavor galeriaKazimierz
```

The build system will:
1. Look for `android/app/src/galeriaKazimierz/google-services.json`
2. If found, use it ✅
3. If not found, fall back to `android/app/google-services.json`

**This allows different flavors to use different Firebase projects!**

## Step-by-Step: Switch galeriaKazimierz to development-417611

### Current State

- `galeriaKazimierz` flavor: uses `galeria-kazimierz-827d4` project
- `galeriaKazimierzNew` flavor: uses `development-417611` project

### Goal

Switch `galeriaKazimierz` to use `development-417611` (same as galeriaKazimierzNew).

### Step 1: Update google-services.json

**Option A: Copy from galeriaKazimierzNew (Quick)**

```bash
cd android/app/src
cp galeriaKazimierzNew/google-services.json galeriaKazimierz/google-services.json
```

**Option B: Download from Firebase Console (Recommended)**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `development-417611`
3. Click gear icon → **Project Settings**
4. Scroll to "Your apps" → Select Android app with package `pl.a2ti.galeriakazimierz`
5. Click **Download google-services.json**
6. Replace `android/app/src/galeriaKazimierz/google-services.json` with downloaded file

**Verify the file:**
```bash
# Check project_id
grep "project_id" android/app/src/galeriaKazimierz/google-services.json
# Should show: "project_id": "development-417611"
```

### Step 2: Update Firestore Config

If not already done, update the database config:

```bash
node scripts/update_single_config.js
```

Or manually update `mobile_configs/galeria-kazimierz` in Firestore to point to `development-417611`.

### Step 3: Build New APK

```bash
# Clean build
flutter clean

# Build release APK
flutter build apk --release --flavor galeriaKazimierz

# Or build app bundle for Google Play
flutter build appbundle --release --flavor galeriaKazimierz
```

### Step 4: Update Version

In `pubspec.yaml`, increment version:
```yaml
# Before
version: 1.0.0+1

# After
version: 1.0.0+2
```

The `+2` is the **version code** that Google Play requires to be incremented.

### Step 5: Deploy to Google Play

Upload the new APK/AAB to Google Play Console:
- Same package ID: `pl.a2ti.galeriakazimierz` ✅
- Higher version code: `2` (was `1`) ✅
- Same signing key ✅
- Updated Firebase project in google-services.json ✅

Google Play will accept this as a standard app update.

## What About the Main google-services.json?

The file at `android/app/google-services.json` is used as **fallback only**.

**Options:**

1. **Leave it as-is** (galeria-kazimierz-827d4)
   - Won't be used since flavor-specific file exists
   - Keeps original config for reference

2. **Update it to development-417611** (recommended)
   - Keeps configuration consistent
   - Useful if you ever remove flavor-specific files

```bash
# Option 2: Update main file for consistency
cp android/app/src/galeriaKazimierzNew/google-services.json \
   android/app/google-services.json
```

## Verification

After building and installing the new APK:

1. Check logs for Firebase project:
```bash
adb logcat | grep -i firebase
# Should show: development-417611
```

2. Check FCM token:
```bash
adb logcat | grep -i "FCM.*token"
# New token from development-417611 project
```

3. Test push notifications:
   - Send test notification from Firebase Console (development-417611)
   - Should be received ✅

## Common Issues

### Issue: Firebase still using old project after rebuild

**Cause:** App not fully reinstalled

**Solution:**
```bash
# Uninstall old app completely
adb uninstall pl.a2ti.galeriakazimierz

# Install new build
flutter install --flavor galeriaKazimierz
```

### Issue: Multiple google-services.json found warning

**Cause:** Both main and flavor-specific files exist (this is normal)

**Solution:** No action needed. Flavor-specific file takes priority.

### Issue: Google Play rejects update

**Cause:** Signing key mismatch or version code not incremented

**Solution:**
- Ensure same keystore used: `android/app/key.properties`
- Increment version code in `pubspec.yaml`

## Summary

**Why flavor-specific files?**
- Different flavors can use different Firebase projects
- Build system prioritizes flavor-specific over main file
- Allows gradual migration (update one flavor at a time)

**What to update:**
- ✅ `/android/app/src/{flavorName}/google-services.json` (required)
- ✅ Version code in `pubspec.yaml` (required for Play Store)
- 📝 `/android/app/google-services.json` (optional, for consistency)

**Result:**
- Firebase Messaging works with new project ✅
- Google Sign In works ✅
- All other dynamic features work ✅
- Standard Google Play update (no special requirements) ✅


