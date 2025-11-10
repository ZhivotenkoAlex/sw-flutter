import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'services/secure_config_service.dart';
import 'app_config.dart';

class FirebaseConfigLoader {
  /// Load Firebase options from config
  /// 
  /// This replaces the old hardcoded configuration with secure config
  /// fetched from Firestore via SecureConfigService.
  static Future<FirebaseOptions> loadFirebaseOptions(dynamic config) async {
    print('[FirebaseConfig] Loading config for project: ${config.firebaseProject}');
    
    // If it's a SecureAppConfig, use the secure method
    if (config is SecureAppConfig) {
      return config.getFirebaseOptions();
    }
    
    // Fallback for AppConfig (shouldn't happen in production)
    throw UnsupportedError('loadFirebaseOptions requires SecureAppConfig');
  }

  /// Get Firebase options for bootstrap initialization
  /// This uses the development-417611 project with skanuj-wygrywaj database
  static FirebaseOptions getBootstrapOptions() {
    if (Platform.isIOS) {
      // Use iOS-specific API key for development-417611
      return const FirebaseOptions(
        apiKey: 'AIzaSyDxIO20bhKa3y5YLfcuZtv2b5qxaPSW_NM',
        appId: '1:159120615271:ios:2ba734d4e96baccf74f1c2',
        messagingSenderId: '159120615271',
        projectId: 'development-417611',
        storageBucket: 'development-417611.firebasestorage.app',
        databaseURL: 'https://development-417611-default-rtdb.firebaseio.com',
        iosBundleId: 'com.skanujwygrywaj.skanujWygrywaj',
      );
    } else {
      // Use Android-specific API key for development-417611
      return const FirebaseOptions(
        apiKey: 'AIzaSyClPTttdsqmbC68z9HxQsWehxcf0Vhb50M',
        appId: '1:159120615271:android:8e46a63c1ab6102f74f1c2',
        messagingSenderId: '159120615271',
        projectId: 'development-417611',
        storageBucket: 'development-417611.firebasestorage.app',
        databaseURL: 'https://development-417611-default-rtdb.firebaseio.com',
      );
    }
  }
}

