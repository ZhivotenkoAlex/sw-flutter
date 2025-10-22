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
  // 2take.it loyalty integration (form-encoded)
  static final TwoTakeLoyaltyPushClient _loyalty = TwoTakeLoyaltyPushClient();
  static String? _loyaltyCompany;
  static String? _loyaltyUid;

  static Future<void> initialize() async {
    try {
      print('[FCM] initialize() start');
      await Firebase.initializeApp();
      try { print('[FCM] projectId=' + (Firebase.app().options.projectId ?? '-')); } catch (_) {}
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
        await _autoRegister2TakeIfPossible();
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        try {
          final title = message.notification?.title ?? '';
          final body = message.notification?.body ?? '';
          print('[FCM] onMessage title="' + title + '" body="' + body + '" data=' + message.data.toString());
        } catch (_) {}
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        try {
          final click = message.data['click_action'] ?? message.notification?.android?.clickAction ?? '';
          print('[FCM] onMessageOpenedApp click="' + click + '" data=' + message.data.toString());
        } catch (_) {}
      });

      _initialized = true;
      // Try an initial upsert if we already know the user
      await _autoUpsertIfPossible();
      await _autoRegister2TakeIfPossible();
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
      // Already granted (full or provisional)
      if (status == AuthorizationStatus.authorized || status == AuthorizationStatus.provisional) {
        if (Platform.isIOS) {
          try {
            final apns = await FirebaseMessaging.instance.getAPNSToken();
            print('[FCM] APNs token: ' + (apns ?? 'null'));
            await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
              alert: true, badge: true, sound: true,
            );
          } catch (e) { print('[FCM] getAPNSToken error: ' + e.toString()); }
        }
        return true;
      }
      // First-run (not decided yet)
      if (status == AuthorizationStatus.notDetermined) {
        if (Platform.isIOS) {
          // Request full permission on iOS so alerts/badges/sounds show immediately
          final perm = await FirebaseMessaging.instance.requestPermission(
            alert: true, badge: true, sound: true, provisional: false,
          );
          final ok = perm.authorizationStatus == AuthorizationStatus.authorized ||
              perm.authorizationStatus == AuthorizationStatus.provisional;
          if (ok) {
            try {
              final apns = await FirebaseMessaging.instance.getAPNSToken();
              print('[FCM] APNs token (post-request): ' + (apns ?? 'null'));
              await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
                alert: true, badge: true, sound: true,
              );
            } catch (e) { print('[FCM] getAPNSToken error: ' + e.toString()); }
          }
          return ok;
        } else {
          // Android: normal prompt
          final perm = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
          return perm.authorizationStatus == AuthorizationStatus.authorized;
        }
      }
      // Denied/ephemeral
      if (status == AuthorizationStatus.denied) {
        // Android can re-prompt; iOS must go to Settings
        if (Platform.isAndroid) {
          final perm = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
          return perm.authorizationStatus == AuthorizationStatus.authorized;
        }
        return false;
      }
      return false;
    } catch (e) {
      print('[FCM] _ensurePermissionIfNeeded error: ' + e.toString());
      return false;
    }
  }

  // Public helper: explicitly request notification permission (useful for a settings screen button)
  static Future<AuthorizationStatus> requestNotificationsPermission() async {
    try {
      final result = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      print('[FCM] requestPermission -> ' + result.authorizationStatus.toString());
      if (Platform.isIOS) {
        try { final apns = await FirebaseMessaging.instance.getAPNSToken(); print('[FCM] APNs token (post-request explicit): ' + (apns ?? 'null')); } catch (e) { print('[FCM] getAPNSToken error: ' + e.toString()); }
      }
      return result.authorizationStatus;
    } catch (e) {
      print('[FCM] requestNotificationsPermission error: ' + e.toString());
      return AuthorizationStatus.denied;
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
      appId: Platform.isAndroid ? 'pl.a2ti.galeriakazimierz' : 'pl.a2ti.galeriakazimierz',
      company: _currentCompany,
      extra: _currentExtra,
    );
    _lastSentToken = token;
    print('[FCM] upsert done for user=' + (_currentUserId ?? '-') + ' tokenLen=' + token.length.toString());
  }

  // ---------- 2take.it helpers -------------------------------------------
  static Future<void> register2TakeToken({required String company, String? uid}) async {
    _loyaltyCompany = company;
    _loyaltyUid = uid;
    final token = await _awaitFcmToken();
    print('[2TAKE] register2TakeToken company=' + company + ' uid=' + (uid ?? '-') + ' tokenLen=' + ((token ?? '').length).toString());
    if (token == null || token.isEmpty) return;
    await _loyalty.saveToken(company: company, uid: uid, token: token);
  }

  static Future<void> register2TakeTokenWith({required String company, String? uid, required String token}) async {
    _loyaltyCompany = company;
    _loyaltyUid = uid;
    _fcmToken ??= token;
    print('[2TAKE] register2TakeTokenWith company=' + company + ' uid=' + (uid ?? '-') + ' tokenLen=' + token.length.toString());
    await _loyalty.saveToken(company: company, uid: uid, token: token);
    _lastSentToken = token;
  }

  static Future<void> _autoRegister2TakeIfPossible() async {
    if (_loyaltyCompany == null) { print('[2TAKE] skip: company not set'); return; }
    final token = await _awaitFcmToken();
    if (token == null || token.isEmpty) { print('[2TAKE] skip: no token'); return; }
    if (_lastSentToken == token) { print('[2TAKE] skip: same token'); return; }
    await _loyalty.saveToken(company: _loyaltyCompany!, uid: _loyaltyUid, token: token);
    _lastSentToken = token;
  }

  static void setLoggedInUser(String userId, {String? company, Map<String, String>? extra}) {
    _currentUserId = userId;
    _currentCompany = company;
    _currentExtra = extra;
    print('[FCM] setLoggedInUser user=' + userId + ' company=' + (company ?? '-'));
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
      appId: Platform.isAndroid ? 'pl.a2ti.galeriakazimierz' : 'pl.a2ti.galeriakazimierz',
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
    final Map<String, String> body = isGuest ? {'token': token} : {'uid': uid!, 'token': token};
    final uri = Uri.parse(url);
    print('[2TAKE] POST ' + url + ' body=' + body.toString());
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    print('[2TAKE] status=' + resp.statusCode.toString() + ' len=' + resp.body.length.toString());
    try {
      final String b = resp.body;
      final String snippet = b.length > 400 ? (b.substring(0, 400) + '…') : b;
      print('[2TAKE] body=' + snippet);
    } catch (_) {}
    if (resp.statusCode >= 300) {
      print('[2TAKE] ERROR body=' + resp.body);
      throw Exception('loyalty save failed: ' + resp.statusCode.toString());
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