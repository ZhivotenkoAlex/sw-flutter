# 🔥 Firebase Configuration Guide

Complete guide for managing Firebase configurations in this project.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Firebase Projects](#firebase-projects)
- [Configuration Files](#configuration-files)
- [Updating Configs](#updating-configs)
- [Firestore Setup](#firestore-setup)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

This app uses a **Dual Firebase App** system:

```
┌─────────────────────────────────────────┐
│  TWO Firebase Apps Running Simultaneously│
├─────────────────────────────────────────┤
│                                          │
│  1. DEFAULT App                          │
│     • Purpose: Firebase Messaging        │
│     • Source: plist/google-services.json │
│     • Project: Flavor-specific           │
│                                          │
│  2. NAMED "config" App                   │
│     • Purpose: Firestore config fetching │
│     • Source: Dart code (bootstrap)      │
│     • Project: Always development-417611 │
│                                          │
└─────────────────────────────────────────┘
```

### Why Two Apps?

**Problem:** Different flavors need different Firebase Messaging projects, but configs should be centralized.

**Solution:**

- **DEFAULT app** handles Messaging (flavor-specific)
- **"config" app** fetches configs (centralized database)

---

## Firebase Projects

### **galeria-kazimierz-827d4** (Legacy Project)

|                          |                                   |
| ------------------------ | --------------------------------- |
| **Used by**              | galeriaKazimierz flavor           |
| **Purpose**              | Firebase Messaging for legacy app |
| **Package ID (Android)** | `pl.a2ti.galeriakazimierz`        |
| **Bundle ID (iOS)**      | `it.2take.galeriakazimierz`       |
| **Sender ID**            | `839029981684`                    |

### **development-417611** (New Project)

|                          |                                                  |
| ------------------------ | ------------------------------------------------ |
| **Used by**              | galeriaKazimierzNew flavor + ALL config fetching |
| **Purpose**              | Firebase Messaging + Firestore configs           |
| **Database**             | `skanuj-wygrywaj` (named database)               |
| **Package ID (Android)** | `com.skanujwygrywaj.skanuj_wygrywaj`             |
| **Bundle ID (iOS)**      | `com.skanujwygrywaj.skanujWygrywaj`              |
| **Sender ID**            | `159120615271`                                   |

---

## Configuration Files

### Android: google-services.json

**Location:**

```
android/app/src/
├── galeriaKazimierz/google-services.json         # galeria-kazimierz-827d4
└── galeriaKazimierzNew/google-services.json      # development-417611
```

**How to get:**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project (galeria-kazimierz-827d4 or development-417611)
3. Project Settings → Your apps → Select Android app
4. Download `google-services.json`
5. Place in correct flavor directory

**Important fields to verify:**

```json
{
  "project_info": {
    "project_id": "galeria-kazimierz-827d4", // Must match
    "firebase_url": "https://...",
    "project_number": "839029981684" // Sender ID
  },
  "client": [
    {
      "client_info": {
        "android_client_info": {
          "package_name": "pl.a2ti.galeriakazimierz" // Must match build.gradle
        }
      }
    }
  ]
}
```

### iOS: GoogleService-Info.plist

**Location:**

```
ios/Runner/
├── galeriaKazimierz/GoogleService-Info.plist     # galeria-kazimierz-827d4
└── galeriaKazimierzNew/GoogleService-Info.plist  # development-417611
```

**How to get:**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project
3. Project Settings → Your apps → Select iOS app
4. Download `GoogleService-Info.plist`
5. Place in correct flavor directory

**Important fields to verify:**

```xml
<key>PROJECT_ID</key>
<string>galeria-kazimierz-827d4</string>  <!-- Must match -->

<key>BUNDLE_ID</key>
<string>it.2take.galeriakazimierz</string>  <!-- Must match Xcode -->

<key>GCM_SENDER_ID</key>
<string>839029981684</string>  <!-- Sender ID -->

<key>API_KEY</key>
<string>AIzaSy...</string>  <!-- iOS-specific key -->
```

### Bootstrap Config (Dart)

**Location:** `lib/firebase_config_loader.dart`

**Purpose:** Provides minimal config for initial Firebase connection (development-417611)

```dart
static FirebaseOptions getBootstrapOptions() {
  if (Platform.isIOS) {
    return const FirebaseOptions(
      apiKey: 'AIzaSyDxIO20bhKa3y5YLfcuZtv2b5qxaPSW_NM',  // iOS key
      appId: '1:159120615271:ios:2ba734d4e96baccf74f1c2',
      messagingSenderId: '159120615271',
      projectId: 'development-417611',
      // ...
    );
  } else {
    return const FirebaseOptions(
      apiKey: 'AIzaSyClPTttdsqmbC68z9HxQsWehxcf0Vhb50M',  // Android key
      appId: '1:159120615271:android:8e46a63c1ab6102f74f1c2',
      messagingSenderId: '159120615271',
      projectId: 'development-417611',
      // ...
    );
  }
}
```

**When to update:**

- When changing Firebase project for config fetching
- When rotating API keys
- Never needs updating if staying with development-417611

---

## Updating Configs

### Scenario 1: Update Firebase Messaging for a Flavor

**Example:** New Firebase API key for galeriaKazimierz

1. **Get new config from Firebase Console:**

   - Download `google-services.json` (Android)
   - Download `GoogleService-Info.plist` (iOS)

2. **Replace old files:**

   ```bash
   # Android
   cp ~/Downloads/google-services.json android/app/src/galeriaKazimierz/

   # iOS
   cp ~/Downloads/GoogleService-Info.plist ios/Runner/galeriaKazimierz/
   ```

3. **Verify package/bundle IDs match:**

   ```bash
   # Android
   grep "package_name" android/app/src/galeriaKazimierz/google-services.json
   # Should show: pl.a2ti.galeriakazimierz

   # iOS
   grep "BUNDLE_ID" ios/Runner/galeriaKazimierz/GoogleService-Info.plist
   # Should show: it.2take.galeriakazimierz
   ```

4. **Test:**
   ```bash
   ./run_flavor.sh galeriaKazimierz android
   ./run_flavor.sh galeriaKazimierz ios
   ```

### Scenario 2: Update Firestore Configs

**Example:** Change webview URL or update Firebase credentials stored in Firestore

1. **Edit config script:**

   File: `scripts/populate_firestore_config.js`

   ```javascript
   const configs = {
     "galeria-kazimierz": {
       firebaseConfig: {
         android: {
           apiKey: "your-new-key", // Update this
           // ... other fields
         },
         ios: {
           apiKey: "your-new-key", // Update this
           // ... other fields
         },
       },
       webviewUrl: "https://new-url.com", // Update this
       isLegacy: true,
       firebaseProject: "galeria-kazimierz-827d4",
       version: 2, // Increment version!
     },
   }
   ```

2. **Run population script:**

   ```bash
   cd scripts
   npm install  # First time only
   node populate_firestore_config.js
   ```

3. **Verify update:**

   ```bash
   node verify_firestore_data.js
   ```

4. **Test app:**

   ```bash
   # Force config refresh (debug mode)
   ./run_flavor.sh galeriaKazimierz android debug

   # Check logs
   flutter logs | grep "SecureConfig"
   # Should see: "Config fetched successfully"
   ```

### Scenario 3: Add New Flavor with Firebase

**Complete setup for new flavor "newCompany"**

#### A. Create Firebase Projects

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create new project (or use existing development-417611)
3. Add Android app with package: `com.newcompany.app`
4. Add iOS app with bundle: `com.newcompany.app`
5. Download `google-services.json` and `GoogleService-Info.plist`

#### B. Add to Android

1. **Create flavor directory:**

   ```bash
   mkdir -p android/app/src/newCompany
   ```

2. **Add google-services.json:**

   ```bash
   cp ~/Downloads/google-services.json android/app/src/newCompany/
   ```

3. **Update build.gradle.kts:**
   ```kotlin
   productFlavors {
       create("newCompany") {
           dimension = "company"
           applicationId = "com.newcompany.app"
           resValue("string", "app_name", "New Company")
       }
   }
   ```

#### C. Add to iOS

1. **Create flavor directory:**

   ```bash
   mkdir -p ios/Runner/newCompany
   ```

2. **Add GoogleService-Info.plist:**

   ```bash
   cp ~/Downloads/GoogleService-Info.plist ios/Runner/newCompany/
   ```

3. **In Xcode:**
   - Create build configurations: Debug-newCompany, Release-newCompany, Profile-newCompany
   - Create scheme: newCompany
   - Set bundle ID: com.newcompany.app
   - Add plist to project (right-click → Add Files)

#### D. Add to Firestore

1. **Edit `scripts/populate_firestore_config.js`:**

   ```javascript
   const configs = {
     "new-company-id": {
       firebaseConfig: {
         android: {
           /* from google-services.json */
         },
         ios: {
           /* from GoogleService-Info.plist */
         },
       },
       webviewUrl: "https://newcompany.com",
       isLegacy: false,
       firebaseProject: "development-417611",
       version: 1,
     },
   }
   ```

2. **Run script:**
   ```bash
   cd scripts
   node populate_firestore_config.js
   ```

#### E. Update Dart Code

File: `lib/flavor_config.dart`

```dart
enum FlavorType {
  galeriaKazimierz,
  galeriaKazimierzNew,
  newCompany,  // Add here
}
```

File: `lib/company_mapping.dart`

```dart
const Map<String, String> packageMappings = {
  // ... existing ...
  'com.newcompany.app': 'new-company-id',
};
```

#### F. Test

```bash
./run_flavor.sh newCompany android
./run_flavor.sh newCompany ios
```

---

## Firestore Setup

### Database Structure

```
Firebase Project: development-417611
  └─ Database: skanuj-wygrywaj (named database)
      └─ Collection: mobile_configs
          ├─ galeria-kazimierz (document)
          │   ├── firebaseConfigAndroid: {...}
          │   ├── firebaseConfigIOS: {...}
          │   ├── webviewUrl: "https://..."
          │   ├── isLegacy: true
          │   ├── firebaseProject: "galeria-kazimierz-827d4"
          │   └── version: 1
          │
          └─ kazimierz-club-new (document)
              ├── firebaseConfigAndroid: {...}
              ├── firebaseConfigIOS: {...}
              ├── webviewUrl: "https://..."
              ├── isLegacy: false
              ├── firebaseProject: "development-417611"
              └── version: 1
```

### Populate Firestore

**Prerequisites:**

```bash
# Install Node.js dependencies
cd scripts
npm install firebase-admin

# Authenticate with Google Cloud
gcloud auth application-default login
```

**Run population script:**

```bash
node populate_firestore_config.js
```

**Output:**

```
🔥 Firebase Admin SDK initialized
📍 Project: development-417611
✓ Using Firestore database: skanuj-wygrywaj

📝 Processing galeria-kazimierz...
✅ Config for galeria-kazimierz written successfully

📝 Processing kazimierz-club-new...
✅ Config for kazimierz-club-new written successfully

🎉 All configs populated successfully!
```

### Verify Data

```bash
node verify_firestore_data.js
```

**Output:**

```
🔍 Verifying galeria-kazimierz...
✅ Document exists
✅ firebaseConfigAndroid present
✅ firebaseConfigIOS present
✅ webviewUrl: https://login.2take.it/...
✅ isLegacy: true
✅ firebaseProject: galeria-kazimierz-827d4

🔍 Verifying kazimierz-club-new...
✅ Document exists
✅ All fields present
```

---

## Troubleshooting

### ❌ "Firebase initialization failed"

**Check 1: Config files exist**

```bash
ls -la android/app/src/*/google-services.json
ls -la ios/Runner/*/GoogleService-Info.plist
```

**Check 2: Package IDs match**

```bash
# Android
grep "package_name" android/app/src/*/google-services.json

# iOS
grep "BUNDLE_ID" ios/Runner/*/GoogleService-Info.plist

# build.gradle
grep "applicationId" android/app/build.gradle.kts
```

**Check 3: Firebase project matches**

```bash
# Android
grep "project_id" android/app/src/galeriaKazimierz/google-services.json

# iOS
grep "PROJECT_ID" ios/Runner/galeriaKazimierz/GoogleService-Info.plist
```

### ❌ "Config not found in Firestore"

**Check 1: Firestore has data**

```bash
cd scripts
node verify_firestore_data.js
```

**Check 2: Company ID matches**

```dart
// In flavor_config.dart
companyId: 'galeria-kazimierz',  // Must match Firestore document ID
```

**Check 3: Database name**

```javascript
// In populate_firestore_config.js
db.settings({
  databaseId: "skanuj-wygrywaj", // Must match this exact name
})
```

### ❌ "Permission denied" (Firestore)

**Solution:**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select development-417611 project
3. Firestore Database → Rules
4. Ensure rules allow authenticated access:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /mobile_configs/{document} {
      allow read: if request.auth != null || request.app != null;
      allow write: if false;  // Only write via Admin SDK
    }
  }
}
```

### ❌ "App Check token validation failed"

**Solution:**

1. Go to Firebase Console → App Check
2. Register apps:
   - Android: Enable Play Integrity
   - iOS: Enable Device Check
3. For debug builds, add debug token:

   ```bash
   # Get debug token from logs
   flutter run | grep "App Check"

   # Add token in Firebase Console → App Check → Apps → Debug tokens
   ```

---

## Best Practices

### ✅ DO

- Keep API keys in platform-specific config files (plist/json)
- Use bootstrap config for centralized Firestore access
- Increment `version` in Firestore when updating configs
- Test both Android and iOS after config changes
- Use named database (`skanuj-wygrywaj`) for organization

### ❌ DON'T

- Don't hardcode API keys in Dart source code
- Don't commit production Firebase configs if they contain sensitive data
- Don't use same Firebase project for all flavors (Messaging)
- Don't forget to update both plist AND Firestore when changing credentials
- Don't mix up package IDs between flavors

---

## Security Checklist

✅ **No hardcoded credentials in source code**  
✅ **Firebase App Check enabled**  
✅ **Firestore rules prevent unauthorized writes**  
✅ **Platform-specific API keys used**  
✅ **Named database for organizational security**  
✅ **Configs cached locally with expiration**  
✅ **No authentication tokens in URLs**

---

## Summary

**Key Points:**

- **Two Firebase apps**: DEFAULT (Messaging) + "config" (Firestore)
- **Config files**: google-services.json (Android), GoogleService-Info.plist (iOS)
- **Firestore**: Centralized configs in development-417611/skanuj-wygrywaj
- **Scripts**: Use Node.js scripts to populate/verify Firestore data

**When updating:**

1. Update plist/json for Messaging changes
2. Update Firestore for dynamic config changes
3. Always test both platforms
4. Verify with verify script

---

For more information:

- [README.md](../README.md) - Project overview
- [FLAVORS_GUIDE.md](FLAVORS_GUIDE.md) - Flavor setup guide
- [Firebase Console](https://console.firebase.google.com/)
