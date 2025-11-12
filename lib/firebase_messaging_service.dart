import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'app_config.dart';

class FirebaseMessagingService {
  static String? _fcmToken;
  static bool _initialized = false;
  static NotificationsApiClient? _api;
  static String? _currentUserId;
  static String? _currentCompany;
  static String? _lastSentToken;
  static Map<String, String>? _currentExtra;
  // 2take.it loyalty integration (form-encoded)
  static final TwoTakeLoyaltyPushClient _loyalty = TwoTakeLoyaltyPushClient();
  static String? _loyaltyCompany;
  static String? _loyaltyUid;
  static String? _cachedPackageId;

  /// Initialize Firebase Cloud Messaging
  /// 
  /// Uses the default Firebase app that's auto-initialized from native configs:
  /// - Android: google-services.json (per flavor)
  /// - iOS: GoogleService-Info.plist (per scheme)
  /// 
  /// The config parameter is accepted but not used for messaging initialization.
  /// It's kept for API compatibility with other parts of the app.
  static Future<void> initialize({AppConfig? config}) async {
    try {
      // Use default FirebaseMessaging instance
      // Firebase is already initialized by native platform before Dart code runs
      final messaging = FirebaseMessaging.instance;
      
      await messaging.setAutoInitEnabled(true);
      
      // CRITICAL: Request permission BEFORE getting token on Android 13+
      // This ensures permission dialog appears in release builds
      await _ensurePermissionIfNeeded(messaging: messaging);

      // Get token - on older Android versions permission is not required
      // On Android 13+ token will be null if permission denied, but we still try
      try {
        _fcmToken = await messaging.getToken();
        if (_fcmToken != null) {
          print('[FCM] Token obtained: length=${_fcmToken!.length}');
        } else {
          print('[FCM] Token is null - permission may be denied');
        }
      } catch (e) {
        print('[FCM] Failed to get token: $e');
      }

      // If API client configured and we have a user, the host code can call
      // registerToken(userId) afterwards. We only set up refresh forwarding here.
      messaging.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        await _autoUpsertIfPossible();
        await _autoRegister2TakeIfPossible();
      });

