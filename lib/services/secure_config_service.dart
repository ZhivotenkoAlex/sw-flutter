import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_config.dart';

/// Secure configuration loaded from Firestore
class SecureAppConfig extends AppConfig {
  final Map<String, dynamic> firebaseConfigAndroid;
  final Map<String, dynamic> firebaseConfigIOS;
  final int version;
  final String companyId; // Company ID for API calls and logic (UI/WebView)
  final String? googleAuthCompanyId; // Company ID for Google Authentication (optional, falls back to flavor-based logic)
  final String backendUrl; // Backend URL for API calls

  SecureAppConfig({
    required super.webviewUrl,
    required super.isLegacy,
    required super.firebaseProject,
    required super.fetchedAt,
    required this.firebaseConfigAndroid,
    required this.firebaseConfigIOS,
    required this.version,
    required this.companyId,
    this.googleAuthCompanyId,
    required this.backendUrl,
  });

  factory SecureAppConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    print('[SecureConfig] Parsing Firestore document...');
    print('[SecureConfig] Available keys: ${data.keys.toList()}');

    final companyId = data['companyId'] as String;
    print('[SecureConfig] Loaded companyId: $companyId');

    final googleAuthCompanyId = data['googleAuthCompanyId'] as String?;
    if (googleAuthCompanyId != null) {
      print('[SecureConfig] Loaded googleAuthCompanyId: $googleAuthCompanyId');
    }

    final backendUrl = data['backendUrl'] as String;
    print('[SecureConfig] Loaded backendUrl: $backendUrl');

