import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'app_config.dart';

class FirebaseConfigLoader {
  /// Load Firebase options based on AppConfig
  static Future<FirebaseOptions> loadFirebaseOptions(AppConfig config) async {
    print('[FirebaseConfig] Loading config for project: ${config.firebaseProject}');
    
    if (Platform.isAndroid) {
      return await _loadAndroidConfig(config);
    } else if (Platform.isIOS) {
      return await _loadIOSConfig(config);
    } else {
      throw UnsupportedError('Platform not supported for Firebase config loading');
    }
  }

  /// Load Android Firebase config from google-services.json
  static Future<FirebaseOptions> _loadAndroidConfig(AppConfig config) async {
    String jsonPath;
    
    if (config.isLegacy) {
      // Legacy uses the default google-services.json in the app folder
      jsonPath = 'google-services.json';
      print('[FirebaseConfig] Loading legacy Android config from default location');
    } else {
      // New app uses the asset file
      jsonPath = 'assets/google-services-new.json';
      print('[FirebaseConfig] Loading new Android config from assets');
    }

    try {
      // Try to load from assets first (works for both cases with proper setup)
      final String jsonString = await rootBundle.loadString(jsonPath);
      final Map<String, dynamic> json = jsonDecode(jsonString);
      
      final projectInfo = json['project_info'] as Map<String, dynamic>;
      final clientList = json['client'] as List;
      final clientInfo = clientList.first as Map<String, dynamic>;
      final clientInfoData = clientInfo['client_info'] as Map<String, dynamic>;
      
      // Find the oauth client for API key
      String? apiKey;
      if (clientInfo.containsKey('api_key')) {
        final apiKeys = clientInfo['api_key'] as List;
        if (apiKeys.isNotEmpty) {
          apiKey = (apiKeys.first as Map<String, dynamic>)['current_key'] as String?;
        }
      }
      
      // Fallback to extracting from services if api_key not found
      if (apiKey == null || apiKey.isEmpty) {
        // Try to get from oauth_client
        if (clientInfo.containsKey('oauth_client')) {
          final oauthClients = clientInfo['oauth_client'] as List;
          for (var client in oauthClients) {
            final clientData = client as Map<String, dynamic>;
            if (clientData['client_type'] == 3) { // Android client type
              // API key might be in the client data
              break;
            }
          }
        }
      }
      
      // If still no API key, use a placeholder (Firebase will use defaults)
      apiKey ??= 'AIzaSyDummy'; // This should not be used in practice

      final options = FirebaseOptions(
        apiKey: apiKey,
        appId: clientInfoData['mobilesdk_app_id'] as String,
        messagingSenderId: projectInfo['project_number'] as String,
        projectId: projectInfo['project_id'] as String,
        storageBucket: projectInfo['storage_bucket'] as String?,
        databaseURL: projectInfo['firebase_url'] as String?,
      );

      print('[FirebaseConfig] Android config loaded: ${options.projectId}');
      return options;
    } catch (e) {
      print('[FirebaseConfig] Error loading Android config: $e');
      
      // Fallback to default config for legacy
      if (config.isLegacy) {
        return _getDefaultLegacyAndroidOptions();
      } else {
        return _getDefaultNewAndroidOptions();
      }
    }
  }

  /// Load iOS Firebase config from GoogleService-Info.plist
  static Future<FirebaseOptions> _loadIOSConfig(AppConfig config) async {
    if (config.isLegacy) {
      print('[FirebaseConfig] Loading legacy iOS config');
    } else {
      print('[FirebaseConfig] Loading new iOS config');
    }

    try {
      // For iOS, the plist files are in the bundle, use rootBundle
      // However, plist parsing in Flutter requires additional logic
      // For simplicity, we'll use the hardcoded known configurations
      // In production, you might want to use a plist parser package
      
      if (config.isLegacy) {
        return _getDefaultLegacyIOSOptions();
      } else {
        return _getDefaultNewIOSOptions();
      }
    } catch (e) {
      print('[FirebaseConfig] Error loading iOS config: $e');
      
      if (config.isLegacy) {
        return _getDefaultLegacyIOSOptions();
      } else {
        return _getDefaultNewIOSOptions();
      }
    }
  }

  // Default configurations extracted from the existing files
  
  static FirebaseOptions _getDefaultLegacyAndroidOptions() {
    return const FirebaseOptions(
      apiKey: 'AIzaSyA1BUbvKpPjTkgLxMOVwawaDW67_f-mhrY',
      appId: '1:839029981684:android:f1773609d3cb500e5e39a1',
      messagingSenderId: '839029981684',
      projectId: 'galeria-kazimierz-827d4',
      storageBucket: 'galeria-kazimierz-827d4.firebasestorage.app',
      databaseURL: 'https://galeria-kazimierz-827d4.firebaseio.com',
    );
  }

  static FirebaseOptions _getDefaultNewAndroidOptions() {
    return const FirebaseOptions(
      apiKey: 'AIzaSyClPTttdsqmbC68z9HxQsWehxcf0Vhb50M',
      appId: '1:159120615271:android:8e46a63c1ab6102f74f1c2',
      messagingSenderId: '159120615271',
      projectId: 'development-417611',
      storageBucket: 'development-417611.firebasestorage.app',
      databaseURL: 'https://development-417611-default-rtdb.firebaseio.com',
    );
  }

  static FirebaseOptions _getDefaultLegacyIOSOptions() {
    return const FirebaseOptions(
      apiKey: 'AIzaSyBo14c6d4SZshTAP-YvqMcHcTTJsXz9F1I',
      appId: '1:839029981684:ios:b33dc71b2f7551e05e39a1',
      messagingSenderId: '839029981684',
      projectId: 'galeria-kazimierz-827d4',
      storageBucket: 'galeria-kazimierz-827d4.firebasestorage.app',
      databaseURL: 'https://galeria-kazimierz-827d4.firebaseio.com',
      iosBundleId: 'it.2take.galeriakazimierz',
    );
  }

  static FirebaseOptions _getDefaultNewIOSOptions() {
    return const FirebaseOptions(
      apiKey: 'AIzaSyDxIO20bhKa3y5YLfcuZtv2b5qxaPSW_NM',
      appId: '1:159120615271:ios:2ba734d4e96baccf74f1c2',
      messagingSenderId: '159120615271',
      projectId: 'development-417611',
      storageBucket: 'development-417611.firebasestorage.app',
      databaseURL: 'https://development-417611-default-rtdb.firebaseio.com',
      iosBundleId: 'com.skanujwygrywaj.skanujWygrywaj',
    );
  }
}

