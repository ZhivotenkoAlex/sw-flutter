import 'package:flutter/foundation.dart';

class FirebaseMessagingService {
  static String? _fcmToken;
  static bool _initialized = false;

  static Future<void> initialize() async {
    // Only initialize on mobile platforms
    if (kIsWeb) {
      print('Web platform detected, skipping Firebase initialization');
      _fcmToken = 'web-mock-token-${DateTime.now().millisecondsSinceEpoch}';
      _initialized = true;
      return;
    }
    
    try {
      // For mobile, we'll use a mock token for now
      // Firebase can be added later when needed
      _fcmToken = 'mobile-mock-token-${DateTime.now().millisecondsSinceEpoch}';
      _initialized = true;
      print('Firebase messaging initialized successfully (mock mode)');

    } catch (e) {
      print('Firebase initialization error: $e');
      print('Continuing without Firebase messaging...');
      // Generate a mock token for testing
      _fcmToken = 'mock-fcm-token-${DateTime.now().millisecondsSinceEpoch}';
      _initialized = true;
    }
  }

  static String? get fcmToken => _fcmToken;
  static bool get isInitialized => _initialized;
} 