      // Use static methods for listeners (these work with the default app)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        try {
          final messageId = message.messageId ?? 'null';
          final title = message.notification?.title ?? '';
          final body = message.notification?.body ?? '';
          final from = message.from ?? 'null';
          print('[FCM] ✅ Message received: "$title" / "$body" (from: $from, id: $messageId)');
        } catch (e) {
          print('[FCM] ❌ onMessage ERROR: $e');
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        // Silent handler - no logging needed
      });

      _initialized = true;
      // Try an initial upsert if we already know the user
      await _autoUpsertIfPossible();
      await _autoRegister2TakeIfPossible();
    } catch (_) { _initialized = true; }
  }

  static String? get fcmToken => _fcmToken;
  static bool get isInitialized => _initialized;

  // ---------- API helpers -------------------------------------------------

  static Future<String?> _awaitFcmToken({Duration timeout = const Duration(seconds: 8)}) async {
    // Use default messaging instance
    final messaging = FirebaseMessaging.instance;
    // Ensure permission only if not granted
    await _ensurePermissionIfNeeded(messaging: messaging);
    var t = _fcmToken ?? await messaging.getToken();
    if (t != null && t.isNotEmpty) { 
      _fcmToken = t; 
      return t; 
    }
    try { 
      t = await messaging.onTokenRefresh.first.timeout(timeout); 
    } catch (e) { 
      // Timeout is expected if token already available
    }
    if (t == null || t.isEmpty) {
      try { 
        t = await messaging.getToken(); 
      } catch (e) { 
        print('[FCM] getToken error: $e'); 
      }
    }
    if (t != null && t.isNotEmpty) _fcmToken = t;
    return t;
  }

  static Future<bool> _ensurePermissionIfNeeded({FirebaseMessaging? messaging}) async {
    final messagingInstance = messaging ?? FirebaseMessaging.instance;
    try {
      final settings = await messagingInstance.getNotificationSettings();
      final status = settings.authorizationStatus;
      print('[FCM] Current permission status: $status');
      
      // Already granted (full or provisional)
      if (status == AuthorizationStatus.authorized || status == AuthorizationStatus.provisional) {
        print('[FCM] Permission already granted');
        if (Platform.isIOS) {
          try {
            await messagingInstance.getAPNSToken();
            await messagingInstance.setForegroundNotificationPresentationOptions(
              alert: true, badge: true, sound: true,
            );
          } catch (e) { 
            // APNs token may not be available immediately
          }
        }
        return true;
      }
      
      // On Android 13+ (API 33+), always request permission if not granted
      // This ensures permission dialog appears in release builds
      if (Platform.isAndroid) {
        print('[FCM] Requesting notification permission on Android...');
        final perm = await messagingInstance.requestPermission(
          alert: true, 
          badge: true, 
          sound: true,
        );
        final granted = perm.authorizationStatus == AuthorizationStatus.authorized;
        print('[FCM] Permission request result: ${perm.authorizationStatus} (granted: $granted)');
        return granted;
      }
      
      // iOS handling
      if (Platform.isIOS) {
        if (status == AuthorizationStatus.notDetermined) {
          // Request full permission on iOS so alerts/badges/sounds show immediately
          print('[FCM] Requesting notification permission on iOS...');
          final perm = await messagingInstance.requestPermission(
            alert: true, badge: true, sound: true, provisional: false,
          );
          final ok = perm.authorizationStatus == AuthorizationStatus.authorized ||
              perm.authorizationStatus == AuthorizationStatus.provisional;
          print('[FCM] Permission request result: ${perm.authorizationStatus} (granted: $ok)');
          if (ok) {
            try {
              final apns = await messagingInstance.getAPNSToken();
              await messagingInstance.setForegroundNotificationPresentationOptions(
                alert: true, badge: true, sound: true,
              );
            } catch (e) { 
              // APNs token may not be available immediately
            }
          }
          return ok;
        } else if (status == AuthorizationStatus.denied) {
          // iOS denied - user must go to Settings
          print('[FCM] Permission denied on iOS - user must enable in Settings');
          return false;
        }
      }
      
      return false;
    } catch (e) {
      print('[FCM] Permission check error: $e');
      return false;
    }
  }

  // Public helper: explicitly request notification permission (useful for a settings screen button)
  static Future<AuthorizationStatus> requestNotificationsPermission() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final result = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (Platform.isIOS) {
        try { 
          final apns = await messaging.getAPNSToken(); 
        } catch (e) { 
          // APNs token may not be available immediately
        }
      }
      return result.authorizationStatus;
    } catch (e) {
      print('[FCM] requestNotificationsPermission error: $e');
      return AuthorizationStatus.denied;
    }
  }

  static Future<String> _getPackageId() async {
    if (_cachedPackageId != null) return _cachedPackageId!;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _cachedPackageId = packageInfo.packageName;
      return _cachedPackageId!;
    } catch (e) {
      print('[FCM] Failed to get package ID: $e');
      return 'unknown';
    }
  }

  static Future<void> _autoUpsertIfPossible() async {
    if (_api == null) { return; }
    if (_currentUserId == null) { return; }
    final token = await _awaitFcmToken();
    if (token == null || token.isEmpty) { return; }
    if (_lastSentToken == token) { return; }
    final packageId = await _getPackageId();
    await _api!.upsertToken(
      userId: _currentUserId!,
      token: token,
      platform: Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'unknown'),
      appId: packageId,
      company: _currentCompany,
      extra: _currentExtra,
    );
    _lastSentToken = token;
  }

  // ---------- 2take.it helpers -------------------------------------------
  static Future<void> register2TakeToken({required String company, String? uid}) async {
    _loyaltyCompany = company;
    _loyaltyUid = uid;
    final token = await _awaitFcmToken();
    if (token == null || token.isEmpty) return;
    await _loyalty.saveToken(company: company, uid: uid, token: token);
  }

  static Future<void> register2TakeTokenWith({required String company, String? uid, required String token}) async {
    _loyaltyCompany = company;
    _loyaltyUid = uid;
    _fcmToken ??= token;
    await _loyalty.saveToken(company: company, uid: uid, token: token);
    _lastSentToken = token;
  }

  static Future<void> _autoRegister2TakeIfPossible() async {
    if (_loyaltyCompany == null) { return; }
    final token = await _awaitFcmToken();
    if (token == null || token.isEmpty) { return; }
    if (_lastSentToken == token) { return; }
    await _loyalty.saveToken(company: _loyaltyCompany!, uid: _loyaltyUid, token: token);
    _lastSentToken = token;
  }

  static void setLoggedInUser(String userId, {String? company, Map<String, String>? extra}) {
    _currentUserId = userId;
    _currentCompany = company;
    _currentExtra = extra;
    // Fire and forget
    _autoUpsertIfPossible();
    _autoRegister2TakeIfPossible();
  }

  static void configureApi({
    required String baseUrl,
    Map<String, String>? defaultHeaders,
    String registerPath = '/notifications/register-token',
    String deletePath = '/notifications/token',
    String testPath = '/notifications/test-message',
  }) {
    _api = NotificationsApiClient(
      baseUrl: baseUrl,
      defaultHeaders: defaultHeaders ?? const {'Content-Type': 'application/json'},
      registerPath: registerPath,
      deletePath: deletePath,
      testPath: testPath,
    );
    // no-op
  }

  static Future<void> registerToken({
    required String userId,
    String? company,
    Map<String, String>? extra,
  }) async {
    if (_api == null) return;
    _currentUserId = userId;
    _currentCompany = company;
    _currentExtra = extra;
    await _ensurePermissionIfNeeded();
    await _autoUpsertIfPossible();
  }

  // Debug/testing helper: force a specific token (e.g., on iOS Simulator)
  static Future<void> registerTokenWith({
    required String userId,
    required String token,
    String? company,
    Map<String, String>? extra,
  }) async {
    if (_api == null) return;
    _currentUserId = userId;
    _currentCompany = company;
    _currentExtra = extra;
    _fcmToken ??= token;
    await _ensurePermissionIfNeeded();
    final packageId = await _getPackageId();
    await _api!.upsertToken(
      userId: userId,
      token: token,
      platform: Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'unknown'),
      appId: packageId,
      company: company,
      extra: extra,
    );
    _lastSentToken = token;
  }

  static Future<void> unregisterToken({required String userId}) async {
    if (_api == null) return;
    final token = _fcmToken;
    if (token == null || token.isEmpty) return;
    await _api!.deleteToken(userId: userId, token: token);
  }

  static Future<Map<String, dynamic>> sendTestMessage({
    required String userId,
    String title = 'Test',
    String message = 'Hello from API',
    String? company,
  }) async {
    if (_api == null) return {'error': 'api_not_configured'};
    return _api!.sendTestMessage(userId: userId, title: title, message: message, company: company);
  }
}

