# Logging Documentation

This document provides a comprehensive guide to all custom debugging logs in the application, organized by feature. Use this documentation to understand log messages, troubleshoot issues, and debug the application effectively.

## Table of Contents

1. [Firebase Cloud Messaging (FCM)](#firebase-cloud-messaging-fcm)
2. [Configuration Service](#configuration-service)
3. [File Picker](#file-picker)
4. [WebView Bridge Handlers](#webview-bridge-handlers)
5. [Authentication](#authentication)
6. [JavaScript Console Logs](#javascript-console-logs)
7. [Secret Gesture](#secret-gesture)
8. [Troubleshooting Guide](#troubleshooting-guide)

---

## Firebase Cloud Messaging (FCM)

### Token Operations

#### `[FCM] Token obtained: length={length}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Successfully obtained FCM token during initialization or refresh
- **Example Values**:
  - `[FCM] Token obtained: length=152`
  - `[FCM] Token obtained: length=163`
- **Possible Reasons**:
  - Normal operation - token successfully retrieved from Firebase
  - Token refresh completed successfully
- **Debugging Usage**:
  - Verify token length is reasonable (typically 150-170 characters)
  - Check if token appears after app initialization
  - Use token length to confirm token refresh occurred

#### `[FCM] Token is null - permission may be denied`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Attempted to get FCM token but received null (typically on Android 13+)
- **Example Values**:
  - `[FCM] Token is null - permission may be denied`
- **Possible Reasons**:
  - User denied notification permission on Android 13+ (API 33+)
  - Permission dialog was dismissed without granting
  - Firebase initialization issue
- **Debugging Usage**:
  - Check permission status logs that follow
  - Verify user granted notification permission in system settings
  - Check if permission request dialog appeared

#### `[FCM] Failed to get token: {error}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Exception occurred while trying to get FCM token
- **Example Values**:
  - `[FCM] Failed to get token: PlatformException(..., ...)`
  - `[FCM] Failed to get token: FirebaseException(...)`
- **Possible Reasons**:
  - Firebase not properly initialized
  - Network connectivity issues
  - Firebase project configuration mismatch
  - Google Play Services not available (Android)
- **Debugging Usage**:
  - Check Firebase initialization logs
  - Verify `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is correct
  - Check network connectivity
  - Verify Firebase project configuration

#### `[FCM] getToken error: {error}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Error during token retrieval in `_awaitFcmToken` method
- **Example Values**:
  - `[FCM] getToken error: PlatformException(...)`
- **Possible Reasons**:
  - Same as "Failed to get token" above
  - Token refresh timeout
- **Debugging Usage**:
  - Check if this appears after initial token fetch
  - Verify Firebase configuration

### Permission Operations

#### `[FCM] Current permission status: {status}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Checking notification permission status before requesting
- **Example Values**:
  - `[FCM] Current permission status: AuthorizationStatus.authorized`
  - `[FCM] Current permission status: AuthorizationStatus.notDetermined`
  - `[FCM] Current permission status: AuthorizationStatus.denied`
  - `[FCM] Current permission status: AuthorizationStatus.provisional`
- **Possible Reasons**:
  - Normal check during initialization
  - Permission check before token request
- **Debugging Usage**:
  - Understand current permission state
  - Determine if permission request is needed
  - Track permission changes over time

#### `[FCM] Permission already granted`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Permission check found permission already granted (authorized or provisional)
- **Example Values**:
  - `[FCM] Permission already granted`
- **Possible Reasons**:
  - User previously granted permission
  - App reinstalled but permission persisted
- **Debugging Usage**:
  - Confirm permission flow is working
  - Verify token should be available

#### `[FCM] Requesting notification permission on Android...`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: About to request notification permission on Android 13+ (API 33+)
- **Example Values**:
  - `[FCM] Requesting notification permission on Android...`
- **Possible Reasons**:
  - Permission not yet granted
  - First time app launch on Android 13+
- **Debugging Usage**:
  - Confirm permission dialog should appear
  - Track permission request flow

#### `[FCM] Permission request result: {status} (granted: {true/false})`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: After requesting notification permission (Android or iOS)
- **Example Values**:
  - `[FCM] Permission request result: AuthorizationStatus.authorized (granted: true)`
  - `[FCM] Permission request result: AuthorizationStatus.denied (granted: false)`
  - `[FCM] Permission request result: AuthorizationStatus.provisional (granted: true)`
- **Possible Reasons**:
  - User responded to permission dialog
  - Permission request completed
- **Debugging Usage**:
  - Verify permission request outcome
  - Understand why token might be null
  - Track user permission decisions

#### `[FCM] Requesting notification permission on iOS...`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: About to request notification permission on iOS when status is `notDetermined`
- **Example Values**:
  - `[FCM] Requesting notification permission on iOS...`
- **Possible Reasons**:
  - First time app launch on iOS
  - Permission never requested before
- **Debugging Usage**:
  - Confirm iOS permission dialog should appear
  - Track iOS permission flow

#### `[FCM] Permission denied on iOS - user must enable in Settings`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Permission check found status is `denied` on iOS
- **Example Values**:
  - `[FCM] Permission denied on iOS - user must enable in Settings`
- **Possible Reasons**:
  - User denied permission previously
  - User needs to enable in iOS Settings app
- **Debugging Usage**:
  - Inform user they need to enable in Settings
  - Understand why token is unavailable
  - Track permission denial cases

#### `[FCM] Permission check error: {error}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Exception occurred during permission check
- **Example Values**:
  - `[FCM] Permission check error: PlatformException(...)`
- **Possible Reasons**:
  - Firebase messaging instance issue
  - Platform-specific permission API error
- **Debugging Usage**:
  - Check Firebase initialization
  - Verify platform-specific permission APIs

#### `[FCM] requestNotificationsPermission error: {error}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Error in public `requestNotificationsPermission` method
- **Example Values**:
  - `[FCM] requestNotificationsPermission error: ...`
- **Possible Reasons**:
  - Permission request failed
  - Firebase messaging instance issue
- **Debugging Usage**:
  - Debug manual permission requests (e.g., from settings screen)
  - Verify permission request flow

### Message Handling

#### `[FCM] ✅ Message received: "{title}" / "{body}" (from: {from}, id: {id})`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: FCM message received while app is in foreground
- **Example Values**:
  - `[FCM] ✅ Message received: "Test Notification" / "Hello World" (from: 839029981684, id: 0:1234567890)`
  - `[FCM] ✅ Message received: "" / "Body only" (from: null, id: null)`
- **Possible Reasons**:
  - Normal operation - push notification received
  - Test message sent from backend
- **Debugging Usage**:
  - Verify push notifications are working
  - Check message content and metadata
  - Debug notification delivery issues
  - Track message IDs for debugging

#### `[FCM] ❌ onMessage ERROR: {error}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Exception occurred while processing foreground message
- **Example Values**:
  - `[FCM] ❌ onMessage ERROR: FormatException(...)`
- **Possible Reasons**:
  - Message payload parsing error
  - Handler code exception
- **Debugging Usage**:
  - Debug message processing issues
  - Check message payload format
  - Fix handler code errors

#### `[FCM][bg] ✅ Background message: "{title}" / "{body}" (from: {from})`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: FCM message received while app is in background (background handler)
- **Example Values**:
  - `[FCM][bg] ✅ Background message: "Background Test" / "App was closed" (from: 839029981684)`
- **Possible Reasons**:
  - Normal operation - background notification received
  - App was closed or in background
- **Debugging Usage**:
  - Verify background message delivery
  - Check if background handler is working
  - Debug background notification issues
  - Note: iOS requires `content-available: 1` in payload for background data messages

#### `[FCM][bg] Firebase init error: {error}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Error initializing Firebase in background handler isolate
- **Example Values**:
  - `[FCM][bg] Firebase init error: FirebaseException(...)`
- **Possible Reasons**:
  - Firebase options not saved properly
  - Background isolate initialization issue
- **Debugging Usage**:
  - Check background handler initialization
  - Verify Firebase options persistence
  - Debug background isolate issues

### Package Information

#### `[FCM] Failed to get package ID: {error}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Error getting package name/bundle ID for token registration
- **Example Values**:
  - `[FCM] Failed to get package ID: PlatformException(...)`
- **Possible Reasons**:
  - PackageInfo plugin issue
  - Platform-specific error
- **Debugging Usage**:
  - Check PackageInfo plugin configuration
  - Verify package name is set correctly

### 2Take.it Loyalty Integration

#### `[2TAKE] ERROR: HTTP {statusCode}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: HTTP error when saving token to 2take.it loyalty service
- **Example Values**:
  - `[2TAKE] ERROR: HTTP 404`
  - `[2TAKE] ERROR: HTTP 500`
- **Possible Reasons**:
  - Invalid company ID
  - 2take.it service unavailable
  - Network error
- **Debugging Usage**:
  - Check company ID format
  - Verify 2take.it service availability
  - Debug network connectivity

---

## Configuration Service

### Config Fetching

#### `[ConfigService] Fetching secure config for: {companyId}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Starting to fetch configuration from Firestore
- **Example Values**:
  - `[ConfigService] Fetching secure config for: galeria-kazimierz`
  - `[ConfigService] Fetching secure config for: kazimierz-club-new`
- **Possible Reasons**:
  - App initialization
  - Config refresh requested
- **Debugging Usage**:
  - Verify correct company ID is being used
  - Track config fetch operations
  - Debug company ID resolution

#### `[ConfigService] Error fetching secure config: {error}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Exception occurred while fetching config from Firestore
- **Example Values**:
  - `[ConfigService] Error fetching secure config: FirebaseException(...)`
  - `[ConfigService] Error fetching secure config: TimeoutException(...)`
- **Possible Reasons**:
  - Firestore connection issue
  - Company ID not found in Firestore
  - Network connectivity problem
  - Firestore permissions issue
- **Debugging Usage**:
  - Check Firestore connectivity
  - Verify company ID exists in `mobile_configs` collection
  - Check Firestore security rules
  - Debug network issues

#### `[ConfigService] Using legacy cache as fallback`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Firestore fetch failed, falling back to old cache format
- **Example Values**:
  - `[ConfigService] Using legacy cache as fallback`
- **Possible Reasons**:
  - Firestore fetch failed
  - Old cache format still exists
- **Debugging Usage**:
  - Understand fallback behavior
  - Check if Firestore is accessible
  - Verify cache migration status

### Cache Operations

#### `[ConfigService] Using memory cache`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Returning config from memory cache (legacy path)
- **Example Values**:
  - `[ConfigService] Using memory cache`
- **Possible Reasons**:
  - Config already loaded in current session
  - Cache is still valid
- **Debugging Usage**:
  - Verify caching is working
  - Understand config source

#### `[ConfigService] Using persistent cache`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Returning config from SharedPreferences cache (legacy path)
- **Example Values**:
  - `[ConfigService] Using persistent cache`
- **Possible Reasons**:
  - Config cached from previous session
  - Cache is still valid (not expired)
- **Debugging Usage**:
  - Verify persistent caching works
  - Check cache expiration logic

#### `[ConfigService] Fetching fresh config from API`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Fetching new config from API endpoint (legacy path)
- **Example Values**:
  - `[ConfigService] Fetching fresh config from API`
- **Possible Reasons**:
  - Cache expired or invalid
  - Force refresh requested
- **Debugging Usage**:
  - Track API calls
  - Verify API endpoint is working

#### `[ConfigService] Failed to fetch from API: {error}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: API request failed (legacy path)
- **Example Values**:
  - `[ConfigService] Failed to fetch from API: SocketException(...)`
  - `[ConfigService] Failed to fetch from API: TimeoutException(...)`
- **Possible Reasons**:
  - Network connectivity issue
  - API endpoint unavailable
  - Invalid response format
- **Debugging Usage**:
  - Check API endpoint availability
  - Debug network issues
  - Verify API response format

#### `[ConfigService] Using stale cache as fallback`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: API fetch failed, using expired cache (legacy path)
- **Example Values**:
  - `[ConfigService] Using stale cache as fallback`
- **Possible Reasons**:
  - API unavailable
  - Network error
  - Prefer stale data over no data
- **Debugging Usage**:
  - Understand fallback behavior
  - Check API availability

#### `[ConfigService] Using default fallback config`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: All config sources failed, using hardcoded default (legacy path)
- **Example Values**:
  - `[ConfigService] Using default fallback config`
- **Possible Reasons**:
  - Firestore unavailable
  - API unavailable
  - Cache unavailable
  - Last resort fallback
- **Debugging Usage**:
  - Indicates complete config failure
  - Check all config sources
  - Verify network connectivity

#### `[ConfigService] Failed to load from cache: {error}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Error reading config from SharedPreferences cache
- **Example Values**:
  - `[ConfigService] Failed to load from cache: FormatException(...)`
- **Possible Reasons**:
  - Corrupted cache data
  - JSON parsing error
  - SharedPreferences access issue
- **Debugging Usage**:
  - Clear cache if corrupted
  - Check cache format
  - Verify SharedPreferences access

#### `[ConfigService] Failed to save to cache: {error}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Error saving config to SharedPreferences cache
- **Example Values**:
  - `[ConfigService] Failed to save to cache: ...`
- **Possible Reasons**:
  - SharedPreferences write error
  - Storage full
  - Permissions issue
- **Debugging Usage**:
  - Check device storage
  - Verify SharedPreferences permissions

#### `[ConfigService] Background refresh completed`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Background config refresh succeeded (legacy path)
- **Example Values**:
  - `[ConfigService] Background refresh completed`
- **Possible Reasons**:
  - Background refresh task completed
- **Debugging Usage**:
  - Verify background refresh works
  - Track refresh operations

#### `[ConfigService] Background refresh failed: {error}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Background config refresh failed (legacy path)
- **Example Values**:
  - `[ConfigService] Background refresh failed: ...`
- **Possible Reasons**:
  - Network error
  - API unavailable
  - Non-critical (background operation)
- **Debugging Usage**:
  - Check background refresh logic
  - Verify network connectivity

#### `[ConfigService] Cache cleared`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Cache cleared manually (debugging operation)
- **Example Values**:
  - `[ConfigService] Cache cleared`
- **Possible Reasons**:
  - Manual cache clear called
  - Debug operation
- **Debugging Usage**:
  - Confirm cache clear operation
  - Force fresh config fetch

### Secure Config Service

#### `[SecureConfig] DEFAULT app init error: {error}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Error initializing default Firebase app for Firestore access
- **Example Values**:
  - `[SecureConfig] DEFAULT app init error: FirebaseException(...)`
- **Possible Reasons**:
  - Firebase options issue
  - Firebase already initialized
- **Debugging Usage**:
  - Check Firebase initialization order
  - Verify bootstrap Firebase options

#### `[SecureConfig] Warning: Remote version ({remote}) is older than cached ({cached}), clearing cache`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Version check found remote version is older than cached (shouldn't happen)
- **Example Values**:
  - `[SecureConfig] Warning: Remote version (5) is older than cached (6), clearing cache`
- **Possible Reasons**:
  - Version rollback in Firestore
  - Cache corruption
  - Data inconsistency
- **Debugging Usage**:
  - Check Firestore version field
  - Verify cache integrity
  - Investigate version management

#### `[SecureConfig] Error fetching from Firestore: {error}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Exception during Firestore config fetch
- **Example Values**:
  - `[SecureConfig] Error fetching from Firestore: FirebaseException(...)`
- **Possible Reasons**:
  - Firestore connection issue
  - Document not found
  - Permission denied
- **Debugging Usage**:
  - Check Firestore connectivity
  - Verify document exists
  - Check security rules

#### `[SecureConfig] Firestore fetch error: {error}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Error in `_fetchFromFirestore` method
- **Example Values**:
  - `[SecureConfig] Firestore fetch error: ...`
- **Possible Reasons**:
  - Same as above
- **Debugging Usage**:
  - Debug Firestore operations
  - Check named Firebase app configuration

#### `[SecureConfig] Cache save error: {error}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Error saving config to cache
- **Example Values**:
  - `[SecureConfig] Cache save error: ...`
- **Possible Reasons**:
  - SharedPreferences write error
  - JSON encoding error
- **Debugging Usage**:
  - Check cache save operations
  - Verify config serialization

### Firebase Config Loader

#### `[FirebaseConfig] Loading config for project: {projectId}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Loading Firebase config for specific project
- **Example Values**:
  - `[FirebaseConfig] Loading config for project: galeria-kazimierz-827d4`
- **Possible Reasons**:
  - Config loader initialization
- **Debugging Usage**:
  - Verify correct Firebase project
  - Track config loading

### Company Mapping

#### `[CompanyMapping] Using COMPANY_ID from --dart-define: {companyId}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Company ID provided via build-time flag
- **Example Values**:
  - `[CompanyMapping] Using COMPANY_ID from --dart-define: galeria-kazimierz`
- **Possible Reasons**:
  - Build-time override used
- **Debugging Usage**:
  - Verify build configuration
  - Check dart-define flags

#### `[CompanyMapping] Using company ID from flavor: {companyId}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Company ID resolved from flavor name
- **Example Values**:
  - `[CompanyMapping] Using company ID from flavor: galeria-kazimierz`
- **Possible Reasons**:
  - Normal flavor-based resolution
- **Debugging Usage**:
  - Verify flavor configuration
  - Check flavor-to-company mapping

#### `[CompanyMapping] Package name: {packageName}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Logging package name during company ID resolution
- **Example Values**:
  - `[CompanyMapping] Package name: pl.a2ti.galeriakazimierz`
- **Possible Reasons**:
  - Debugging company ID extraction
- **Debugging Usage**:
  - Verify package name format
  - Check company ID extraction logic

#### `[CompanyMapping] Failed to get package info: {error}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Error getting package information
- **Example Values**:
  - `[CompanyMapping] Failed to get package info: ...`
- **Possible Reasons**:
  - PackageInfo plugin issue
- **Debugging Usage**:
  - Check PackageInfo configuration

#### `[CompanyMapping] Extracted company ID from package: {companyId}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Successfully extracted company ID from package name
- **Example Values**:
  - `[CompanyMapping] Extracted company ID from package: galeriakazimierz`
- **Possible Reasons**:
  - Package name contains company identifier
- **Debugging Usage**:
  - Verify extraction logic
  - Check package naming convention

#### `[CompanyMapping] Could not extract company ID, using default`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Could not extract company ID, using fallback
- **Example Values**:
  - `[CompanyMapping] Could not extract company ID, using default`
- **Possible Reasons**:
  - Package name doesn't match expected format
  - Fallback to default company
- **Debugging Usage**:
  - Check package naming
  - Verify fallback behavior

### Flavor Config

#### `[Flavor] Initialized: {name} ({flavor})`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Flavor configuration initialized
- **Example Values**:
  - `[Flavor] Initialized: galeriaKazimierz (galeriaKazimierz)`
- **Possible Reasons**:
  - App startup
  - Flavor auto-detection
- **Debugging Usage**:
  - Verify correct flavor is detected
  - Check flavor configuration

#### `[Flavor] DEBUG: fromEnvironment returned: "{flavor}" (isEmpty: {true/false})`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Debug log during flavor detection
- **Example Values**:
  - `[Flavor] DEBUG: fromEnvironment returned: "galeriaKazimierz" (isEmpty: false)`
- **Possible Reasons**:
  - Debugging flavor detection
- **Debugging Usage**:
  - Understand flavor detection process
  - Debug flavor resolution

#### `[Flavor] DEBUG: _flavorFromString returned: {flavor}`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: Debug log during flavor string parsing
- **Example Values**:
  - `[Flavor] DEBUG: _flavorFromString returned: galeriaKazimierz`
- **Possible Reasons**:
  - Debugging flavor parsing
- **Debugging Usage**:
  - Verify flavor string parsing
  - Check flavor format

#### `[Flavor] No flavor specified, defaulting to galeriaKazimierz`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: No flavor detected, using default
- **Example Values**:
  - `[Flavor] No flavor specified, defaulting to galeriaKazimierz`
- **Possible Reasons**:
  - Flavor not provided in build
  - Default fallback
- **Debugging Usage**:
  - Check build configuration
  - Verify flavor is set correctly

---

## File Picker

All file picker logs use `debugPrint()` and are only visible in debug builds.

### File Picker Flow

#### `FPK: _handleFilePicker() start`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: File picker handler started
- **Example Values**:
  - `FPK: _handleFilePicker() start`
- **Possible Reasons**:
  - User clicked file input in WebView
  - File picker triggered
- **Debugging Usage**:
  - Track file picker initiation
  - Verify file picker is triggered

#### `FPK: meta probe error: {error}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Error probing file input metadata from WebView
- **Example Values**:
  - `FPK: meta probe error: PlatformException(...)`
- **Possible Reasons**:
  - JavaScript evaluation error
  - WebView not ready
- **Debugging Usage**:
  - Check WebView state
  - Verify JavaScript bridge is working

#### `FPK: meta parse error: {error}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Error parsing file input metadata JSON
- **Example Values**:
  - `FPK: meta parse error: FormatException(...)`
- **Possible Reasons**:
  - Invalid JSON from WebView
  - Metadata format changed
- **Debugging Usage**:
  - Check metadata format
  - Verify JSON structure

#### `FPK: meta host={host} href={href} accept={accept} capture={capture} multiple={multiple} forceCamera={forceCamera}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Logging file input metadata after parsing
- **Example Values**:
  - `FPK: meta host=2take.it href=https://2take.it/upload accept=image/* capture= multiple=false forceCamera=true`
- **Possible Reasons**:
  - Normal operation - logging metadata
- **Debugging Usage**:
  - Understand file picker context
  - Verify camera vs gallery decision
  - Check file input attributes

#### `FPK: showing chooser dialog`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: About to show camera/gallery chooser dialog
- **Example Values**:
  - `FPK: showing chooser dialog`
- **Possible Reasons**:
  - User needs to choose source
- **Debugging Usage**:
  - Track dialog flow
  - Verify dialog appears

#### `FPK: dialog result => {result}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: User selected option from chooser dialog
- **Example Values**:
  - `FPK: dialog result => camera`
  - `FPK: dialog result => gallery`
  - `FPK: dialog result => null`
- **Possible Reasons**:
  - User selected camera
  - User selected gallery
  - User cancelled dialog
- **Debugging Usage**:
  - Track user choice
  - Verify dialog interaction

#### `FPK: launching camera`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: About to launch camera picker
- **Example Values**:
  - `FPK: launching camera`
- **Possible Reasons**:
  - User selected camera option
- **Debugging Usage**:
  - Track camera flow
  - Verify camera permission

#### `FPK: camera error => {error}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Error launching camera
- **Example Values**:
  - `FPK: camera error => PlatformException(CAMERA_ACCESS_DENIED, ...)`
- **Possible Reasons**:
  - Camera permission denied
  - Camera not available
  - Image picker error
- **Debugging Usage**:
  - Check camera permissions
  - Verify camera availability
  - Debug image picker issues

#### `FPK: camera cancelled or no image`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: User cancelled camera or no image returned
- **Example Values**:
  - `FPK: camera cancelled or no image`
- **Possible Reasons**:
  - User pressed back/cancel
  - Camera returned null
- **Debugging Usage**:
  - Track user cancellation
  - Verify camera behavior

#### `FPK: opening gallery`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: About to open gallery picker
- **Example Values**:
  - `FPK: opening gallery`
- **Possible Reasons**:
  - User selected gallery option
- **Debugging Usage**:
  - Track gallery flow
  - Verify gallery permission

#### `FPK: picker returned => {filename}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Image picker returned file
- **Example Values**:
  - `FPK: picker returned => IMG_20240101_120000.jpg`
  - `FPK: picker returned => null`
- **Possible Reasons**:
  - Image selected successfully
  - Picker cancelled
- **Debugging Usage**:
  - Verify file selection
  - Check file name format

#### `FPK: dialog cancelled`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: User cancelled chooser dialog
- **Example Values**:
  - `FPK: dialog cancelled`
- **Possible Reasons**:
  - User pressed cancel/back
- **Debugging Usage**:
  - Track cancellation flow

#### `FPK: dispatch error => {error}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Error dispatching picked image to WebView
- **Example Values**:
  - `FPK: dispatch error => PlatformException(...)`
- **Possible Reasons**:
  - JavaScript evaluation error
  - Image encoding error
  - WebView not ready
- **Debugging Usage**:
  - Check image encoding
  - Verify WebView bridge
  - Debug JavaScript injection

---

## WebView Bridge Handlers

All WebView bridge handler logs use `debugPrint()` and are only visible in debug builds.

### Push Notification Registration

#### `[WEBVIEW] registerPush: uid={uid} company={company}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: JavaScript called `registerPush` handler
- **Example Values**:
  - `[WEBVIEW] registerPush: uid=user123 company=galeria-kazimierz`
  - `[WEBVIEW] registerPush: uid= company=-`
- **Possible Reasons**:
  - Web app registering push token
  - User login completed
- **Debugging Usage**:
  - Track push registration flow
  - Verify user ID and company
  - Debug registration timing

#### `[WEBVIEW] fcmToken(before)={token}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Logging FCM token before registration operation
- **Example Values**:
  - `[WEBVIEW] fcmToken(before)=dAbCdEf123...`
  - `[WEBVIEW] fcmToken(before)=null`
- **Possible Reasons**:
  - Tracking token state
- **Debugging Usage**:
  - Verify token availability
  - Track token changes

#### `[WEBVIEW] registerPush done uid={uid} fcmToken(after)={token}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Push registration completed successfully
- **Example Values**:
  - `[WEBVIEW] registerPush done uid=user123 fcmToken(after)=dAbCdEf123...`
- **Possible Reasons**:
  - Registration succeeded
- **Debugging Usage**:
  - Verify registration success
  - Check token after registration

#### `[WEBVIEW] registerPush error: {error}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Error during push registration
- **Example Values**:
  - `[WEBVIEW] registerPush error: Exception: no_company`
- **Possible Reasons**:
  - Missing company parameter
  - Token registration failed
  - API error
- **Debugging Usage**:
  - Debug registration failures
  - Check parameters
  - Verify API connectivity

#### `[WEBVIEW] logoutPush uid={uid}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: JavaScript called `logoutPush` handler
- **Example Values**:
  - `[WEBVIEW] logoutPush uid=user123`
- **Possible Reasons**:
  - User logout
  - Unregistering push token
- **Debugging Usage**:
  - Track logout flow
  - Verify token unregistration

#### `[WEBVIEW] logoutPush done uid={uid}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Push logout completed successfully
- **Example Values**:
  - `[WEBVIEW] logoutPush done uid=user123`
- **Possible Reasons**:
  - Logout succeeded
- **Debugging Usage**:
  - Verify logout success

### User Management

#### `[WEBVIEW] setUser uid={uid} company={company}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: JavaScript called `setUser` handler
- **Example Values**:
  - `[WEBVIEW] setUser uid=user123 company=galeria-kazimierz`
- **Possible Reasons**:
  - User login/session update
  - Setting current user context
- **Debugging Usage**:
  - Track user context changes
  - Verify user ID and company

#### `[WEBVIEW] setUser done uid={uid} fcmToken={token}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: setUser operation completed
- **Example Values**:
  - `[WEBVIEW] setUser done uid=user123 fcmToken=dAbCdEf123...`
- **Possible Reasons**:
  - User context set successfully
- **Debugging Usage**:
  - Verify user context update
  - Check token availability

#### `[WEBVIEW] setUser error: {error}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Error during setUser operation
- **Example Values**:
  - `[WEBVIEW] setUser error: Exception: no_user`
- **Possible Reasons**:
  - Missing user ID
  - Token registration failed
- **Debugging Usage**:
  - Debug user context errors
  - Check parameters

#### `[WEBVIEW] debugRegisterPushWithToken uid={uid} tokenLen={length}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Debug handler called with explicit token
- **Example Values**:
  - `[WEBVIEW] debugRegisterPushWithToken uid=user123 tokenLen=152`
- **Possible Reasons**:
  - Testing/debugging operation
  - iOS Simulator token injection
- **Debugging Usage**:
  - Debug token registration
  - Test with specific tokens

### WebView Initialization

#### `[WEBVIEW] Flavor: {flavor}, Company (UI): {companyId}, Company (Google Auth): {authCompanyId}, Google Auth client: {clientId}...`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Logging WebView initialization details
- **Example Values**:
  - `[WEBVIEW] Flavor: galeriaKazimierz, Company (UI): galeria-kazimierz, Company (Google Auth): galeria-kazimierz, Google Auth client: 839029981684-v8su4cmc...`
- **Possible Reasons**:
  - WebView setup
  - Debugging configuration
- **Debugging Usage**:
  - Verify configuration
  - Check company ID resolution
  - Verify Google Auth client ID

#### `[WEBVIEW] GoogleSignIn initialized`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Google Sign-In instance created
- **Example Values**:
  - `[WEBVIEW] GoogleSignIn initialized`
- **Possible Reasons**:
  - Google Auth setup complete
- **Debugging Usage**:
  - Verify Google Auth initialization

#### `[WEBVIEW] early guest register company={company}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Attempting early guest token registration
- **Example Values**:
  - `[WEBVIEW] early guest register company=galeria-kazimierz`
- **Possible Reasons**:
  - Pre-registering guest token
- **Debugging Usage**:
  - Track guest registration
  - Verify company ID

#### `[WEBVIEW] early guest register skipped: no company in URL`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Early guest registration skipped due to missing company
- **Example Values**:
  - `[WEBVIEW] early guest register skipped: no company in URL`
- **Possible Reasons**:
  - URL doesn't contain company_name parameter
- **Debugging Usage**:
  - Check URL parameters
  - Verify company ID source

#### `[WEBVIEW] early guest register error: {error}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Error during early guest registration
- **Example Values**:
  - `[WEBVIEW] early guest register error: ...`
- **Possible Reasons**:
  - Registration failed
  - Token not available
- **Debugging Usage**:
  - Debug guest registration issues

#### `[WEBVIEW CONSOLE] {message}`

- **Type**: `print()` - Visible in release builds (from WebView console)
- **When It Appears**: Console message from WebView JavaScript
- **Example Values**:
  - `[WEBVIEW CONSOLE] Error: Cannot read property 'x' of undefined`
  - `[WEBVIEW CONSOLE] Firebase bridge ready`
- **Possible Reasons**:
  - JavaScript errors in WebView
  - Web app logging
- **Debugging Usage**:
  - Debug WebView JavaScript issues
  - Track web app behavior
  - Monitor web app errors

---

## Authentication

### Facebook Authentication

#### `FB pre-logout ignored: {error}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Error during pre-logout (non-critical, ignored)
- **Example Values**:
  - `FB pre-logout ignored: PlatformException(...)`
- **Possible Reasons**:
  - Already logged out
  - Logout not needed
- **Debugging Usage**:
  - Normal operation - can be ignored
  - Verify logout flow

#### `FB login failed: status={status} message={message}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Facebook login returned non-success status
- **Example Values**:
  - `FB login failed: status=LoginStatus.cancelled message=User cancelled login`
  - `FB login failed: status=LoginStatus.failed message=Network error`
- **Possible Reasons**:
  - User cancelled login
  - Network error
  - Facebook SDK error
  - Permission denied
- **Debugging Usage**:
  - Understand login failure reason
  - Check Facebook SDK configuration
  - Verify network connectivity
  - Debug user cancellation flow

#### `FB login exception: {error}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Exception during Facebook login
- **Example Values**:
  - `FB login exception: PlatformException(FACEBOOK_LOGIN_ERROR, ...)`
- **Possible Reasons**:
  - Facebook SDK exception
  - Platform channel error
  - Unexpected error
- **Debugging Usage**:
  - Debug Facebook SDK issues
  - Check platform-specific errors
  - Verify Facebook configuration

#### `FB fallback channel error: {error}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Error using fallback platform channel for Facebook login
- **Example Values**:
  - `FB fallback channel error: MissingPluginException(...)`
- **Possible Reasons**:
  - Fallback channel not available
  - Plugin not registered
- **Debugging Usage**:
  - Check fallback mechanism
  - Verify plugin registration

#### `FB native sign-in failed: status={status} message={message}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Native Facebook sign-in failed (via JS prompt)
- **Example Values**:
  - `FB native sign-in failed: status=LoginStatus.cancelled message=User cancelled`
- **Possible Reasons**:
  - Same as "FB login failed"
  - Triggered from WebView JavaScript
- **Debugging Usage**:
  - Debug native sign-in flow
  - Check WebView bridge

#### `FB native sign-in exception: {error}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Exception during native Facebook sign-in (via JS prompt)
- **Example Values**:
  - `FB native sign-in exception: ...`
- **Possible Reasons**:
  - Same as "FB login exception"
  - Triggered from WebView
- **Debugging Usage**:
  - Debug native sign-in exceptions
  - Check WebView bridge

### Apple Authentication

#### `[APPLE][open-in-webview] {url}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Opening Apple OAuth URL in WebView (not external browser)
- **Example Values**:
  - `[APPLE][open-in-webview] https://appleid.apple.com/auth/authorize?client_id=...`
- **Possible Reasons**:
  - Apple sign-in button clicked
  - OAuth flow initiated
- **Debugging Usage**:
  - Track Apple OAuth flow
  - Verify OAuth URL format
  - Check redirect handling

#### `[APPLE][native] got tokens idTokenLen={idLength} codeLen={codeLength}`

- **Type**: `debugPrint()` - Debug builds only
- **When It Appears**: Successfully obtained Apple ID tokens from native sign-in
- **Example Values**:
  - `[APPLE][native] got tokens idTokenLen=1234 codeLen=567`
- **Possible Reasons**:
  - Native Apple sign-in succeeded
  - Tokens received from Sign in with Apple
- **Debugging Usage**:
  - Verify token lengths are reasonable
  - Confirm native sign-in worked
  - Debug token format issues

---

## JavaScript Console Logs

These logs appear in the WebView's JavaScript console and are also logged via `onConsoleMessage` handler. They help debug WebView bridge operations and web app behavior.

### Bridge Injection

#### `♻️ Flutter bridge already installed, skipping re-injection`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Bridge injection attempted but already exists
- **Example Values**:
  - `♻️ Flutter bridge already installed, skipping re-injection`
- **Possible Reasons**:
  - Bridge already injected
  - Page reload/navigation
- **Debugging Usage**:
  - Verify bridge is present
  - Check injection logic

#### `🚀 ULTIMATE Firebase bridge injection - MAXIMUM OVERRIDE...`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Starting bridge injection process
- **Example Values**:
  - `🚀 ULTIMATE Firebase bridge injection - MAXIMUM OVERRIDE...`
- **Possible Reasons**:
  - Bridge injection starting
- **Debugging Usage**:
  - Track injection process
  - Verify injection timing

#### `✅ serviceWorkerVersion defined: {version}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Service worker version detected
- **Example Values**:
  - `✅ serviceWorkerVersion defined: 1.2.3`
- **Possible Reasons**:
  - Service worker present
- **Debugging Usage**:
  - Verify service worker detection

### File Picker JavaScript

#### `[FPK-JS] click() on file input accept={accept} capture={capture} multiple={multiple}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: File input click intercepted
- **Example Values**:
  - `[FPK-JS] click() on file input accept=image/* capture= multiple=false`
- **Possible Reasons**:
  - User clicked file input
  - Interceptor triggered
- **Debugging Usage**:
  - Track file input interactions
  - Verify interceptor works

#### `[FPK-JS] showPicker() on file input accept={accept} capture={capture} multiple={multiple}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: File input showPicker called
- **Example Values**:
  - `[FPK-JS] showPicker() on file input accept=image/* capture= multiple=false`
- **Possible Reasons**:
  - Programmatic picker trigger
- **Debugging Usage**:
  - Track picker triggers

#### `[FPK-JS] direct input click accept={accept} capture={capture} multiple={multiple}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Direct file input click detected
- **Example Values**:
  - `[FPK-JS] direct input click accept=image/* capture= multiple=false`
- **Possible Reasons**:
  - Direct input interaction
- **Debugging Usage**:
  - Track direct interactions

#### `[FPK-JS] label click -> input accept={accept} capture={capture} multiple={multiple}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Label click that triggers file input
- **Example Values**:
  - `[FPK-JS] label click -> input accept=image/* capture= multiple=false`
- **Possible Reasons**:
  - User clicked label associated with file input
- **Debugging Usage**:
  - Track label interactions

#### `[FPK-JS] mutated to type=file accept={accept} capture={capture} multiple={multiple}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Input type changed to file via MutationObserver
- **Example Values**:
  - `[FPK-JS] mutated to type=file accept=image/* capture= multiple=false`
- **Possible Reasons**:
  - Dynamic input creation
  - Type change detected
- **Debugging Usage**:
  - Track dynamic input creation
  - Verify MutationObserver

#### `[FPK-JS] __dispatchFlutterImage received name={name} size={size}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Image data received from Flutter
- **Example Values**:
  - `[FPK-JS] __dispatchFlutterImage received name=photo.jpg size=123456`
- **Possible Reasons**:
  - Image picked and dispatched
- **Debugging Usage**:
  - Verify image dispatch
  - Check image size

#### `⚠️ __dispatchFlutterImage error {error}`

- **Type**: JavaScript `console.error` - Visible in WebView dev tools
- **When It Appears**: Error dispatching image to file input
- **Example Values**:
  - `⚠️ __dispatchFlutterImage error TypeError: Cannot read property 'files' of null`
- **Possible Reasons**:
  - File input not found
  - DataTransfer API error
- **Debugging Usage**:
  - Debug image dispatch issues
  - Check file input state

### Authentication JavaScript

#### `[NATIVE->WEB] facebook button disabled by class; triggering page error`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Facebook button clicked but disabled
- **Example Values**:
  - `[NATIVE->WEB] facebook button disabled by class; triggering page error`
- **Possible Reasons**:
  - Button has disabled class
  - Form validation failed
- **Debugging Usage**:
  - Check button state
  - Verify form validation

#### `[NATIVE->WEB] terms not accepted; triggering page error (fb)`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Facebook login attempted but terms checkbox not checked
- **Example Values**:
  - `[NATIVE->WEB] terms not accepted; triggering page error (fb)`
- **Possible Reasons**:
  - User didn't accept terms
  - Checkbox validation failed
- **Debugging Usage**:
  - Check terms acceptance flow
  - Verify checkbox state

#### `[NATIVE->WEB][FB] using fixed legacy login URL {url}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Using legacy Facebook login endpoint
- **Example Values**:
  - `[NATIVE->WEB][FB] using fixed legacy login URL https://login.2take.it/api/web/user/fblogin`
- **Possible Reasons**:
  - Legacy backend detected
  - Fallback to old endpoint
- **Debugging Usage**:
  - Track backend version
  - Verify endpoint selection

#### `[NATIVE->WEB][FB] legacy login ok; redirect: {url}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Legacy Facebook login succeeded
- **Example Values**:
  - `[NATIVE->WEB][FB] legacy login ok; redirect: https://2take.it/dashboard`
- **Possible Reasons**:
  - Login successful
  - Redirect URL received
- **Debugging Usage**:
  - Verify login success
  - Check redirect URL

#### `[NATIVE->WEB][FB] legacy login http {status}`

- **Type**: JavaScript `console.warn` - Visible in WebView dev tools
- **When It Appears**: Legacy Facebook login returned non-200 status
- **Example Values**:
  - `[NATIVE->WEB][FB] legacy login http 401`
- **Possible Reasons**:
  - Authentication failed
  - Server error
- **Debugging Usage**:
  - Debug login failures
  - Check HTTP status

#### `[NATIVE->WEB][FB] trying {url}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Attempting Facebook login at URL
- **Example Values**:
  - `[NATIVE->WEB][FB] trying https://login.2take.it/api/web/user/facebook-auth`
- **Possible Reasons**:
  - Login attempt
- **Debugging Usage**:
  - Track login attempts
  - Verify URL format

#### `[NATIVE->WEB][FB] login ok at {base} redirect: {url}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Facebook login succeeded
- **Example Values**:
  - `[NATIVE->WEB][FB] login ok at https://login.2take.it redirect: https://2take.it/dashboard`
- **Possible Reasons**:
  - Login successful
- **Debugging Usage**:
  - Verify login success
  - Check redirect

#### `[NATIVE->WEB][FB] login failed for all bases {bases}`

- **Type**: JavaScript `console.error` - Visible in WebView dev tools
- **When It Appears**: All Facebook login attempts failed
- **Example Values**:
  - `[NATIVE->WEB][FB] login failed for all bases ["https://login.2take.it", "https://api.2take.it"]`
- **Possible Reasons**:
  - All endpoints failed
  - Network error
  - Invalid token
- **Debugging Usage**:
  - Debug login failures
  - Check all endpoints
  - Verify token validity

#### `[APPLE][intercept] company={company} redirect={redirectUrl}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Apple sign-in button intercepted
- **Example Values**:
  - `[APPLE][intercept] company=galeria-kazimierz redirect=https://login.2take.it/api/web/user/apple-login?cn=galeria-kazimierz`
- **Possible Reasons**:
  - Apple button clicked
  - OAuth flow initiated
- **Debugging Usage**:
  - Track Apple sign-in flow
  - Verify company ID
  - Check redirect URL

#### `[NATIVE->WEB][APPLE] tokens ready, posting to redirect endpoint`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Apple tokens received, submitting to backend
- **Example Values**:
  - `[NATIVE->WEB][APPLE] tokens ready, posting to redirect endpoint`
- **Possible Reasons**:
  - Native sign-in completed
  - Tokens available
- **Debugging Usage**:
  - Track token submission
  - Verify token flow

#### `[NATIVE->WEB][APPLE] submitting form to {action} idTokenLen={idLength} codeLen={codeLength}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Submitting Apple login form to backend
- **Example Values**:
  - `[NATIVE->WEB][APPLE] submitting form to https://login.2take.it/api/web/user/apple-login?cn=galeria-kazimierz idTokenLen=1234 codeLen=567`
- **Possible Reasons**:
  - Form submission
  - Token lengths logged
- **Debugging Usage**:
  - Verify form submission
  - Check token lengths
  - Debug submission flow

#### `[NATIVE->WEB][APPLE] using fixed legacy login URL {url}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Using legacy Apple login endpoint
- **Example Values**:
  - `[NATIVE->WEB][APPLE] using fixed legacy login URL https://login.2take.it/api/web/user/apple-login`
- **Possible Reasons**:
  - Legacy backend detected
- **Debugging Usage**:
  - Track backend version

#### `[NATIVE->WEB][APPLE] legacy login ok; redirect: {url}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Legacy Apple login succeeded
- **Example Values**:
  - `[NATIVE->WEB][APPLE] legacy login ok; redirect: https://2take.it/dashboard`
- **Possible Reasons**:
  - Login successful
- **Debugging Usage**:
  - Verify login success

#### `[NATIVE->WEB][APPLE] legacy login http {status}`

- **Type**: JavaScript `console.warn` - Visible in WebView dev tools
- **When It Appears**: Legacy Apple login returned non-200 status
- **Example Values**:
  - `[NATIVE->WEB][APPLE] legacy login http 401`
- **Possible Reasons**:
  - Authentication failed
- **Debugging Usage**:
  - Debug login failures

#### `[NATIVE->WEB][APPLE] trying {url}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Attempting Apple login at URL
- **Example Values**:
  - `[NATIVE->WEB][APPLE] trying https://login.2take.it/api/web/user/apple-auth`
- **Possible Reasons**:
  - Login attempt
- **Debugging Usage**:
  - Track login attempts

#### `[NATIVE->WEB][APPLE] login http {status}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Apple login HTTP response status
- **Example Values**:
  - `[NATIVE->WEB][APPLE] login http 200`
- **Possible Reasons**:
  - HTTP response received
- **Debugging Usage**:
  - Check HTTP status

#### `[NATIVE->WEB][APPLE] login ok; redirect: {url}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Apple login succeeded
- **Example Values**:
  - `[NATIVE->WEB][APPLE] login ok; redirect: https://2take.it/dashboard`
- **Possible Reasons**:
  - Login successful
- **Debugging Usage**:
  - Verify login success

#### `[NATIVE->WEB][APPLE] JSON parse failed {error}`

- **Type**: JavaScript `console.error` - Visible in WebView dev tools
- **When It Appears**: Error parsing Apple login response JSON
- **Example Values**:
  - `[NATIVE->WEB][APPLE] JSON parse failed SyntaxError: Unexpected token...`
- **Possible Reasons**:
  - Invalid JSON response
  - Server error page
- **Debugging Usage**:
  - Check response format
  - Debug server errors

#### `[NATIVE->WEB][APPLE] login error at {base} {error}`

- **Type**: JavaScript `console.error` - Visible in WebView dev tools
- **When It Appears**: Error during Apple login at base URL
- **Example Values**:
  - `[NATIVE->WEB][APPLE] login error at https://login.2take.it NetworkError: Failed to fetch`
- **Possible Reasons**:
  - Network error
  - Server unavailable
- **Debugging Usage**:
  - Debug network issues
  - Check server availability

#### `[NATIVE->WEB][APPLE] form post failed {error}`

- **Type**: JavaScript `console.error` - Visible in WebView dev tools
- **When It Appears**: Error submitting Apple login form
- **Example Values**:
  - `[NATIVE->WEB][APPLE] form post failed TypeError: ...`
- **Possible Reasons**:
  - Form submission error
  - DOM manipulation error
- **Debugging Usage**:
  - Debug form submission
  - Check DOM state

#### `onFlutterAppleSignIn error {error}`

- **Type**: JavaScript `console.error` - Visible in WebView dev tools
- **When It Appears**: Error in Apple sign-in handler
- **Example Values**:
  - `onFlutterAppleSignIn error TypeError: Cannot read property 'idToken' of undefined`
- **Possible Reasons**:
  - Handler error
  - Invalid parameters
- **Debugging Usage**:
  - Debug handler errors
  - Check parameters

#### `native apple sign-in error {error}`

- **Type**: JavaScript `console.error` - Visible in WebView dev tools
- **When It Appears**: Error during native Apple sign-in
- **Example Values**:
  - `native apple sign-in error PlatformException(...)`
- **Possible Reasons**:
  - Native sign-in failed
  - Platform error
- **Debugging Usage**:
  - Debug native sign-in
  - Check platform errors

#### `FB error dispatch failed {error}`

- **Type**: JavaScript `console.error` - Visible in WebView dev tools
- **When It Appears**: Error dispatching Facebook error event
- **Example Values**:
  - `FB error dispatch failed TypeError: ...`
- **Possible Reasons**:
  - Event dispatch error
  - Handler not available
- **Debugging Usage**:
  - Debug event system
  - Check handlers

#### `FB tokens dispatch error {error}`

- **Type**: JavaScript `console.error` - Visible in WebView dev tools
- **When It Appears**: Error dispatching Facebook tokens event
- **Example Values**:
  - `FB tokens dispatch error TypeError: ...`
- **Possible Reasons**:
  - Event dispatch error
- **Debugging Usage**:
  - Debug event system

#### `facebook native interceptor failed {error}`

- **Type**: JavaScript `console.error` - Visible in WebView dev tools
- **When It Appears**: Error in Facebook button interceptor
- **Example Values**:
  - `facebook native interceptor failed TypeError: ...`
- **Possible Reasons**:
  - Interceptor setup error
  - DOM access error
- **Debugging Usage**:
  - Debug interceptor
  - Check DOM state

#### `native facebook sign-in error {error}`

- **Type**: JavaScript `console.error` - Visible in WebView dev tools
- **When It Appears**: Error during native Facebook sign-in
- **Example Values**:
  - `native facebook sign-in error PlatformException(...)`
- **Possible Reasons**:
  - Native sign-in failed
- **Debugging Usage**:
  - Debug native sign-in

### Firebase Bridge JavaScript

#### `🔥 Flutter bridge: getFCMToken called, returning: {token}`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: FCM token requested via bridge
- **Example Values**:
  - `🔥 Flutter bridge: getFCMToken called, returning: dAbCdEf123...`
- **Possible Reasons**:
  - Web app requesting token
- **Debugging Usage**:
  - Verify bridge token access
  - Check token availability

#### `🔥 Flutter bridge: onNotificationReceived callback registered`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Notification callback registered
- **Example Values**:
  - `🔥 Flutter bridge: onNotificationReceived callback registered`
- **Possible Reasons**:
  - Web app registering callback
- **Debugging Usage**:
  - Verify callback registration

#### `🔥 Flutter bridge: onNotificationClick callback registered`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Notification click callback registered
- **Example Values**:
  - `🔥 Flutter bridge: onNotificationClick callback registered`
- **Possible Reasons**:
  - Web app registering callback
- **Debugging Usage**:
  - Verify callback registration

#### `🔥 FAKE Firebase messaging() called`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Web app accessing Firebase messaging via bridge
- **Example Values**:
  - `🔥 FAKE Firebase messaging() called`
- **Possible Reasons**:
  - Web app using Firebase bridge
- **Debugging Usage**:
  - Verify bridge usage

#### `🔥 FAKE Firebase messaging getToken, returning Flutter token`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Token requested via Firebase bridge
- **Example Values**:
  - `🔥 FAKE Firebase messaging getToken, returning Flutter token`
- **Possible Reasons**:
  - Token access via bridge
- **Debugging Usage**:
  - Verify token access

#### `🔥 FAKE Firebase messaging onMessage registered`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Message listener registered via bridge
- **Example Values**:
  - `🔥 FAKE Firebase messaging onMessage registered`
- **Possible Reasons**:
  - Web app registering listener
- **Debugging Usage**:
  - Verify listener registration

#### `🔥 FAKE Firebase messaging onBackgroundMessage registered`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Background message listener registered
- **Example Values**:
  - `🔥 FAKE Firebase messaging onBackgroundMessage registered`
- **Possible Reasons**:
  - Background listener registration
- **Debugging Usage**:
  - Verify background listener

#### `🔥 FAKE Firebase messaging requestPermission - ALWAYS GRANTED`

- **Type**: JavaScript `console.log` - Visible in WebView dev tools
- **When It Appears**: Permission requested via bridge (always granted by bridge)
- **Example Values**:
  - `🔥 FAKE Firebase messaging requestPermission - ALWAYS GRANTED`
- **Possible Reasons**:
  - Web app requesting permission
  - Bridge simulates granted permission
- **Debugging Usage**:
  - Verify permission bridge behavior

---

## Secret Gesture

### Secret Tap Tracking

#### `[SECRET] Tap count: {count}/{threshold} at ({x}, {y})`

- **Type**: `print()` - Visible in release builds
- **When It Appears**: User taps in top-right corner (100x100px area)
- **Example Values**:
  - `[SECRET] Tap count: 3/7 at (350.5, 45.2)`
  - `[SECRET] Tap count: 7/7 at (380.1, 30.8)`
- **Possible Reasons**:
  - User performing secret gesture
  - Accidental taps in corner
- **Debugging Usage**:
  - Track secret gesture attempts
  - Verify tap detection works
  - Debug gesture recognition
  - **Note**: After 7 taps, FCM token dialog appears

---

## Troubleshooting Guide

### Common Scenarios

#### FCM Token Not Available

**Symptoms:**

- `[FCM] Token is null - permission may be denied`
- `[FCM] Token is null - permission may be denied` followed by `[FCM] Permission denied on iOS`

**Debugging Steps:**

1. Check permission status: Look for `[FCM] Current permission status: ...`
2. Android 13+: Verify `[FCM] Requesting notification permission on Android...` appears
3. iOS: Check if `[FCM] Permission denied on iOS` appears - user must enable in Settings
4. Verify Firebase initialization: Check for `[FCM] Failed to get token` errors
5. Check `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) configuration

#### Push Notifications Not Received

**Symptoms:**

- No `[FCM] ✅ Message received` logs
- Token obtained but messages not arriving

**Debugging Steps:**

1. Verify token is obtained: Look for `[FCM] Token obtained: length=...`
2. Check token registration: Look for `[WEBVIEW] registerPush done` logs
3. Verify backend is sending to correct token
4. Check message format: Foreground messages should appear as `[FCM] ✅ Message received`
5. Background messages: Look for `[FCM][bg] ✅ Background message` (requires `content-available: 1` on iOS)
6. Check notification channel (Android): Verify `fcm_default_channel` is created (check Android logs)

#### Configuration Not Loading

**Symptoms:**

- `[ConfigService] Using default fallback config`
- `[ConfigService] Error fetching secure config`

**Debugging Steps:**

1. Check company ID: Look for `[ConfigService] Fetching secure config for: ...`
2. Verify Firestore connectivity: Check for `[SecureConfig] Error fetching from Firestore`
3. Check cache: Look for `[ConfigService] Using persistent cache` or `[ConfigService] Using memory cache`
4. Verify company ID exists in Firestore `mobile_configs` collection
5. Check Firestore security rules
6. Clear cache: Call `ConfigService.clearCache()` and check `[ConfigService] Cache cleared`

#### File Picker Not Working

**Symptoms:**

- File picker dialog doesn't appear
- Images not dispatched to WebView

**Debugging Steps:**

1. Check file picker initiation: Look for `FPK: _handleFilePicker() start`
2. Verify metadata: Check `FPK: meta host=...` log for file input attributes
3. Check dialog: Look for `FPK: showing chooser dialog` and `FPK: dialog result => ...`
4. Verify camera/gallery: Check `FPK: launching camera` or `FPK: opening gallery`
5. Check dispatch: Look for `FPK: dispatch error` or JavaScript `[FPK-JS] __dispatchFlutterImage`
6. Verify permissions: Check camera and storage permissions in AndroidManifest.xml / Info.plist

#### Authentication Failures

**Facebook Login Issues:**

1. Check login attempt: Look for `FB login failed: status=...`
2. Verify status: `LoginStatus.cancelled` = user cancelled, `LoginStatus.failed` = error
3. Check fallback: Look for `FB fallback channel error` if primary fails
4. Verify Facebook SDK configuration in AndroidManifest.xml / Info.plist

**Apple Login Issues:**

1. Check token receipt: Look for `[APPLE][native] got tokens idTokenLen=...`
2. Verify form submission: Check `[NATIVE->WEB][APPLE] submitting form to ...`
3. Check HTTP status: Look for `[NATIVE->WEB][APPLE] login http ...`
4. Verify redirect: Check `[NATIVE->WEB][APPLE] login ok; redirect: ...`
5. Check errors: Look for `[NATIVE->WEB][APPLE] login error` or `onFlutterAppleSignIn error`

#### WebView Bridge Not Working

**Symptoms:**

- JavaScript handlers not responding
- Bridge functions not available

**Debugging Steps:**

1. Check bridge injection: Look for `🚀 ULTIMATE Firebase bridge injection` in JavaScript console
2. Verify bridge ready: Check `window.flutterFirebaseBridge` exists in WebView console
3. Check handler registration: Look for `[WEBVIEW] registerPush`, `[WEBVIEW] setUser` logs
4. Verify FCM token: Check `window.flutterFCMToken` in WebView console
5. Check console messages: Look for `[WEBVIEW CONSOLE]` logs for JavaScript errors

### Log Filtering Tips

**Filter FCM logs:**

```bash
adb logcat | grep "\[FCM\]"
```

**Filter Config logs:**

```bash
adb logcat | grep "\[ConfigService\]"
```

**Filter WebView logs:**

```bash
adb logcat | grep "\[WEBVIEW\]"
```

**Filter File Picker logs (debug only):**

```bash
flutter run --debug 2>&1 | grep "FPK:"
```

**Filter Authentication logs:**

```bash
adb logcat | grep -E "FB |\[APPLE\]"
```

### Understanding Log Types

- **`print()`**: Visible in both debug and release builds. Use for important operational logs.
- **`debugPrint()`**: Only visible in debug builds. Use for detailed debugging that shouldn't appear in production.
- **JavaScript `console.log`**: Only visible in WebView dev tools. Use for web app debugging.

### Best Practices

1. **Use appropriate log level**: Use `debugPrint()` for detailed debugging, `print()` for important events
2. **Include context**: Logs include relevant IDs, statuses, and error messages
3. **Check related logs**: Many features have multiple related logs - check all of them
4. **Use log prefixes**: All logs use consistent prefixes like `[FCM]`, `[ConfigService]`, `[WEBVIEW]` for easy filtering
5. **Monitor in production**: `print()` logs are visible in release - monitor them for production issues

---

## Additional Resources

- Firebase Cloud Messaging: https://firebase.google.com/docs/cloud-messaging
- Flutter Firebase: https://firebase.flutter.dev/
- WebView Documentation: See `lib/webview_screen_mobile.dart`
- Configuration Service: See `lib/config_service.dart` and `lib/services/secure_config_service.dart`

---

**Last Updated**: 2024-01-XX  
**Maintained By**: Development Team