    return SecureAppConfig(
      webviewUrl: data['webviewUrl'] as String,
      isLegacy: data['isLegacy'] as bool,
      firebaseProject: data['firebaseProject'] as String? ?? 'unknown',
      fetchedAt: DateTime.now(),
      firebaseConfigAndroid: data['firebaseConfigAndroid'] as Map<String, dynamic>,
      firebaseConfigIOS: data['firebaseConfigIOS'] as Map<String, dynamic>,
      version: data['version'] as int? ?? 1,
      companyId: companyId,
      googleAuthCompanyId: googleAuthCompanyId,
      backendUrl: backendUrl,
    );
  }

  factory SecureAppConfig.fromCachedJson(Map<String, dynamic> json) {
    return SecureAppConfig(
      webviewUrl: json['webviewUrl'] as String,
      isLegacy: json['isLegacy'] as bool,
      firebaseProject: json['firebaseProject'] as String,
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      firebaseConfigAndroid: json['firebaseConfigAndroid'] as Map<String, dynamic>,
      firebaseConfigIOS: json['firebaseConfigIOS'] as Map<String, dynamic>,
      version: json['version'] as int? ?? 1,
      companyId: json['companyId'] as String,
      googleAuthCompanyId: json['googleAuthCompanyId'] as String?,
      backendUrl: json['backendUrl'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['firebaseConfigAndroid'] = firebaseConfigAndroid;
    baseJson['firebaseConfigIOS'] = firebaseConfigIOS;
    baseJson['version'] = version;
    baseJson['companyId'] = companyId;
    if (googleAuthCompanyId != null) {
      baseJson['googleAuthCompanyId'] = googleAuthCompanyId;
    }
    baseJson['backendUrl'] = backendUrl;
    return baseJson;
  }

  /// Get Firebase options for the current platform
  FirebaseOptions getFirebaseOptions() {
    final config = Platform.isIOS ? firebaseConfigIOS : firebaseConfigAndroid;
    
    return FirebaseOptions(
      apiKey: config['apiKey'] as String,
      appId: config['appId'] as String,
      messagingSenderId: config['messagingSenderId'] as String,
      projectId: config['projectId'] as String,
      storageBucket: config['storageBucket'] as String?,
      databaseURL: config['databaseURL'] as String?,
      iosBundleId: Platform.isIOS ? config['iosBundleId'] as String? : null,
    );
  }
}

/// Service to fetch secure configuration from Firestore
/// 
/// Flow:
/// 1. Initialize Firebase with bootstrap config (development-417611)
/// 2. Enable App Check for authentication
/// 3. Fetch flavor-specific config from Firestore
/// 4. Cache config locally with version checking
/// 5. Return config to be used for final Firebase initialization
class SecureConfigService {
  static const String _cacheKey = 'secure_app_config_cache';
  static const String _cacheVersionKey = 'secure_app_config_version';
  static const Duration _cacheTimeout = Duration(hours: 24);

  static SecureAppConfig? _memoryCache;

  /// Initialize Firebase with bootstrap config for Firestore config fetching
  /// 
  /// Creates DEFAULT Firebase app if not exists + NAMED "config" app for Firestore
  /// 
  /// CRITICAL: FirebaseFirestore.instanceFor() requires DEFAULT app internally,
  /// even when using named app. So we must ensure DEFAULT app exists first.
  static Future<void> initializeBootstrapFirebase({
    required FirebaseOptions bootstrapOptions,
  }) async {
    // Step 1: Ensure DEFAULT app exists (required by Firestore plugin internals)
    try {
      final defaultApp = Firebase.app();
      print('[SecureConfig] DEFAULT app already exists: ${defaultApp.options.projectId}');
    } catch (e) {
      // DEFAULT app doesn't exist, create it with bootstrap options
      try {
        await Firebase.initializeApp(options: bootstrapOptions);
        print('[SecureConfig] Created DEFAULT app with bootstrap: ${bootstrapOptions.projectId}');
      } catch (e2) {
        print('[SecureConfig] DEFAULT app init error: $e2');
      }
    }
    
    // Step 2: Create NAMED "config" app for explicit config fetching
    try {
      final configApp = await Firebase.initializeApp(
        name: 'config',
        options: bootstrapOptions,
      );
      print('[SecureConfig] Named "config" Firebase app created for: ${bootstrapOptions.projectId}');
      
      // Enable App Check for the named config app
      try {
        await FirebaseAppCheck.instanceFor(app: configApp).activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.deviceCheck,
        );
        print('[SecureConfig] App Check enabled for config app');
      } catch (e) {
        print('[SecureConfig] App Check activation error: $e');
        // Continue without App Check in development
      }
    } catch (e) {
      // Config app might already exist, that's okay
      print('[SecureConfig] Config app init error: $e');
    }
  }

  /// Fetch secure configuration from Firestore
  static Future<SecureAppConfig> fetchConfig({
    required String companyId,
    bool forceRefresh = false,
  }) async {
    // Return memory cache if valid
    if (!forceRefresh && _memoryCache != null) {
      print('[SecureConfig] Using memory cache');
      return _memoryCache!;
    }

    // Try persistent cache first
    if (!forceRefresh) {
      final cachedConfig = await _loadFromCache();
      if (cachedConfig != null && !_isCacheExpired(cachedConfig)) {
        print('[SecureConfig] Using persistent cache');
        _memoryCache = cachedConfig;
        return cachedConfig;
      }
    }

    // Fetch from Firestore
    try {
      print('[SecureConfig] Fetching config from Firestore for: $companyId');
      final config = await _fetchFromFirestore(companyId);
      
      // Save to cache
      await _saveToCache(config);
      _memoryCache = config;
      
      print('[SecureConfig] Config fetched successfully');
      return config;
    } catch (e) {
      print('[SecureConfig] Error fetching from Firestore: $e');
      
      // Fallback to stale cache if available
      final cachedConfig = await _loadFromCache();
      if (cachedConfig != null) {
        print('[SecureConfig] Using stale cache as fallback');
        _memoryCache = cachedConfig;
        return cachedConfig;
      }
      
      // No cache available, throw error
      throw Exception('Failed to fetch config and no cache available: $e');
    }
  }

  /// Fetch configuration from Firestore
  /// Uses the NAMED "config" Firebase app to ensure we always fetch from development-417611
  static Future<SecureAppConfig> _fetchFromFirestore(String companyId) async {
    try {
      print('[SecureConfig] Getting named "config" Firebase app...');
      final configApp = Firebase.app('config'); // Use named config app for development-417611
      print('[SecureConfig] Config app project: ${configApp.options.projectId}');
      
      print('[SecureConfig] Connecting to Firestore database: skanuj-wygrywaj...');
      // Connect to the specific named database in development-417611 project
      final firestore = FirebaseFirestore.instanceFor(
        app: configApp,
        databaseId: 'skanuj-wygrywaj',
      );
      
      print('[SecureConfig] Fetching document: mobile_configs/$companyId');
      final docRef = firestore.collection('mobile_configs').doc(companyId);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        throw Exception('Config document not found for company: $companyId');
      }

      print('[SecureConfig] Document found, parsing...');
      return SecureAppConfig.fromFirestore(docSnapshot);
    } catch (e) {
      print('[SecureConfig] Firestore fetch error: $e');
      print('[SecureConfig] Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Load configuration from persistent cache
  static Future<SecureAppConfig?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      
      if (cachedJson == null) return null;

      final json = jsonDecode(cachedJson) as Map<String, dynamic>;
      return SecureAppConfig.fromCachedJson(json);
    } catch (e) {
      print('[SecureConfig] Cache load error: $e');
      return null;
    }
  }

  /// Save configuration to persistent cache
  static Future<void> _saveToCache(SecureAppConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(config.toJson());
      await prefs.setString(_cacheKey, json);
      await prefs.setInt(_cacheVersionKey, config.version);
      print('[SecureConfig] Config cached');
    } catch (e) {
      print('[SecureConfig] Cache save error: $e');
    }
  }

  /// Check if cache is expired
  static bool _isCacheExpired(SecureAppConfig config) {
    final age = DateTime.now().difference(config.fetchedAt);
    return age > _cacheTimeout;
  }

  /// Clear all caches
  static Future<void> clearCache() async {
    _memoryCache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheVersionKey);
    print('[SecureConfig] Cache cleared');
  }

  /// Check if a newer version is available in cache
  static Future<bool> hasNewerVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedVersion = prefs.getInt(_cacheVersionKey) ?? 0;
      
      if (_memoryCache != null) {
        return cachedVersion > _memoryCache!.version;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
}

