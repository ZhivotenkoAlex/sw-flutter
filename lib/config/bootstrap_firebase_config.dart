import 'package:firebase_core/firebase_core.dart';

/// Bootstrap Firebase configuration for development-417611
/// 
/// This is a minimal public config used ONLY to:
/// 1. Initialize Firebase on app start
/// 2. Enable App Check authentication
/// 3. Fetch secure config from Firestore (skanuj-wygrywaj database)
/// 
/// After fetching secure config, the app will re-initialize Firebase
/// with the full configuration specific to each flavor.
/// 
/// This config is safe to commit to version control as it contains
/// only public information needed for the initial connection.
class BootstrapFirebaseConfig {
  /// Get bootstrap Firebase options for the development-417611 project
  /// This connects to the skanuj-wygrywaj Firestore database
  /// This is used as the single source of truth for all flavors to fetch their configs
  static FirebaseOptions getBootstrapOptions() {
    // Use Android/iOS specific configs
    return const FirebaseOptions(
      apiKey: 'AIzaSyClPTttdsqmbC68z9HxQsWehxcf0Vhb50M',
      appId: '1:159120615271:android:8e46a63c1ab6102f74f1c2',
      messagingSenderId: '159120615271',
      projectId: 'development-417611',
      storageBucket: 'development-417611.firebasestorage.app',
      databaseURL: 'https://development-417611-default-rtdb.firebaseio.com',
    );
  }

  /// Get iOS-specific bootstrap options
  static FirebaseOptions getBootstrapOptionsIOS() {
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

