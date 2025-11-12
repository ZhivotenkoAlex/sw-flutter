# Dynamic Configuration Guide

This guide explains how to use Firestore to dynamically configure your app **without releasing a new version**.

## Table of Contents

- [Overview](#overview)
- [What Can Be Changed Dynamically](#what-can-be-changed-dynamically)
- [Configuration Structure](#configuration-structure)
- [Step-by-Step Instructions](#step-by-step-instructions)
- [Android Setup](#android-setup)
- [iOS Setup](#ios-setup)
- [Testing](#testing)
- [Production Deployment](#production-deployment)
- [Troubleshooting](#troubleshooting)

---

## Overview

### How It Works

```
App Launch
   ↓
Load flavor config (determines which Firestore document to read)
   ↓
Fetch configuration from Firestore (development-417611/skanuj-wygrywaj/mobile_configs/{companyId})
   ↓
Apply configuration:
   - companyId (for API calls and business logic)
   - webviewUrl (URL to load in WebView)
   - isLegacy (UI theme: blue or purple)
   - Firebase credentials (for messaging)
   ↓
Initialize Firebase with fetched credentials
   ↓
Load WebView with configured URL
```

### Key Benefits

✅ **No new release required** - Change behavior via Firestore  
✅ **Switch companies/databases** - Change `companyId` to switch backends  
✅ **Instant rollback** - Revert changes in ~1 minute  
✅ **A/B testing** - Test different configurations with different users  
✅ **Gradual rollout** - Deploy changes to subset of users first  

---

## What Can Be Changed Dynamically

| Parameter | Impact | Release Required? |
|-----------|--------|-------------------|
| **companyId** | Company ID used in API calls and business logic | ❌ No |
| **webviewUrl** | URL loaded in WebView | ❌ No |
| **isLegacy** | UI theme (blue vs purple) | ❌ No |
| **firebaseConfigAndroid** | Firebase credentials for Android | ❌ No |
| **firebaseConfigIOS** | Firebase credentials for iOS | ❌ No |
| **firebaseProject** | Firebase project name (metadata) | ❌ No |
| **version** | Config version number (⚠️ MUST increment when updating) | ❌ No |

---

## Configuration Structure

### Firestore Location

```
Firebase Project: development-417611
  └─ Database: skanuj-wygrywaj (named database)
      └─ Collection: mobile_configs
          ├─ galeria-kazimierz (document)
          └─ kazimierz-club-new (document)
```

### Document Structure

```javascript
// Document ID: galeria-kazimierz
{
  // Company ID used in app logic and API calls
  "companyId": "galeria-kazimierz",
  
  // URL to load in WebView
  "webviewUrl": "https://login.2take.it/...",
  
  // UI mode: true = Legacy (blue theme), false = Modern (purple theme)
  "isLegacy": true,
  
  // Firebase project name
  "firebaseProject": "galeria-kazimierz-827d4",
  
  // Android Firebase credentials
  "firebaseConfigAndroid": {
    "apiKey": "AIza...",
    "appId": "1:839029...",
    "messagingSenderId": "839029981684",
    "projectId": "galeria-kazimierz-827d4",
    "storageBucket": "galeria-kazimierz-827d4.firebasestorage.app",
    "databaseURL": "https://galeria-kazimierz-827d4.firebaseio.com"
  },
  
  // iOS Firebase credentials
  "firebaseConfigIOS": {
    "apiKey": "AIza...",
    "appId": "1:839029...",
    "messagingSenderId": "839029981684",
    "projectId": "galeria-kazimierz-827d4",
    "storageBucket": "galeria-kazimierz-827d4.firebasestorage.app",
    "databaseURL": "https://galeria-kazimierz-827d4.firebaseio.com",
    "iosBundleId": "it.2take.galeriakazimierz"
  },
  
  // Config version (REQUIRED: increment when making ANY changes)
  // The app automatically checks version and fetches new config if version is higher
  "version": 1
}
```

---

## Step-by-Step Instructions

### Method 1: Using Firebase Console (Recommended for Quick Changes)

**When to use:** Quick changes to existing configuration

1. **Open Firebase Console**
   ```
   https://console.firebase.google.com/
   → Select project: development-417611
   → Firestore Database
   → Select database: skanuj-wygrywaj
   → Collection: mobile_configs
   → Document: galeria-kazimierz (or your target)
   ```

2. **Edit fields** (examples):
   
   **To change WebView URL:**
   ```javascript
   webviewUrl: "https://new-url.com"
   ```
   
   **To switch UI theme:**
   ```javascript
   isLegacy: false  // Change from true to false
   ```
   
   **To switch company/database:**
   ```javascript
   companyId: "kazimierz-club-new"  // Change from "galeria-kazimierz"
   ```

3. **⚠️ CRITICAL: Increment version** (REQUIRED):
   ```javascript
   version: 2  // Was 1 - MUST be incremented!
   ```
   
   **Why version is required:**
   - The app caches configuration locally for performance
   - When version is incremented, the app automatically detects the change
   - App fetches new config on next launch WITHOUT requiring cache clear or reinstall
   - Without version increment, users may see stale config until cache expires (1 hour)

4. **Save changes**

5. **Restart app on device** - Changes will be loaded automatically

**Result:** App loads new configuration on next launch! No cache clearing needed.

---

### Method 2: Using Population Script (Recommended for Complete Updates)

**When to use:** Updating multiple fields or all credentials

1. **Edit configuration file:**
   ```bash
   cd scripts
   nano populate_firestore_config.js
   ```

2. **Modify configuration:**
   ```javascript
   const configs = {
     'galeria-kazimierz': {
       firebaseConfig: {
         android: { 
           // ⚠️ CRITICAL: projectId MUST match google-services.json!
           // For galeriaKazimierz flavor: "galeria-kazimierz-827d4"
           projectId: 'galeria-kazimierz-827d4',
           // ... other fields from google-services.json
         },
         ios: { /* updated credentials */ }
       },
       webviewUrl: 'https://new-url.com',
       isLegacy: false,
       firebaseProject: 'galeria-kazimierz-827d4',  // Must match android projectId
       version: 2  // ⚠️ REQUIRED: Always increment when making changes!
     }
   };
   ```

3. **Run population script:**
   ```bash
   npm install  # First time only
   node populate_firestore_config.js
   ```

4. **Verify changes:**
   ```bash
   node verify_firestore_data.js
   ```

5. **Restart app** - New configuration will be loaded

---

## Android Setup

### Prerequisites

✅ Android Studio installed  
✅ Flutter SDK configured  
✅ Firebase project created  
✅ `google-services.json` files in place  

### Initial Setup

Your Android app is already configured if you can build successfully. The dynamic configuration works automatically.

### Testing on Android

```bash
# Run in debug mode (always fetches fresh config)
./run_flavor.sh galeriaKazimierz android debug

# Check logs for configuration loading
adb logcat | grep "SecureConfig\|companyId\|isLegacy"
```

**Expected logs:**
```
[SecureConfig] Fetching config from Firestore for: galeria-kazimierz
[SecureConfig] Loaded companyId: galeria-kazimierz
[MyApp] UI Mode: Legacy Mode (isLegacy=true)
[WebViewScreen] Loading Legacy mode, URL: https://...
```

### Building for Production

```bash
# Build release APK
flutter build apk --flavor galeriaKazimierz \
  --dart-define=FLAVOR=galeriaKazimierz \
  --release

# Build App Bundle for Play Store
flutter build appbundle --flavor galeriaKazimierz \
  --dart-define=FLAVOR=galeriaKazimierz \
  --release
```

**Output:**
```
build/app/outputs/bundle/galeriaKazimierzRelease/app-galeriaKazimierz-release.aab
```

---

## iOS Setup

### Prerequisites

✅ Xcode installed  
✅ iOS development certificates configured  
✅ Xcode schemes created (see [FLAVORS_GUIDE.md](FLAVORS_GUIDE.md#ios-flavor-setup))  
✅ `GoogleService-Info.plist` files in place  

### Initial Setup

If you haven't set up iOS flavors yet, follow the complete guide in [FLAVORS_GUIDE.md](FLAVORS_GUIDE.md#ios-flavor-setup).

**Quick check:**
```bash
# Verify schemes exist
ls -la ios/Runner.xcworkspace

# Verify plist files
ls -la ios/Runner/*/GoogleService-Info.plist
```

### Testing on iOS

```bash
# Run in debug mode (always fetches fresh config)
./run_flavor.sh galeriaKazimierz ios debug

# Check logs in Xcode Console or terminal
flutter logs | grep "SecureConfig\|companyId\|isLegacy"
```

**Expected logs:**
```
[SecureConfig] Fetching config from Firestore for: galeria-kazimierz
[SecureConfig] Loaded companyId: galeria-kazimierz
[MyApp] UI Mode: Legacy Mode (isLegacy=true)
[WebViewScreen] Loading Legacy mode, URL: https://...
```

### Building for Production

```bash
# Build for iOS
flutter build ios --flavor galeriaKazimierz \
  --dart-define=FLAVOR=galeriaKazimierz \
  --release

# Then archive in Xcode
open ios/Runner.xcworkspace
```

**In Xcode:**
1. Select scheme: **galeriaKazimierz**
2. Product → Archive
3. Distribute App → App Store Connect
4. Upload

---

## Testing

### Pre-Deployment Testing Checklist

Test BOTH configurations before deploying to production:

#### Test Legacy Mode (isLegacy: true)

```bash
# 1. Set configuration in Firestore
# companyId: "galeria-kazimierz"
# isLegacy: true

# 2. Run app
./run_flavor.sh galeriaKazimierz android debug

# 3. Verify:
# ✅ Blue theme visible (if UI theme is used)
# ✅ Debug indicator shows "Legacy Mode 🕐" (debug only)
# ✅ WebView loads correct URL
# ✅ Push notifications work
# ✅ All app features function correctly
```

#### Test Modern Mode (isLegacy: false)

```bash
# 1. Change configuration in Firestore
# isLegacy: false

# 2. Run app (may need to clear data)
./run_flavor.sh galeriaKazimierz android debug

# 3. Verify:
# ✅ Purple theme visible (if UI theme is used)
# ✅ Debug indicator shows "Modern Mode 🚀" (debug only)
# ✅ WebView loads correct URL
# ✅ Push notifications work
# ✅ All app features function correctly
```

#### Test Company Switch

```bash
# 1. Change in Firestore:
# companyId: "kazimierz-club-new"
# webviewUrl: "https://new-backend.com"
# firebaseConfig*: (new credentials)

# 2. Run app
./run_flavor.sh galeriaKazimierz android debug

# 3. Verify:
# ✅ Logs show: "Loaded companyId: kazimierz-club-new"
# ✅ New WebView URL loads
# ✅ API calls use new companyId
# ✅ Data from new database appears
```

### Configuration Cache & Version System

**How caching works:**

The app uses a **version-based caching system**:

1. **On app launch:**
   - App checks cached config version
   - Fetches current version from Firestore
   - If Firestore version > cached version → **automatically fetches new config**
   - If versions match → uses cached config (faster)

2. **Cache expiration:**
   - Cache expires after **1 hour** (if version check fails)
   - Debug mode always fetches fresh config

**⚠️ CRITICAL: Always increment version when making changes**

```javascript
// Before change:
"version": 1

// After change:
"version": 2  // MUST increment!
```

**Why version is required:**
- Without version increment, users may see stale config for up to 1 hour
- With version increment, users get new config immediately on next app launch
- No need to clear cache or reinstall app

**To force refresh (if version not incremented):**
- Run in debug mode (always refreshes)
- OR clear app data on device
- OR wait 1 hour (cache expires)

---

## Production Deployment

### Deployment Workflow

```
┌─────────────────────────────────────────────┐
│  STEP 1: Build and Deploy App with New Code │
│  (Must include dynamic configuration support)│
└──────────────────┬──────────────────────────┘
                   ↓
┌─────────────────────────────────────────────┐
│  STEP 2: Test Configuration Changes         │
│  (Test on dev devices with Firestore changes)│
└──────────────────┬──────────────────────────┘
                   ↓
┌─────────────────────────────────────────────┐
│  STEP 3: Deploy to Production               │
│  (Change Firestore config when ready)       │
└──────────────────┬──────────────────────────┘
                   ↓
┌─────────────────────────────────────────────┐
│  Users get new configuration on next launch  │
│  (NO app update required!)                   │
└─────────────────────────────────────────────┘
```

### Example: Gradual Migration Scenario

**Goal:** Migrate from old company (`galeria-kazimierz`) to new company (`kazimierz-club-new`)

**Week 1: Deploy app with dynamic config support**
```bash
# Build and deploy new version
flutter build appbundle --flavor galeriaKazimierz \
  --dart-define=FLAVOR=galeriaKazimierz --release

# Firestore config remains OLD:
{
  "companyId": "galeria-kazimierz",
  "isLegacy": true,
  ...
}
```

**Week 2-3: Test with beta users**
```javascript
// Change Firestore for beta users' devices:
{
  "companyId": "kazimierz-club-new",  // NEW
  "webviewUrl": "https://new-backend.com",  // NEW
  "isLegacy": false,  // NEW theme
  ...
}

// Monitor for issues
// Gather feedback
```

**Week 4: Full rollout**
```javascript
// Change Firestore for ALL users:
{
  "companyId": "kazimierz-club-new",
  "webviewUrl": "https://new-backend.com",
  "isLegacy": false,
  "version": 2  // ⚠️ CRITICAL: Incremented from 1
}

// All users get new configuration on next app launch!
// Version increment triggers automatic refresh - no cache clearing needed
```

**If issues occur: Instant rollback**
```javascript
// Revert Firestore (takes ~1 minute):
{
  "companyId": "galeria-kazimierz",  // Reverted
  "webviewUrl": "https://old-backend.com",  // Reverted
  "isLegacy": true,  // Reverted
  "version": 3  // ⚠️ CRITICAL: Incremented from 2
}

// All users back to old configuration on next launch
// Version increment ensures immediate rollback without cache clearing
```

---

## Troubleshooting

### Configuration Not Loading

**Symptom:** App shows "Loading configuration..." indefinitely

**Causes:**
1. No internet connection
2. Firestore rules blocking access
3. Missing document in Firestore
4. Wrong document ID

**Solution:**
```bash
# 1. Check internet connection

# 2. Verify Firestore document exists
node scripts/verify_firestore_data.js

# 3. Check logs
flutter logs | grep "SecureConfig\|Firestore"

# Expected: [SecureConfig] Config fetched successfully
# If error: Check error message

# 4. Verify document ID matches flavor
# Flavor: galeriaKazimierz
# Should load: mobile_configs/galeria-kazimierz
```

---

### Changes Not Appearing

**Symptom:** Made changes in Firestore but app still shows old configuration

**Cause:** Version not incremented OR configuration cache

**Solution:**

**✅ RECOMMENDED: Increment version (automatic refresh)**
```javascript
// In Firestore, increment version:
"version": 2  // Was 1 - MUST increment!
```
- App automatically detects version change
- Fetches new config on next launch
- No cache clearing needed

**Alternative solutions (if version already incremented):**
```bash
# Option 1: Run in debug mode (bypasses cache)
./run_flavor.sh galeriaKazimierz android debug

# Option 2: Clear app data
# Android: Settings → Apps → [App Name] → Clear Data
# iOS: Delete and reinstall app

# Option 3: Wait 1 hour (cache expires)
```

**Verify version check:**
```bash
# Check logs for version comparison:
adb logcat | grep "SecureConfig.*version"

# Expected output:
# [SecureConfig] Newer version available (2 > 1), clearing cache and fetching...
# OR
# [SecureConfig] Using persistent cache (version 1 is current)
```

---

### Firebase Messaging Not Working After Config Change

**Symptom:** Push notifications stop working after changing Firebase credentials

**Cause:** Mismatch between `google-services.json`/`GoogleService-Info.plist` in app and Firestore `firebaseConfigAndroid`/`firebaseConfigIOS`

**⚠️ CRITICAL: firebaseConfigAndroid MUST match native google-services.json**

**Important rules:**

1. **For `galeriaKazimierz` flavor:**
   - Native `google-services.json` uses: `galeria-kazimierz-827d4`
   - Firestore `firebaseConfigAndroid` MUST also use: `galeria-kazimierz-827d4`
   - **DO NOT** set `firebaseConfigAndroid.projectId` to `development-417611` for this flavor

2. **For `galeriaKazimierzNew` flavor:**
   - Native `google-services.json` uses: `development-417611`
   - Firestore `firebaseConfigAndroid` MUST also use: `development-417611`

**How the app works:**
- The app uses TWO Firebase instances:
  - **DEFAULT** (from google-services.json/plist) - for Messaging
  - **"config"** (from Firestore) - for config fetching only
- **Messaging uses DEFAULT app** (from native config files)
- **Config fetching uses "config" app** (from Firestore)

**Safe changes:**
```javascript
{
  "companyId": "...",     // ✅ Safe to change
  "webviewUrl": "...",    // ✅ Safe to change
  "isLegacy": true/false, // ✅ Safe to change
  "version": 2,          // ✅ Safe to change (REQUIRED when updating)
  "firebaseConfigAndroid": {
    "projectId": "galeria-kazimierz-827d4"  // ⚠️  MUST match google-services.json!
  }
}
```

**If you need to fix firebaseConfigAndroid:**
```bash
# Use the fix script:
node scripts/fix_galeria_kazimierz_firebase_config.js

# Or manually update in Firestore to match google-services.json
```

**Android 13+ (API 33+) Notification Permission:**

On Android 13+, notification permission is automatically requested on app launch. If permission dialog doesn't appear:

1. Check logs: `adb logcat | grep FCM`
2. Verify `POST_NOTIFICATIONS` permission in AndroidManifest.xml (already included)
3. Ensure app targets API 33+ (check `targetSdk` in build.gradle.kts)

---

### Wrong Company Data Appearing

**Symptom:** App shows data from wrong company

**Cause:** `companyId` in Firestore doesn't match expected company

**Solution:**
```bash
# 1. Check current companyId in logs
flutter logs | grep "Loaded companyId"

# Expected: [SecureConfig] Loaded companyId: galeria-kazimierz

# 2. Verify Firestore document
node scripts/verify_firestore_data.js

# 3. Check that companyId matches your backend
# If switching companies, ensure:
# - New database has user data migrated
# - Backend API recognizes new companyId
# - All integrations updated
```

---

## Summary

### What You Can Do

| Action | Time Required | Release Needed? | Version Increment |
|--------|---------------|-----------------|------------------|
| Change WebView URL | ~1 min | ❌ No | ✅ Required |
| Switch UI theme | ~1 min | ❌ No | ✅ Required |
| Change company/database | ~5 min | ❌ No | ✅ Required |
| Update Firebase credentials | ~10 min | ❌ No | ✅ Required |
| Rollback any change | ~1 min | ❌ No | ✅ Required |

**⚠️ Note:** Always increment `version` field when making changes. This ensures users get updates immediately on next app launch without requiring cache clearing or reinstall.

### Quick Reference

**Change configuration:**
```
Firebase Console → development-417611 
→ Firestore → skanuj-wygrywaj 
→ mobile_configs → [document] 
→ Edit fields 
→ ⚠️ Increment version (REQUIRED!)
→ Save
```

**Test changes:**
```bash
./run_flavor.sh galeriaKazimierz android debug
flutter logs | grep "SecureConfig"
```

**Deploy to users:**
```
1. Update Firestore config
2. ⚠️ Increment version field
3. Save
Users get changes on next app launch (automatic refresh).
No app update or cache clearing needed.
```

**Verify version check:**
```bash
adb logcat | grep "SecureConfig.*version"
# Should see: "Newer version available (X > Y), clearing cache and fetching..."
```

---

## Related Documentation

- **[ANDROID_FIREBASE_PROJECT_SWITCH.md](ANDROID_FIREBASE_PROJECT_SWITCH.md)** - **Android-specific: How to switch Firebase projects (explains flavor-specific google-services.json files)**
- **[GOOGLE_SIGNIN_WEB_CLIENT_ID.md](GOOGLE_SIGNIN_WEB_CLIENT_ID.md)** - How to find and verify Google Sign In Web Client ID
- **[FLAVORS_GUIDE.md](FLAVORS_GUIDE.md)** - Complete flavor setup for Android & iOS
- **[FIREBASE_CONFIG.md](FIREBASE_CONFIG.md)** - Firebase projects and credentials management
- **[FCM_TOKEN_TESTING.md](FCM_TOKEN_TESTING.md)** - How to access FCM token in production builds
- **[scripts/README.md](../scripts/README.md)** - Firestore population scripts

## Important Notes

### Version Management

**⚠️ ALWAYS increment version when updating Firestore config:**

- Version increment triggers automatic config refresh
- Users get new config on next app launch (no cache clearing needed)
- Without version increment, changes may take up to 1 hour to appear

### firebaseConfigAndroid Requirements

**⚠️ CRITICAL: firebaseConfigAndroid.projectId MUST match native google-services.json**

- `galeriaKazimierz` flavor → `galeria-kazimierz-827d4`
- `galeriaKazimierzNew` flavor → `development-417611`
- Mismatch causes `DEVELOPER_ERROR` and FCM messages won't arrive

### Android Notification Permission

- On Android 13+ (API 33+), permission is automatically requested on app launch
- Permission dialog appears automatically in release builds
- If permission is denied, FCM messages won't arrive

---

**Questions?** Check the logs and Firebase Console first. Most issues are visible in logs with `[SecureConfig]` prefix.

