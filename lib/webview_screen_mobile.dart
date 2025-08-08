import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'firebase_messaging_service.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController controller;
  bool _bridgeInjected = false;

  @override
  void initState() {
    super.initState();
    final fcmToken = FirebaseMessagingService.fcmToken;
    
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'Flutter',
        onMessageReceived: (JavaScriptMessage message) {
          print('Message from web app: ${message.message}');
        },
      )
      ..addJavaScriptChannel(
        'FirebaseBridge',
        onMessageReceived: (JavaScriptMessage message) {
          print('Firebase bridge message: ${message.message}');
          _handleFirebaseMessage(message.message);
        },
      )
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {
            print('Page started loading: $url');
            // Inject immediately when page starts
            _injectPermissionOverrides();
          },
          onPageFinished: (String url) {
            print('Page finished loading: $url');
            // Inject again to ensure it's there
            _injectPermissionOverrides();
          },
          onWebResourceError: (WebResourceError error) {
            print('Web resource error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation requests, especially for service workers
            print('Navigation request: ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      );
      
    // Inject the permission overrides BEFORE loading the page
    _injectPermissionOverrides().then((_) {
      controller.loadRequest(Uri.parse('https://skanuj-staging.firebaseapp.com/index?company_name=kazimierz-club'));
    });
  }

  Future<void> _injectPermissionOverrides() async {
    if (_bridgeInjected) return; // Prevent multiple injections
    
    final fcmToken = FirebaseMessagingService.fcmToken;
    print('Injecting ULTIMATE permission overrides with token: $fcmToken');
    
    try {
      await controller.runJavaScript('''
        (function() {
          console.log('🚀 ULTIMATE Firebase bridge injection - MAXIMUM OVERRIDE...');
          
          // Define serviceWorkerVersion FIRST
          if (typeof serviceWorkerVersion === 'undefined') {
            window.serviceWorkerVersion = '1.0.0';
            console.log('✅ serviceWorkerVersion defined:', window.serviceWorkerVersion);
          }
          
          // ULTIMATE OVERRIDE - Replace the entire global environment
          console.log('🔔 ULTIMATE notification permission override...');
          
          // Create a completely fake Notification API
          const FakeNotification = function(title, options) {
            console.log('📱 Fake notification created:', title, options);
            this.title = title;
            this.options = options || {};
            return this;
          };
          
          // Set permission to always be granted
          FakeNotification.permission = 'granted';
          
          // Override requestPermission
          FakeNotification.requestPermission = function() {
            console.log('📱 FakeNotification.requestPermission - ALWAYS GRANTED');
            return Promise.resolve('granted');
          };
          
          // Lock the Notification object
          Object.defineProperty(window, 'Notification', {
            value: FakeNotification,
            writable: false,
            configurable: false,
            enumerable: true
          });
          
          // ULTIMATE navigator.permissions override
          if (navigator.permissions) {
            console.log('🔐 ULTIMATE navigator.permissions override...');
            
            const fakePermissions = {
              query: function(permissionDesc) {
                console.log('🔍 FAKE Permission query:', permissionDesc);
                return Promise.resolve({
                  state: 'granted',
                  onchange: null
                });
              }
            };
            
            Object.defineProperty(navigator, 'permissions', {
              value: fakePermissions,
              writable: false,
              configurable: false,
              enumerable: true
            });
            
            console.log('✅ navigator.permissions LOCKED to fake granted version');
          }
          
          // Create Flutter bridge
          window.flutterFCMToken = '$fcmToken';
          window.flutterFirebaseBridge = {
            getFCMToken: function() {
              console.log('🔥 Flutter bridge: getFCMToken called, returning: $fcmToken');
              return Promise.resolve('$fcmToken');
            },
            onNotificationReceived: function(callback) {
              window.flutterNotificationCallback = callback;
              console.log('🔥 Flutter bridge: onNotificationReceived callback registered');
            },
            onNotificationClick: function(callback) {
              window.flutterNotificationClickCallback = callback;
              console.log('🔥 Flutter bridge: onNotificationClick callback registered');
            }
          };
          
          // Firebase config that matches the service worker
          const firebaseConfig = {
            apiKey: "AIzaSyDTaBY5QfDbPXdQGVYIVifdCsbqF4Ed98A",
            authDomain: "development-417611.firebaseapp.com",
            projectId: "development-417611",
            storageBucket: "development-417611.firebasestorage.app",
            messagingSenderId: "159120615271",
            appId: "1:159120615271:web:5eab7cf9ecedc12a74f1c2"
          };
          
          // Override Firebase BEFORE it loads
          window.firebaseConfig = firebaseConfig;
          
          // Create fake Firebase
          const fakeFirebase = {
            messaging: function() {
              console.log('🔥 FAKE Firebase messaging() called');
              return {
                getToken: function(options) {
                  console.log('🔥 FAKE Firebase messaging getToken, returning Flutter token');
                  return Promise.resolve('$fcmToken');
                },
                onMessage: function(callback) {
                  console.log('🔥 FAKE Firebase messaging onMessage registered');
                  window.flutterNotificationCallback = callback;
                  return Promise.resolve();
                },
                onBackgroundMessage: function(callback) {
                  console.log('🔥 FAKE Firebase messaging onBackgroundMessage registered');
                  window.flutterBackgroundMessageCallback = callback;
                  return Promise.resolve();
                },
                requestPermission: function() {
                  console.log('🔥 FAKE Firebase messaging requestPermission - ALWAYS GRANTED');
                  return Promise.resolve('granted');
                }
              };
            }
          };
          
          // Lock Firebase object
          Object.defineProperty(window, 'firebase', {
            value: fakeFirebase,
            writable: false,
            configurable: false,
            enumerable: true
          });
          
          // Enable service worker registration
          if ('serviceWorker' in navigator) {
            console.log('⚙️ Service Worker is supported, enabling registration');
            const originalRegister = navigator.serviceWorker.register;
            navigator.serviceWorker.register = function(scriptURL, options) {
              console.log('⚙️ Service Worker registration intercepted:', scriptURL);
              return originalRegister.call(this, scriptURL, options);
            };
          }
          
          // Create a global function to check if bridge is ready
          window.isFlutterBridgeReady = function() {
            return window.flutterFCMToken && window.flutterFirebaseBridge;
          };
          
          // Dispatch custom event
          window.dispatchEvent(new CustomEvent('flutterBridgeReady', {
            detail: { token: '$fcmToken' }
          }));
          
          console.log('🎉 ULTIMATE Firebase bridge injection completed');
          console.log('🔥 FCM Token available:', '$fcmToken');
          console.log('📱 Notification permissions FAKED and LOCKED');
          console.log('⚙️ Service worker should work with fake permissions');
          
          return 'Ultimate Firebase bridge injected successfully';
        })();
      ''');
      
      _bridgeInjected = true;
      print('✅ ULTIMATE permission overrides injection completed');
      
    } catch (e) {
      print('❌ Error injecting ULTIMATE permission overrides: $e');
    }
  }

  void _handleFirebaseMessage(String message) {
    // Handle messages from web app to Flutter
    print('Handling Firebase message from web: $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: controller),
      ),
    );
  }
} 