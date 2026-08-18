import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'webview_screen.dart';
import 'firebase_messaging_service.dart';
import 'config_service.dart';
import 'services/secure_config_service.dart';
import 'firebase_config_loader.dart';
import 'flavor_config.dart';
import 'mall_selector_screen.dart';
import 'services/mall_selection_storage.dart';

// Helper function to load messaging app options in background handler
Future<FirebaseOptions?> _loadMessagingAppOptionsFromPrefs() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final projectId = prefs.getString('fcm_messaging_app_project_id');
    if (projectId == null || projectId.isEmpty) return null;
    
    return FirebaseOptions(
      apiKey: prefs.getString('fcm_messaging_app_api_key') ?? '',
      appId: prefs.getString('fcm_messaging_app_app_id') ?? '',
      messagingSenderId: prefs.getString('fcm_messaging_app_messaging_sender_id') ?? '',
      projectId: projectId,
      storageBucket: prefs.getString('fcm_messaging_app_storage_bucket'),
      databaseURL: prefs.getString('fcm_messaging_app_database_url'),
      iosBundleId: Platform.isIOS ? prefs.getString('fcm_messaging_app_ios_bundle_id') : null,
    );
  } catch (e) {
    return null;
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Required for iOS/macOS background isolates
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Try to initialize default app with saved options from foreground
    // With FirebaseAppDelegateProxyEnabled=false, we control initialization
    final savedOptions = await _loadMessagingAppOptionsFromPrefs();
    if (savedOptions != null) {
      try {
        await Firebase.initializeApp(options: savedOptions);
      } catch (e) {
        // Default app might already exist, that's okay
      }
    } else {
      // Fallback to bootstrap options if no saved options
      try {
        await Firebase.initializeApp(options: FirebaseConfigLoader.getBootstrapOptions());
      } catch (e) {
        // Default app might already exist, that's okay
      }
    }
  } catch (e) {
    print('[FCM][bg] Firebase init error: $e');
  }
  
  try {
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    final from = message.from ?? 'null';
    // Keep logs minimal but useful for debugging background delivery
    // Do not add heavy work here; offload to the app after resume/open
    // iOS background "data" pushes require content-available=1 from server
    // to reach this handler when the app is not in foreground
    // ignore: avoid_print
    print('[FCM][bg] ✅ Background message: "$title" / "$body" (from: $from)');
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 0. Initialize flavor configuration
  await FlavorConfig.autoDetect();
  
  SecureAppConfig? config;
  
  // 1. Fetch secure configuration from Firestore
  if (!kIsWeb) {
    try {
      config = await ConfigService.getSecureConfig(forceRefresh: kDebugMode);
    } catch (e) {
      print('[Main] Failed to fetch secure config: $e');
    }
  }
  
  // 2. Initialize Firebase on mobile platforms with correct project
  if (!kIsWeb && config != null) {
    // Register background handler early for iOS/macOS/Android background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    try {
      // Firebase Messaging uses the default Firebase app that's auto-initialized
      // from native platform configs (google-services.json on Android,
      // GoogleService-Info.plist on iOS). Each flavor has its own Firebase project
      // configured statically in these files.
      
      // Initialize Firebase Messaging Service
      // Note: config parameter is accepted for API compatibility but not used for
      // Firebase initialization - native configs are used instead
      await FirebaseMessagingService.initialize(config: config);
      
      // Configure API with hardcoded backend URL (same for all flavors)
      FirebaseMessagingService.configureApi(
        baseUrl: 'https://europe-central2-development-417611.cloudfunctions.net/kanuj-wygrywaj-backend',
        registerPath: '/notifications/register-token',
      );
    } catch (e) {
      print('[Main] Firebase configuration failed, continuing without it: $e');
    }
  }
  
  // 3. Restore WebView session after Android activity recreation (e.g. camera)
  String? restoredWebViewUrl;
  if (config != null && config.showSeletorPage) {
    try {
      restoredWebViewUrl = await MallSelectionStorage.getWebViewUrl(config.companyId);
      if (restoredWebViewUrl != null) {
        print('[Main] Restoring WebView session: $restoredWebViewUrl');
      }
    } catch (e) {
      print('[Main] Failed to restore WebView session: $e');
    }
  }

  // 4. Run app with config (use a fallback if config failed to load)
  if (config != null) {
    runApp(MyApp(config: config, restoredWebViewUrl: restoredWebViewUrl));
  } else {
    // Fallback for web or if config fetch failed
    runApp(const MyApp(config: null));
  }
}

Widget _buildHomeScreen(SecureAppConfig config, String? restoredWebViewUrl) {
  if (config.showSeletorPage && config.selectorItems.isNotEmpty) {
    final sessionUrl = restoredWebViewUrl;
    if (sessionUrl != null && sessionUrl.isNotEmpty) {
      return WebViewScreen(config: config, initialUrl: sessionUrl);
    }
    return MallSelectorScreen(config: config);
  }
  return WebViewScreen(config: config);
}

class MyApp extends StatelessWidget {
  final SecureAppConfig? config;
  final String? restoredWebViewUrl;

  const MyApp({super.key, this.config, this.restoredWebViewUrl});

  @override
  Widget build(BuildContext context) {
    // Determine theme based on isLegacy from configuration
    final bool isLegacyMode = config?.isLegacy ?? true;
    // Different themes for legacy and new mode
    final ThemeData appTheme = isLegacyMode 
      ? ThemeData(
          // Legacy mode - traditional colors
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        )
      : ThemeData(
          // New mode - modern colors
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.deepPurple.shade700,
            foregroundColor: Colors.white,
          ),
        );
    
    return MaterialApp(
      title: isLegacyMode ? 'Skanuj Wygrywaj' : 'Skanuj Wygrywaj New',
      theme: appTheme,
      home: config != null
        ? _buildHomeScreen(config!, restoredWebViewUrl)
        : const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading configuration...'),
                ],
              ),
            ),
          ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
