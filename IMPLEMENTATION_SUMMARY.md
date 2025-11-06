# Implementation Summary: Legacy and New App Merge

## Overview

Successfully merged the `main` (new app) and `old_system` (legacy app) branches into a unified application that dynamically loads either version based on API configuration.

## What Was Done

### 1. Configuration System ✅

**Created Files:**
- `lib/app_config.dart` - Configuration data model
- `lib/config_service.dart` - API fetch with caching (1-hour TTL)
- `lib/company_mapping.dart` - Maps package ID to company ID

**Features:**
- Fetches config from API: `https://europe-central2-development-417611.cloudfunctions.net/kanuj-wygrywaj-backend/config?company_id={id}`
- Mock response enabled by default (set `_useMockResponse = false` when API is ready)
- Caches config in SharedPreferences with 1-hour TTL
- Background refresh when cache approaches expiry
- Falls back to cached data if API fails
- Ultimate fallback to legacy mode

### 2. Company Identification ✅

**Implementation:**
- Extracts company ID from package identifier (e.g., `pl.a2ti.galeriakazimierz` → `galeria-kazimierz`)
- Supports `--dart-define=COMPANY_ID=xxx` for debugging
- Cached in memory for performance

**Package Mappings:**
```dart
pl.a2ti.galeriakazimierz → galeria-kazimierz
pl.a2ti.kazimierzclub → kazimierz-club
com.cgence.adminpanel.brandcentiv.prod → brand-centiv
```

### 3. Firebase Configuration ✅

**Created Files:**
- `lib/firebase_config_loader.dart` - Dynamic Firebase config loading

**Firebase Configs Bundled:**
- **Legacy (galeria-kazimierz):**
  - Android: `android/app/google-services.json` (default)
  - iOS: `ios/Runner/GoogleService-Info.plist`
  
- **New (development-417611):**
  - Android: `android/app/src/main/assets/google-services-new.json`
  - iOS: `ios/Runner/GoogleService-Info-new.plist`

**Runtime Selection:**
- Firebase project selected based on `AppConfig.firebaseProject`
- Loads appropriate credentials for Android/iOS
- Secure - both configs bundled, selected at runtime

### 4. WebView Integration ✅

**Modified Files:**
- `lib/webview_screen_mobile.dart` - Now accepts `AppConfig`, uses `config.webviewUrl`
- `lib/webview_screen_web.dart` - Now accepts `AppConfig`, dynamic iframe registration

**Features:**
- URL loaded from config
- All existing bridges maintained (Google/Apple/Facebook sign-in, image picker)
- Works for both legacy and new apps

### 5. Main Entry Point ✅

**Modified File:**
- `lib/main.dart`

**Flow:**
1. Fetch app configuration (with cache)
2. Initialize Firebase with correct project
3. Configure backend API based on config
4. Launch app with config

**Backend URL Selection:**
- Legacy: `https://europe-central2-galeria-kazimierz-827d4.cloudfunctions.net/legacy-backend`
- New: `https://europe-central2-development-417611.cloudfunctions.net/kanuj-wygrywaj-backend`

### 6. Dependencies ✅

**Added:**
- `package_info_plus: ^8.0.0` - Read package identifier
- `http: ^1.1.0` - API requests

## How to Use

### Testing with Mock Data

Currently configured to use mock responses. The mock returns:
```json
{
  "webviewUrl": "https://login.2take.it/?company_name={companyId}&legacy=true&d=...",
  "isLegacy": true,
  "firebaseProject": "galeria-kazimierz",
  "backendUrl": "https://europe-central2-galeria-kazimierz-827d4.cloudfunctions.net/legacy-backend"
}
```

### Switching to Real API

In `lib/config_service.dart`, change:
```dart
static const bool _useMockResponse = false;
```

### Testing Different Companies

**Option 1: Use --dart-define**
```bash
flutter run --dart-define=COMPANY_ID=kazimierz-club
```

**Option 2: Change package identifier**
Update `android/app/build.gradle` and `ios/Runner.xcodeproj` package name

### Changing Default App Mode

To change the default from legacy to new:
1. Update the DB records for all companies (set `is_legacy: false`)
2. Or modify the fallback in `config_service.dart`:

```dart
static AppConfig _getDefaultConfig() {
  return AppConfig(
    webviewUrl: 'https://skanuj-staging.web.app?company_name=kazimierz-club-new',
    isLegacy: false,  // Changed from true
    firebaseProject: 'development-417611',  // Changed
    // ...
  );
}
```

### Force Config Refresh

```dart
await ConfigService.clearCache();
final newConfig = await ConfigService.getConfig(forceRefresh: true);
```

## Testing Checklist

- [ ] Test legacy mode (default mock)
- [ ] Test new mode (modify mock to return `isLegacy: false`)
- [ ] Verify Firebase switches correctly
- [ ] Test webview loads correct URL
- [ ] Test push notifications work
- [ ] Test Google/Apple/Facebook sign-in bridges
- [ ] Test image picker
- [ ] Test on iOS and Android
- [ ] Test config caching
- [ ] Test offline fallback

## Architecture Benefits

1. **Safe**: Both Firebase configs bundled, runtime selection
2. **Simple**: Single codebase, controlled by API
3. **Fast**: 1-hour cache, background refresh, instant fallback
4. **Flexible**: Easy to add new companies or toggle modes
5. **Debuggable**: Override company ID with --dart-define

## API Contract

Your backend should implement:

**Endpoint:** `GET /config?company_id={companyId}`

**Response:**
```json
{
  "webviewUrl": "https://example.com?company_name={companyId}&params",
  "isLegacy": true,
  "firebaseProject": "galeria-kazimierz",
  "backendUrl": "https://backend-url.com" // optional
}
```

**Fields:**
- `webviewUrl`: Full URL to load in webview
- `isLegacy`: Boolean - true for old app, false for new
- `firebaseProject`: "galeria-kazimierz" or "development-417611"
- `backendUrl`: (optional) Override backend URL

## Next Steps

1. Implement the API endpoint on your backend
2. Set `_useMockResponse = false` in `config_service.dart`
3. Test with real API
4. Add more companies to `CompanyMapping` if needed
5. Adjust TTL if needed (currently 1 hour)
6. Build different apps with different package identifiers for each company

## Notes

- Firebase background handler uses default config (improvement: could load from cache)
- Web version doesn't use Firebase (as designed)
- Config is fetched on every app start (unless cache is fresh)
- TTL is 1 hour, can be adjusted in `app_config.dart`

