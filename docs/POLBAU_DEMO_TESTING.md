# polbau-demo — Run & Testing Checklist

Flavor: `polbauDemo`  
Firestore doc: `mobile_configs/polbau-demo`  
Package (Android): `com.polbau.polbau_demo`  
Bundle ID (iOS): `com.polbau.polbau_demo`

---

## Prerequisites

- [ ] Flutter SDK installed (`flutter doctor` with no critical errors)
- [ ] Firestore doc `polbau-demo` contains:
  - `showSeletorPage: true`
  - `selectorItems` (at least 1 item with `name`, `image`, `logo`, `redirection_url`)
  - `webviewUrl`, `backendUrl`, `companyId`, `version`
- [ ] Access to Firebase project `development-417611`, database `skanuj-wygrywaj`
- [ ] For iOS: Xcode + CocoaPods (`pod install` in `ios/`)

---

## How to Run

### Android (emulator or device)

```bash
# List devices
flutter devices

# Run
flutter run --flavor polbauDemo --dart-define=FLAVOR=polbauDemo

# Or via script
./run_flavor.sh polbauDemo android
```

If there is a package conflict with another flavor, `run_flavor.sh` will uninstall old APKs.

### iOS (simulator)

```bash
flutter devices

flutter run --flavor polbauDemo --dart-define=FLAVOR=polbauDemo

# Or
./run_flavor.sh polbauDemo ios
```

The first run may take several minutes (pod install + Xcode build).

### Debug with forced config refresh

In debug mode, config is refreshed from Firestore:

```bash
flutter run --flavor polbauDemo --dart-define=FLAVOR=polbauDemo
```

To clear the config cache — reinstall the app or clear app data.

### Release build (smoke test)

```bash
# Android
flutter build apk --flavor polbauDemo --dart-define=FLAVOR=polbauDemo --release

# iOS simulator
flutter build ios --flavor polbauDemo --dart-define=FLAVOR=polbauDemo --simulator --debug
```

---

## Checklist: Mall Selector

### General

- [ ] App starts without crash
- [ ] Logs show: `[CompanyMapping] Using company ID from flavor: polbau-demo` (or from Firestore)
- [ ] Screen **"Wybierz swoje / Centrum handlowe"** is displayed
- [ ] All cards from `selectorItems` are shown
- [ ] Each card has: background image, logo, name (uppercase)
- [ ] Placeholder/error when images fail to load — card layout stays intact

### Android

- [ ] Status bar: light icons on dark background
- [ ] Safe area: content not under status bar / gesture navigation bar
- [ ] Ripple effect on card tap
- [ ] Hardware **Back** on selector → exits the app

### iOS

- [ ] Notch / Dynamic Island: title not clipped
- [ ] Home indicator: correct bottom padding
- [ ] List scroll with bounce effect
- [ ] Back gesture on selector → exits app (home screen)

---

## Checklist: WebView After Mall Selection

- [ ] Tap on card → WebView opens
- [ ] URL = selected mall's `redirection_url` (not `webviewUrl`)
- [ ] Log: `[WebViewScreen] Loading ... URL: <redirection_url>`
- [ ] Login / app page loads successfully
- [ ] **Back** (Android) → WebView history, then exit (no return to selector)
- [ ] On iOS after selection, no swipe-back to selector (expected: `pushReplacement`)

Example URL (Ostrovia):

```
https://login.2take.it/?company_name=ch-ostrovia&legacy=true&d=0
```

---

## Checklist: Fallback Without Selector

Verify in Firestore (or temporarily for testing):

- [ ] `showSeletorPage: false` → WebView opens directly with `webviewUrl`
- [ ] `showSeletorPage: true` + empty `selectorItems` → WebView with `webviewUrl`

---

## Checklist: Offline / Cache

- [ ] First launch online → selector visible
- [ ] Close app, enable airplane mode, relaunch
- [ ] Selector shown from SharedPreferences cache
- [ ] Cards offline: placeholder/error on images

---

## Checklist: Login

> Test **after selecting a mall** in WebView. For each method: successful login, error/cancel, re-login after logout.

### Email

- [ ] Login screen has email form (password / magic link — as on web)
- [ ] Valid email + password → successful login, redirect into app
- [ ] Invalid email / wrong password → clear error on page
- [ ] After login, session persists (restart app → still logged in)

### Google

