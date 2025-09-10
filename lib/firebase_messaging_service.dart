import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class FirebaseMessagingService {
  static String? _fcmToken;
  static bool _initialized = false;
  static NotificationsApiClient? _api;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();

      // Android 13+ runtime permission
      if (Platform.isAndroid) {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
      }

      // iOS will require APNs setup to actually receive on device; requesting is harmless
      if (Platform.isIOS) {
        await FirebaseMessaging.instance.requestPermission();
      }

      _fcmToken = await FirebaseMessaging.instance.getToken();

      // If API client configured and we have a user, the host code can call
      // registerToken(userId) afterwards. We only set up refresh forwarding here.
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {});

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {});

      _initialized = true;
    } catch (_) { _initialized = true; }
  }

  static String? get fcmToken => _fcmToken;
  static bool get isInitialized => _initialized;

  // ---------- API helpers -------------------------------------------------

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
    final token = _fcmToken;
    if (token == null || token.isEmpty) return;
    await _api!.upsertToken(
      userId: userId,
      token: token,
      platform: Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'unknown'),
      appId: Platform.isAndroid ? 'com.skanujwygrywaj.skanuj_wygrywaj' : 'com.skanujwygrywaj.skanujWygrywaj',
      company: company,
      extra: extra,
    );
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