// 2take.it loyalty client (form-encoded endpoints on https://2take.it)
class TwoTakeLoyaltyPushClient {
  Future<void> saveToken({
    required String company,
    String? uid,
    required String token,
  }) async {
    final bool isGuest = uid == null || uid.isEmpty;
    final String url = isGuest
        ? 'https://2take.it/loyalty/index.php/site/pushtokensaveguest/c/' + company
        : 'https://2take.it/loyalty/index.php/site/pushtokensave/c/' + company;
    final Map<String, String> body = isGuest ? {'token': token} : {'uid': uid, 'token': token};
    final uri = Uri.parse(url);
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (resp.statusCode >= 300) {
      print('[2TAKE] ERROR: HTTP ${resp.statusCode}');
      throw Exception('loyalty save failed: ${resp.statusCode}');
    }
  }
}

class NotificationsApiClient {
  final String baseUrl;
  final Map<String, String> defaultHeaders;
  final String registerPath;
  final String deletePath;
  final String testPath;

  NotificationsApiClient({
    required this.baseUrl,
    required this.defaultHeaders,
    required this.registerPath,
    required this.deletePath,
    required this.testPath,
  });

  Uri _u(String path) => Uri.parse(baseUrl + path);

  Future<void> upsertToken({
    required String userId,
    required String token,
    required String platform,
    required String appId,
    String? company,
    Map<String, String>? extra,
  }) async {
    // Match backend contract: user_id, fcm_token, device_info.platform/app_id
    final body = <String, dynamic>{
      'user_id': userId,
      'fcm_token': token,
      'device_info': {
        'platform': platform,
        'app_id': appId,
        'device_type': "mobile",
        if (company != null) 'company': company,
        if (extra != null) ...extra,
      },
      if (company != null) 'company_name': company,
    };
    final url = _u(registerPath);
    try {
      final resp = await http.post(url, headers: defaultHeaders, body: jsonEncode(body));
      // Treat JSON body.status >= 300 as failure even if HTTP is 201
      if (resp.statusCode >= 300) {
        throw Exception('Token register failed ${resp.statusCode}: ${resp.body}');
      }
      try {
        final decoded = jsonDecode(resp.body);
        final innerStatus = (decoded is Map && decoded['status'] is num) ? (decoded['status'] as num).toInt() : null;
        if (innerStatus != null && innerStatus >= 300) {
          throw Exception('Token register failed (body.status=$innerStatus): ${resp.body}');
        }
      } catch (_) {
        // ignore decode errors
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteToken({required String userId, required String token}) async {
    final url = _u(deletePath);
    try {
      final body = {'userId': userId, 'token': token};
      final resp = await http.delete(url, headers: defaultHeaders, body: jsonEncode(body));
      if (resp.statusCode >= 300) {
        throw Exception('Token delete failed ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendTestMessage({
    required String userId,
    required String title,
    required String message,
    String? company,
  }) async {
    final url = _u(testPath);
    final body = {'user_id': userId, 'title': title, 'message': message, if (company != null) 'company': company};
    final resp = await http.post(url, headers: defaultHeaders, body: jsonEncode(body));
    return {'status': resp.statusCode, 'body': resp.body};
  }
} 