import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'webview_screen.dart';
import 'firebase_messaging_service.dart';
import 'config_service.dart';
import 'app_config.dart';
import 'flavor_config.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Required for iOS/macOS background isolates
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  try {
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    // Keep logs minimal but useful for debugging background delivery
    // Do not add heavy work here; offload to the app after resume/open
    // iOS background "data" pushes require content-available=1 from server
    // to reach this handler when the app is not in foreground
    // ignore: avoid_print
    print('[FCM][bg] title="$title" body="$body" data=${message.data}');
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 0. Initialize flavor configuration
  await FlavorConfig.autoDetect();
  print('[Main] Flavor: ${FlavorConfig.instance.name}');
  
  // 1. Fetch app configuration (with cache/mock, or use flavor defaults)
  print('[Main] Fetching app configuration...');
  final config = await ConfigService.getConfig(forceRefresh: kDebugMode);
  print('[Main] Config loaded: isLegacy=${config.isLegacy}, firebase=${config.firebaseProject}');
  
  // 2. Initialize Firebase on mobile platforms with correct project
  if (!kIsWeb) {
    // Register background handler early for iOS/macOS/Android background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    try {
      await FirebaseMessagingService.initialize(config: config);
      
      // Configure API based on config
      final backendUrl = config.backendUrl ?? 
        (config.isLegacy 
          ? 'https://europe-central2-galeria-kazimierz-827d4.cloudfunctions.net/legacy-backend'
          : 'https://europe-central2-development-417611.cloudfunctions.net/kanuj-wygrywaj-backend');
      
      FirebaseMessagingService.configureApi(
        baseUrl: backendUrl,
        registerPath: '/notifications/register-token',
      );
      
      print('[Main] Firebase initialized with project: ${config.firebaseProject}');
    } catch (e) {
      print('[Main] Firebase initialization failed, continuing without it: $e');
    }
  } else {
    print('[Main] Running on web, skipping Firebase initialization');
  }
  
  // 3. Run app with config
  runApp(MyApp(config: config));
}

class MyApp extends StatelessWidget {
  final AppConfig config;
  
  const MyApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skanuj Wygrywaj',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: WebViewScreen(config: config),
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
