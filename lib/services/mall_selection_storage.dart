import 'package:shared_preferences/shared_preferences.dart';

/// Persists mall/WebView URL so Android activity recreation (e.g. after camera)
/// does not send the user back to the mall selector.
class MallSelectionStorage {
  static String _key(String companyId) => 'webview_session_url_$companyId';

  static Future<void> saveWebViewUrl(String companyId, String url) async {
    if (companyId.isEmpty || url.isEmpty) return;
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
