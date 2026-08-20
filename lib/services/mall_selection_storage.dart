import 'package:shared_preferences/shared_preferences.dart';

/// Persists mall/WebView URL so Android activity recreation (e.g. after camera)
/// does not send the user back to the mall selector.
class MallSelectionStorage {
  static String _key(String companyId) => 'webview_session_url_$companyId';

  /// URLs safe to restore on cold start (entry points or post-login mall pages).
  /// Intermediate login/signup/oauth routes break when reopened without SPA state.
  static bool isRestorableWebViewUrl(String url) {
    if (url.isEmpty || !url.startsWith('http')) return false;
    final lower = url.toLowerCase();
    if (lower.contains('/fm/1') || lower.contains('redirectafterlogin')) {
      return false;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    if (host.contains('accounts.google.com') ||
        host.contains('facebook.com') ||
        host.contains('appleid.apple.com')) {
      return false;
    }
    if (host == 'login.2take.it') {
      final path = uri.path.toLowerCase();
      if (path.startsWith('/login') ||
          path.startsWith('/signup') ||
          path.startsWith('/api/')) {
        return false;
      }
    }
    return true;
  }

  static Future<void> saveWebViewUrl(String companyId, String url) async {
    if (companyId.isEmpty || url.isEmpty || !isRestorableWebViewUrl(url)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(companyId), url);
  }

  static Future<String?> getWebViewUrl(String companyId) async {
    if (companyId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_key(companyId));
    if (url == null || url.isEmpty) return null;
    return url;
  }

  static Future<void> clearWebViewUrl(String companyId) async {
    if (companyId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(companyId));
  }
}
