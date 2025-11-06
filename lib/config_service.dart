import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'app_config.dart';
import 'company_mapping.dart';

class ConfigService {
  static const String _baseUrl = 
      'https://europe-central2-development-417611.cloudfunctions.net/kanuj-wygrywaj-backend';
  static const String _cacheKey = 'app_config_cache';
  static const bool _useMockResponse = true; // Set to false when API is ready

  static AppConfig? _memoryCache;

  /// Get app configuration with caching and TTL
  static Future<AppConfig> getConfig({bool forceRefresh = false}) async {
    // Return memory cache if valid and not forcing refresh
    if (!forceRefresh && _memoryCache != null && !_memoryCache!.isCacheStale) {
      print('[ConfigService] Using memory cache');
      return _memoryCache!;
    }

    // Try to load from persistent cache
    if (!forceRefresh) {
      final cachedConfig = await _loadFromCache();
      if (cachedConfig != null && !cachedConfig.isCacheStale) {
        print('[ConfigService] Using persistent cache');
        _memoryCache = cachedConfig;
        // Refresh in background if getting close to expiry
        if (cachedConfig.fetchedAt.difference(DateTime.now()).inMinutes.abs() > 45) {
          _refreshInBackground();
        }
        return cachedConfig;
      }
    }

    // Fetch fresh config from API
    try {
      print('[ConfigService] Fetching fresh config from API');
      final config = await _fetchFromApi();
      await _saveToCache(config);
      _memoryCache = config;
      return config;
    } catch (e) {
      print('[ConfigService] Failed to fetch from API: $e');
      
      // Fallback to stale cache if available
      final cachedConfig = await _loadFromCache();
      if (cachedConfig != null) {
        print('[ConfigService] Using stale cache as fallback');
        _memoryCache = cachedConfig;
        return cachedConfig;
      }
      
      // Final fallback to default config
      print('[ConfigService] Using default fallback config');
      final defaultConfig = _getDefaultConfig();
      _memoryCache = defaultConfig;
      return defaultConfig;
    }
  }

  /// Fetch configuration from API
  static Future<AppConfig> _fetchFromApi() async {
    if (_useMockResponse) {
      return _getMockResponse();
    }

    final companyId = await CompanyMapping.getCompanyId();
    final url = Uri.parse('$_baseUrl/config?company_id=$companyId');
    
    final response = await http.get(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Request timeout'),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return AppConfig.fromJson(json);
    } else {
      throw Exception('Failed to fetch config: ${response.statusCode}');
    }
  }

  /// Mock response for testing until API is ready
  static Future<AppConfig> _getMockResponse() async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network
    
    final companyId = await CompanyMapping.getCompanyId();
    
    // Mock response - defaults to legacy mode
    return AppConfig(
      webviewUrl: 'https://login.2take.it/?company_name=$companyId&legacy=true&d=9e30d60cdabaa8c6859b7ee737cd943b23d727b3',
      isLegacy: true,
      firebaseProject: 'galeria-kazimierz',
      fetchedAt: DateTime.now(),
      backendUrl: 'https://europe-central2-galeria-kazimierz-827d4.cloudfunctions.net/legacy-backend',
    );
  }

  /// Get default config as ultimate fallback
  static AppConfig _getDefaultConfig() {
    return AppConfig(
      webviewUrl: 'https://login.2take.it/?company_name=galeria-kazimierz&legacy=true&d=9e30d60cdabaa8c6859b7ee737cd943b23d727b3',
      isLegacy: true,
      firebaseProject: 'galeria-kazimierz',
      fetchedAt: DateTime.now(),
      backendUrl: null,
    );
  }

  /// Load config from persistent cache
  static Future<AppConfig?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson == null) return null;
      
      final json = jsonDecode(cachedJson) as Map<String, dynamic>;
      return AppConfig.fromCachedJson(json);
    } catch (e) {
      print('[ConfigService] Failed to load from cache: $e');
      return null;
    }
  }

  /// Save config to persistent cache
  static Future<void> _saveToCache(AppConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(config.toJson());
      await prefs.setString(_cacheKey, json);
    } catch (e) {
      print('[ConfigService] Failed to save to cache: $e');
    }
  }

  /// Refresh config in background without blocking
  static void _refreshInBackground() {
    getConfig(forceRefresh: true).then((config) {
      print('[ConfigService] Background refresh completed');
    }).catchError((e) {
      print('[ConfigService] Background refresh failed: $e');
    });
  }

  /// Clear all caches (useful for debugging)
  static Future<void> clearCache() async {
    _memoryCache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    print('[ConfigService] Cache cleared');
  }
}

