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

## Troubleshooting

**Problem:** Google Sign In fails with "invalid_client"
- **Solution:** Check that Web Client ID matches the Firebase project
- **Solution:** Verify the ID is in Firestore config (`googleSignInWebClientId` field)

**Problem:** Multiple Web Client IDs found
- **Solution:** Use the one from `oauth_client` array (not from `appinvite_service`)
- **Solution:** Usually the first one found is the correct one

**Problem:** No Web Client ID found
- **Solution:** Create one in Google Cloud Console > APIs & Services > Credentials
- **Solution:** Application type must be "Web application"


