# Scripts

This directory contains utility scripts for managing the Flutter application.

## Quick Start

For a quick guide on switching between old and new app configurations, see **[QUICK_GUIDE.md](QUICK_GUIDE.md)**.

## populate_firestore_config.js

Populates the Firestore `mobile_configs` collection with secure configuration data for both flavors.

### Prerequisites

1. **Install Node.js and npm** (if not already installed)

   ```bash
   brew install node  # macOS
   ```

2. **Install Firebase Admin SDK**

   ```bash
   npm install firebase-admin
   ```

3. **Authenticate with Firebase**

   Option A - Using gcloud (recommended):

   ```bash
   gcloud auth application-default login
   ```

   Option B - Using service account:

   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
   ```

### Usage

```bash
# Run the script
node scripts/populate_firestore_config.js
```

Or without installing dependencies globally:

```bash
npx -y firebase-admin && node scripts/populate_firestore_config.js
```

### What It Does

1. Initializes Firebase Admin SDK with `skanuj-wygrywaj` project
2. Creates/updates documents in `mobile_configs` collection:
   - `galeria-kazimierz` - Legacy flavor configuration
   - `kazimierz-club-new` - New flavor configuration
3. Each document contains:
   - Firebase configuration (Android & iOS)
   - Webview URL with auth tokens
   - Backend URL
   - Legacy mode flag
   - Version number

### Expected Output

```
✓ Firebase Admin SDK initialized

📝 Populating Firestore with app configurations...

✓ Created/Updated config for: galeria-kazimierz
  - Firebase Project: galeria-kazimierz-827d4
  - Legacy Mode: true
  - Version: 1

✓ Created/Updated config for: kazimierz-club-new
  - Firebase Project: skanuj-wygrywaj
  - Legacy Mode: false
  - Version: 1

✅ All configurations populated successfully!

Next steps:
  1. Configure Firestore security rules (see docs/FIRESTORE_CONFIG_SETUP.md)
  2. Enable App Check in Firebase Console
  3. Test the app with: flutter run --dart-define=FLAVOR=galeriaKazimierz
```

### Troubleshooting

**Error: "Failed to initialize Firebase Admin SDK"**

- Make sure you're authenticated with `gcloud auth application-default login`
- Or set `GOOGLE_APPLICATION_CREDENTIALS` environment variable

**Error: "Cannot find module 'firebase-admin'"**

- Run `npm install firebase-admin` first

**Error: "Missing or insufficient permissions"**

- Ensure your account has Firestore write permissions in the `skanuj-wygrywaj` project
- Check IAM roles in Firebase Console

### Updating Configurations

**⚠️ CRITICAL: Always increment version when updating configs**

To update an existing configuration:

1. Edit the `configs` object in `populate_firestore_config.js`
2. **⚠️ REQUIRED**: Increment the `version` field - this triggers automatic config refresh
3. **⚠️ IMPORTANT**: Ensure `firebaseConfigAndroid.projectId` matches native `google-services.json`:
   - `galeriaKazimierz` flavor → `galeria-kazimierz-827d4`
   - `galeriaKazimierzNew` flavor → `development-417611`
4. Run the script again

Example:

```javascript
'galeria-kazimierz': {
  firebaseConfig: {
    android: {
      // ⚠️ CRITICAL: Must match google-services.json!
      projectId: 'galeria-kazimierz-827d4',
      // ... other fields from google-services.json
    }
  },
  webviewUrl: 'https://new-url.example.com',
  firebaseProject: 'galeria-kazimierz-827d4',  // Must match android projectId
  version: 2  // ⚠️ REQUIRED: Incremented from 1
}
```

**Why version is critical:**
- App caches configuration locally for performance
- When version is incremented, app automatically detects change
- Users get new config on next app launch (no cache clearing needed)
- Without version increment, changes may take up to 1 hour to appear

### Available Scripts

- **`populate_firestore_config.js`** - Populate/update all configurations
- **`update_single_config.js`** - Update single config (galeria-kazimierz) to new app config
- **`rollback_to_old_config.js`** - Rollback galeria-kazimierz to old/legacy config
- **`verify_firestore_data.js`** - Verify configurations in Firestore
- **`fix_galeria_kazimierz_firebase_config.js`** - Fix firebaseConfigAndroid to match google-services.json

**All scripts support:**
- Service account key authentication (`scripts/firebase-service-account.json`)
- gcloud auth fallback (`gcloud auth application-default login`)

### Security Note

This script contains sensitive configuration data. Do not share or commit service account keys. The script itself is safe to commit as it only contains the same data that will be in Firestore.

## Adding More Scripts

When adding new scripts to this directory:

1. Use meaningful names (e.g., `migrate_users.js`, `cleanup_cache.js`)
2. Add documentation in this README
3. Include error handling and clear output messages
4. Add a shebang line for direct execution: `#!/usr/bin/env node`
5. Make executable: `chmod +x scripts/your_script.js`