- [ ] Google button opens **native** Google Sign-In (not web popup only)
- [ ] Account selection → successful login
- [ ] Logs: `[WEBVIEW] ... Company (Google Auth): polbau-demo` and `GoogleSignIn initialized`
- [ ] Cancel Google picker → back to login screen, no crash
- [ ] ⚠️ polbau requires entry in `_googleAuthClientIds` + Android OAuth client with SHA-1

### Facebook

- [ ] Facebook button triggers **native** login (`flutter_facebook_auth`)
- [ ] Successful login → token passed to WebView, user logged in
- [ ] Cancel / error → message on page, app does not crash
- [ ] Native App ID: `683312195062841`
- [ ] ⚠️ Android: `facebook_client_token` in `strings.xml` must not be a placeholder

### Phone (SMS / OTP)

- [ ] Phone number login available on login screen
- [ ] Enter number → SMS / OTP sent (or code entry step)
- [ ] Correct code → successful login
- [ ] Wrong code → error, can request again
- [ ] Test on a **real device** (SMS may not work on simulator)

### Apple (iOS, if available on page)

- [ ] Sign in with Apple opens natively
- [ ] Successful login → user in app

---

## Checklist: Receipt Scanning (paragony)

> Test scanning on a **real device** with a camera. iOS Simulator has no camera — gallery fallback only.

### Starting a scan

- [ ] After login, receipt add/scan feature is available (e.g. "Skanuj", "Dodaj paragon")
- [ ] Tap scan → native dialog **Aparat / Camera** and **Galeria / Gallery**
- [ ] Scan logs: `FPK: launching camera` or `FPK: launching gallery`

### Camera

- [ ] **Aparat / Camera** → system camera opens (rear camera)
- [ ] Camera permission requested on first use (iOS + Android)
- [ ] Receipt photo → uploaded to web app, preview / success shown
- [ ] Cancel camera → return without crash, can retry

### Gallery

- [ ] **Galeria / Gallery** → photo picker opens
- [ ] Select receipt photo from gallery → upload / processing in web app
- [ ] Photo library permission (iOS `NSPhotoLibraryUsageDescription`)

### Receipt processing

- [ ] After upload, receipt is recognized / accepted by backend (success UI)
- [ ] Unreadable / invalid photo → server error, can upload again
- [ ] Second receipt scan works

### APP2TI bridge (if web calls directly)

- [ ] `window.APP2TI.startScan()` from WebView opens the same camera/gallery flow
- [ ] `window.APP2TI.startScanForId(id)` — scan bound to id

---

## Checklist: FCM (optional)

- [ ] Push permission prompt (iOS first launch)
- [ ] Secret gesture: 7 quick taps in top-right corner → FCM token dialog
- [ ] Token copies to clipboard

---

## Checklist: Other

- [ ] `tel:` / `mailto:` / `sms:` open system apps
- [ ] No regression: other flavors (`galeriaKazimierz`) start as before

---

## Useful Logs

| Log | Expected |
|-----|----------|
| `[Flavor] Initialized: Moja Galeria (FlavorType.polbauDemo)` | flavor OK |
| `[ConfigService] Fetching secure config for: polbau-demo` | Firestore doc loaded |
| `[WebViewScreen] Loading ... URL:` | correct URL after mall selection |
| `[WEBVIEW] Flavor: ... Company (UI): polbau-demo` | config OK |
| `GoogleSignIn: idToken len=...` | Google login succeeded |
| `flutter_facebook_tokens` / `[NATIVE->WEB][FB]` | Facebook login succeeded |
| `FPK: launching camera` / `FPK: launching gallery` | receipt scan started |

---

## Known Limitations (current version)

1. **iOS `Info.plist`** — shared across all flavors; Google/Facebook IDs may be from galeria
2. **`ios/Runner/polbauDemo/GoogleService-Info.plist`** — replace with plist where `BUNDLE_ID = com.polbau.polbau_demo`
3. **Android `google-services.json`** — needs real `appId` + OAuth client for `com.polbau.polbau_demo`
4. **Dart `_googleAuthClientIds`** — add `'polbau-demo'` for correct Google Auth
5. **Facebook Android token** — `REPLACE_WITH_CLIENT_TOKEN` in `strings.xml`

---

## Quick Commands (copy-paste)

```bash
# Android
flutter run --flavor polbauDemo --dart-define=FLAVOR=polbauDemo

# iOS
flutter run --flavor polbauDemo --dart-define=FLAVOR=polbauDemo
```
