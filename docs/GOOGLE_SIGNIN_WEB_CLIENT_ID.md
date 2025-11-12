# How to Find and Verify Google Sign In Web Client ID

## Quick Method: Use the Script

```bash
# For new app (development-417611)
node scripts/find_web_client_id.js android/app/src/galeriaKazimierzNew/google-services.json

# For legacy app (galeria-kazimierz-827d4)
node scripts/find_web_client_id.js android/app/src/galeriaKazimierz/google-services.json
```

## Manual Method: From google-services.json

1. Open `google-services.json` for your flavor
2. Search for `"client_type": 3` - this is the Web Client ID
3. Look in:
   - `oauth_client` array (direct Web client)
   - `services.appinvite_service.other_platform_oauth_client` (shared Web client)

**Example:**
```json
{
  "oauth_client": [
    {
      "client_id": "159120615271-s2fbutrvvgk39rq71fafmeadksmk4g4d.apps.googleusercontent.com",
      "client_type": 3  // ← This is Web Client ID
    }
  ]
}
```

## From Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (`development-417611` or `galeria-kazimierz-827d4`)
3. Go to **Project Settings** (gear icon)
4. Scroll to **Your apps** section
5. Click on your app
6. Download `google-services.json`
7. Use the script above to extract Web Client ID

## From Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Navigate to **APIs & Services** > **Credentials**
4. Look for **OAuth 2.0 Client IDs**
5. Find the one with **Application type: Web application**
6. Copy the **Client ID**

## Verify It's Correct

The Web Client ID should:
- ✅ Start with your project number (e.g., `159120615271-` or `839029981684-`)
- ✅ End with `.apps.googleusercontent.com`
- ✅ Have `client_type: 3` in `google-services.json`
- ✅ Work when used in `GoogleSignIn(serverClientId: '...')`

## Current Values

### development-417611 (kazimierz-club-new)
```
159120615271-s2fbutrvvgk39rq71fafmeadksmk4g4d.apps.googleusercontent.com
```

### galeria-kazimierz-827d4 (galeria-kazimierz)
```
839029981684-v8su4cmc72t498k2evmejnohi0pk7v3c.apps.googleusercontent.com
```

## Update Firestore Config

After finding the correct Web Client ID, update it in:
1. `scripts/populate_firestore_config.js` - for initial population
2. Run `node scripts/populate_firestore_config.js` to update Firestore
3. Or manually update in Firebase Console > Firestore > `mobile_configs` collection

## Current Implementation (Updated)

### Static Mapping Approach

Google Sign-In now uses a **static mapping** in Dart code rather than dynamic Firestore configuration:

**Location:** `lib/webview_screen_mobile.dart`

```dart
const Map<String, String> _googleAuthClientIds = {
  'galeria-kazimierz': '839029981684-v8su4cmc72t498k2evmejnohi0pk7v3c.apps.googleusercontent.com',
  'kazimierz-club-new': '159120615271-s2fbutrvvgk39rq71fafmeadksmk4g4d.apps.googleusercontent.com',
  // Add new companies here as needed
};
```

### Selection Logic

The app determines which Web Client ID to use based on this priority:

1. **`googleAuthCompanyId` from Firestore** (if explicitly set in config)
2. **Flavor-based fallback** (e.g., `galeriaKazimierz` flavor → `galeria-kazimierz`)
3. **`companyId` from Firestore config** (for other flavors)

### Why Static Mapping?

- ✅ **Avoids SHA-1 conflicts**: Different companies can use different Firebase projects
- ✅ **Simplifies configuration**: No need to update Firestore for Google Auth changes
- ✅ **Consistent behavior**: Google Auth project is determined at compile time
- ✅ **Flexible**: Each company can have its own Firebase project for Google Auth

### Platform Requirements

**Android:**
- Requires Android OAuth Client (`client_type: 1`) with SHA-1 fingerprints
- Must be present in `google-services.json` for the flavor
- Package name must match `applicationId` in `build.gradle.kts`

**iOS:**
- Requires iOS OAuth Client (`client_type: 2`) with Bundle ID
- Must be configured in Firebase project
- Bundle ID must match Xcode project settings

**Web:**
- Uses Web OAuth Client (`client_type: 3`) for `serverClientId`
- Configured in Firebase project → Project Settings → Your apps

### Adding New Companies

1. **Add to static mapping:**
   ```dart
   const Map<String, String> _googleAuthClientIds = {
     // ... existing entries ...
     'new-company-id': 'PROJECT_NUMBER-CLIENT_ID.apps.googleusercontent.com',
   };
   ```

2. **Configure Firebase project:**
   - Add Android app with correct package name and SHA-1 fingerprints
   - Add iOS app with correct Bundle ID
   - Download updated `google-services.json` / `GoogleService-Info.plist`

3. **Update native configs:**
   - Replace `google-services.json` for the flavor
   - Replace `GoogleService-Info.plist` for the flavor

4. **Optional Firestore override:**
   - Set `googleAuthCompanyId` in Firestore config if you want explicit control

## Troubleshooting

**Problem:** Google Sign In fails with "invalid_client"
- **Solution:** Check that Web Client ID matches the Firebase project
- **Solution:** Verify the ID is in the static mapping (`_googleAuthClientIds`)
- **Solution:** Ensure `companyId` matches the key in the mapping

**Problem:** Android shows `DEVELOPER_ERROR` (ApiException: 10)
- **Solution:** Verify Android OAuth Client exists in Firebase project
- **Solution:** Check SHA-1 fingerprints are added for the package name
- **Solution:** Ensure `google-services.json` contains the Android OAuth Client (`client_type: 1`)
- **Solution:** Verify `applicationId` in `build.gradle.kts` matches `package_name` in `google-services.json`

**Problem:** iOS Google Sign-In fails
- **Solution:** Verify iOS OAuth Client exists in Firebase project
- **Solution:** Check Bundle ID matches Xcode project settings
- **Solution:** Ensure `GoogleService-Info.plist` contains correct `CLIENT_ID`
- **Solution:** Verify `Info.plist` has correct `GIDClientID` and `CFBundleURLSchemes`

**Problem:** Multiple Web Client IDs found
- **Solution:** Use the one from `oauth_client` array (not from `appinvite_service`)
- **Solution:** Usually the first one found is the correct one

**Problem:** No Web Client ID found
- **Solution:** Create one in Google Cloud Console > APIs & Services > Credentials
- **Solution:** Application type must be "Web application"

**Problem:** Google Auth works for one flavor but not another
- **Solution:** Check that each flavor has correct `google-services.json` / `GoogleService-Info.plist`
- **Solution:** Verify `applicationId` / Bundle ID matches the Firebase app configuration
- **Solution:** Ensure Android OAuth Client exists for each package name


