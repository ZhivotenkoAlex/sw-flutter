import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class FirebaseMessagingService {
  static String? _fcmToken;
  static bool _initialized = false;
  static NotificationsApiClient? _api;
  static String? _currentUserId;
  static String? _currentCompany;
  static String? _lastSentToken;
  static Map<String, String>? _currentExtra;

  static Future<void> initialize() async {
    try {
      print('[FCM] initialize() start');
      await Firebase.initializeApp();
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      // Proactively ensure permission at startup, but only if not decided yet
      await _ensurePermissionIfNeeded();

      _fcmToken = await FirebaseMessaging.instance.getToken();
      print('[FCM] initial FCM token: ' + (_fcmToken ?? 'null'));

      // If API client configured and we have a user, the host code can call
      // registerToken(userId) afterwards. We only set up refresh forwarding here.
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        print('[FCM] onTokenRefresh -> ' + (newToken));
        await _autoUpsertIfPossible();
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {});

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {});

      _initialized = true;
      // Try an initial upsert if we already know the user
      await _autoUpsertIfPossible();
      print('[FCM] initialize() done');
    } catch (_) { _initialized = true; }
  }

  static String? get fcmToken => _fcmToken;
  static bool get isInitialized => _initialized;

  // ---------- API helpers -------------------------------------------------

  static Future<String?> _awaitFcmToken({Duration timeout = const Duration(seconds: 8)}) async {
    print('[FCM] _awaitFcmToken() begin, current=' + (_fcmToken ?? 'null'));
    // Ensure permission only if not granted
    await _ensurePermissionIfNeeded();
    var t = _fcmToken ?? await FirebaseMessaging.instance.getToken();
    if (t != null && t.isNotEmpty) { _fcmToken = t; print('[FCM] _awaitFcmToken() immediate token'); return t; }
    try { t = await FirebaseMessaging.instance.onTokenRefresh.first.timeout(timeout); print('[FCM] _awaitFcmToken() from onTokenRefresh'); } catch (e) { print('[FCM] _awaitFcmToken() refresh timeout/error: ' + e.toString()); }
    if (t == null || t.isEmpty) {
      try { t = await FirebaseMessaging.instance.getToken(); print('[FCM] getToken after permission'); } catch (e) { print('[FCM] getToken error: ' + e.toString()); }
    }
    if (t != null && t.isNotEmpty) _fcmToken = t;
    print('[FCM] _awaitFcmToken() result=' + (t ?? 'null'));
    return t;
  }

  static Future<bool> _ensurePermissionIfNeeded() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      final status = settings.authorizationStatus;
      print('[FCM] permission status: ' + status.toString());
      if (status == AuthorizationStatus.authorized || status == AuthorizationStatus.provisional) {
        if (Platform.isIOS) {
          try { final apns = await FirebaseMessaging.instance.getAPNSToken(); print('[FCM] APNs token: ' + (apns ?? 'null')); } catch (e) { print('[FCM] getAPNSToken error: ' + e.toString()); }
        }
        return true;
      }
      if (status == AuthorizationStatus.notDetermined) {
        final perm = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
        final ok = perm.authorizationStatus == AuthorizationStatus.authorized || perm.authorizationStatus == AuthorizationStatus.provisional;
        if (Platform.isIOS) {
          try { final apns = await FirebaseMessaging.instance.getAPNSToken(); print('[FCM] APNs token (post-request): ' + (apns ?? 'null')); } catch (e) { print('[FCM] getAPNSToken error: ' + e.toString()); }
        }
        return ok;
      }
      // denied/ephemeral: do not re-prompt (iOS blocks), return false
      return false;
    } catch (e) {
      print('[FCM] _ensurePermissionIfNeeded error: ' + e.toString());
      return false;
    }
  }

  static Future<void> _autoUpsertIfPossible() async {
    if (_api == null) { print('[FCM] skip upsert: api not configured'); return; }
    if (_currentUserId == null) { print('[FCM] skip upsert: user not set'); return; }
    final token = await _awaitFcmToken();
    if (token == null || token.isEmpty) { print('[FCM] skip upsert: token missing'); return; }
    if (_lastSentToken == token) { print('[FCM] skip upsert: token unchanged'); return; }
    await _api!.upsertToken(
      userId: _currentUserId!,
      token: token,
      platform: Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'unknown'),
      appId: Platform.isAndroid ? 'com.skanujwygrywaj.skanuj_wygrywaj' : 'com.skanujwygrywaj.skanujWygrywaj',
      company: _currentCompany,
      extra: _currentExtra,
    );
    _lastSentToken = token;
    print('[FCM] upsert done for user=' + (_currentUserId ?? '-') + ' tokenLen=' + token.length.toString());
  }

  static void setLoggedInUser(String userId, {String? company, Map<String, String>? extra}) {
    _currentUserId = userId;
    _currentCompany = company;
    _currentExtra = extra;
    print('[FCM] setLoggedInUser user=' + userId + ' company=' + (company ?? '-'));
    // Fire and forget
    _autoUpsertIfPossible();
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
    print('[FCM] registerToken called for user=' + userId + ' company=' + (company ?? '-'));
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
    print('[FCM] registerTokenWith override token len=' + token.length.toString());
    await _ensurePermissionIfNeeded();
    await _api!.upsertToken(
      userId: userId,
      token: token,
      platform: Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'unknown'),
      appId: Platform.isAndroid ? 'com.skanujwygrywaj.skanuj_wygrywaj' : 'com.skanujwygrywaj.skanujWygrywaj',
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
        'company': "kazimierz-club-new",
        'app_id': appId,
        platform: "mobile",
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