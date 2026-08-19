import 'dart:convert';
import 'dart:collection';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'firebase_messaging_service.dart';
import 'package:flutter/foundation.dart'; // for kDebugMode
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'app_config.dart';
import 'services/secure_config_service.dart';
import 'services/mall_selection_storage.dart';
import 'flavor_config.dart';
import 'package:url_launcher/url_launcher.dart';

Future<NavigationActionPolicy> _navigationPolicyForExternalSchemes(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return NavigationActionPolicy.ALLOW;
  switch (uri.scheme.toLowerCase()) {
    case 'tel':
    case 'mailto':
    case 'sms':
    case 'smsto':
    case 'geo':
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
      return NavigationActionPolicy.CANCEL;
    default:
      return NavigationActionPolicy.ALLOW;
  }
}

/// Static mapping of companyId to Google Sign-In Web Client ID
/// Each company has its own Firebase project for Google Authentication
const Map<String, String> _googleAuthClientIds = {
  'galeria-kazimierz': '839029981684-v8su4cmc72t498k2evmejnohi0pk7v3c.apps.googleusercontent.com',
  'kazimierz-club-new': '159120615271-s2fbutrvvgk39rq71fafmeadksmk4g4d.apps.googleusercontent.com',
  'polbau-demo': '235700920701-0gh8pnikbhue765jjmrmhjiq3l4gqo6c.apps.googleusercontent.com',
};

class WebViewScreen extends StatefulWidget {
  final AppConfig config;
  final String? initialUrl;

  const WebViewScreen({super.key, required this.config, this.initialUrl});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  // Remove WebViewController from webview_flutter; we'll keep a JS eval handle
  InAppWebViewController? _inAppController;
  bool _bridgeInjected = false;
  GoogleSignIn? _googleSignIn;
  // String? _customUrl; // persisted override for HTTPS tunnel

  static const MethodChannel _fbFallbackChannel = MethodChannel('fb_fallback');

  String? _pendingImageDataUrl; // pull-based bridge buffer
  bool _isPicking = false; // prevent duplicate pickers
  String? _lastKnownUrl;
  XFile? _deferredPickedImage;
  bool _rendererCrashedDuringPick = false;
  bool _isDispatchingDeferred = false;
  DateTime? _postDispatchGraceUntil;
  String? _pendingScanUrl;

  static const int _pickImageQuality = 50;
  static const double _pickImageMaxSize = 1024;
  static const int _b64ChunkSize = 24000;
  
  // Secret gesture for FCM token access
  int _secretTapCount = 0;
  DateTime? _lastTapTime;
  static const int _secretTapThreshold = 7;
  static const Duration _secretTapTimeout = Duration(seconds: 1);

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String get _app2tiBridgeJs => '''
    (function(){
      try {
        if (!window.APP2TI) window.APP2TI = {};
        window.APP2TI.startScan = function() {
          try { window.flutter_inappwebview?.callHandler('app2ti_startScan'); } catch(e) { console.error(e); }
        };
        window.APP2TI.startScanForId = function(id) {
          try { window.flutter_inappwebview?.callHandler('app2ti_startScan', { id: String(id||'') }); } catch(e) { console.error(e); }
        };
        window.APP2TI.giveApiToken = function(token, uid) {
          try { window.flutter_inappwebview?.callHandler('app2ti_giveApiToken', { token: String(token||''), uid: String(uid||'') }); } catch(e) { console.error(e); }
        };

        function _forward(msg, targetOrigin){
          try { window.flutter_inappwebview?.callHandler('webview_postMessage', String(msg||''), String(targetOrigin||'*')); } catch(e){ console.error('postMessage bridge failed', e); }
        }
        try {
          var _origParentPostMessage = (window.parent && window.parent.postMessage) ? window.parent.postMessage.bind(window.parent) : null;
          window.parent.postMessage = function(message, targetOrigin) {
            _forward(message, targetOrigin);
            try { if (_origParentPostMessage) _origParentPostMessage(message, targetOrigin); } catch(_) {}
          };
        } catch(e) { console.error('override parent.postMessage failed', e); }

        try {
          var _origWindowPostMessage = window.postMessage ? window.postMessage.bind(window) : null;
          window.postMessage = function(message, targetOrigin) {
            _forward(message, targetOrigin);
            try { if (_origWindowPostMessage) _origWindowPostMessage(message, targetOrigin); } catch(_) {}
          };
        } catch(e) { console.error('override window.postMessage failed', e); }
      } catch(e) { console.error('bridge init failed', e); }
    })();
  ''';

  @override
  void initState() {
    super.initState();
    _lastKnownUrl = widget.initialUrl ?? widget.config.webviewUrl;
    // _loadCustomUrl();
    final fcmToken = FirebaseMessagingService.fcmToken;
    
    // The original controller setup is removed, but the JS bridge and file picker logic
    // are integrated into the InAppWebView's onJsPrompt handler.
    // The _injectPermissionOverrides method is also adapted to use _inAppController.
  }

  // Future<void> _loadCustomUrl() async {
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     setState(() {
  //       _customUrl = prefs.getString('custom_https_url');
  //     });
  //   } catch (_) {}
  // }

  // Future<void> _setCustomUrlDialog() async {
  //   final controller = TextEditingController(text: _customUrl ?? 'https://');
  //   final url = await showDialog<String>(
  //     context: context,
  //     builder: (ctx) {
  //       return AlertDialog(
  //         title: const Text('Set HTTPS URL'),
  //         content: TextField(
  //           controller: controller,
  //           keyboardType: TextInputType.url,
  //           decoration: const InputDecoration(hintText: 'https://<your-domain>'),
  //         ),
  //         actions: [
  //           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
  //           TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
  //         ],
  //       );
  //     },
  //   );
  //   if (url != null && url.isNotEmpty && Uri.tryParse(url)?.hasScheme == true) {
  //     try {
  //       final prefs = await SharedPreferences.getInstance();
  //       await prefs.setString('custom_https_url', url);
  //     } catch (_) {}
  //     if (!mounted) return;
  //     setState(() { _customUrl = url; });
  //     if (_inAppController != null) {
  //       try { await _inAppController!.loadUrl(urlRequest: URLRequest(url: WebUri(url))); } catch (_) {}
  //     }
  //   }
  // }

  Future<void> _injectPermissionOverrides() async {
    final fcmToken = FirebaseMessagingService.fcmToken;
    
    
    try {
      await _inAppController?.evaluateJavascript(source: '''
        (function() {
          if (window.__flutterBridgeInstalled) {
            console.log('♻️ Flutter bridge already installed, skipping re-injection');
            return 'Bridge already installed';
          }
          window.__flutterBridgeInstalled = true;
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
          
                     // Override file input restrictions
           console.log('🔐 Overriding file input restrictions...');
           
           // Prefer native popup handling, but force same-window only for Google OAuth
           (function installGoogleSameWindow(){
             try {
              const isGoogleOAuth = (u) => /accounts\.google\.com|oauth2|gsi\/client|apis\.google\.com/.test(u || '');
              // Route ALL window.open through a prompt the Flutter side handles
              window.open = function(url, name, specs){
                try { window.prompt('window_open', String(url || '')); } catch(_) {}
                return null;
              };
              // Also catch target=_blank
              document.addEventListener('click', function(e){
                const a = e.target && e.target.closest ? e.target.closest('a[target="_blank"]') : null;
                if (a && a.href) {
                  e.preventDefault(); e.stopPropagation();
                  try { window.prompt('window_open', String(a.href)); } catch(_) {}
                }
              }, true);
             } catch(err) { console.error('⚠️ Failed to install Google same-window override', err); }
           })();
           
           // Override getUserMedia for camera/microphone access
           if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
             const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
             navigator.mediaDevices.getUserMedia = function(constraints) {
               return originalGetUserMedia.call(this, constraints);
             };
           }
           
           // TARGETED interception only
          const TARGET_SELECTORS = [
            '[data-flutter-file-input="1"]'
          ];
          
          document.addEventListener('click', function(e) {
            // Only proceed if click matches one of our target selectors
            const matchedSelector = TARGET_SELECTORS.find(sel => e.target.closest(sel));
            if (!matchedSelector) return;
            
            // From here on, we will drive the native picker
            e.preventDefault();
            e.stopPropagation();
            
            let fileInput = null;
            let shouldIntercept = false;
            
            // Direct file input click
            if (e.target.type === 'file') {
              fileInput = e.target;
              shouldIntercept = true;
            }
            // Label pointing to file input
            else if (e.target.tagName === 'LABEL') {
              const forAttr = e.target.getAttribute('for');
              if (forAttr) {
                fileInput = document.getElementById(forAttr);
                if (fileInput && fileInput.type === 'file') {
                  shouldIntercept = true;
                }
              }
            }
            // Button or div that might trigger file input
            else if (e.target.tagName === 'BUTTON' || e.target.tagName === 'DIV' || e.target.tagName === 'SPAN') {
              // Look for file input in nearby elements
              fileInput = e.target.querySelector('input[type="file"]') ||
                         e.target.parentElement?.querySelector('input[type="file"]') ||
                         e.target.closest('div')?.querySelector('input[type="file"]') ||
                         e.target.closest('form')?.querySelector('input[type="file"]');
              
              if (fileInput) {
                shouldIntercept = true;
              }
            }
            // Check if clicked element contains text that suggests file upload
            else if (e.target.textContent && (
              e.target.textContent.toLowerCase().includes('upload') ||
              e.target.textContent.toLowerCase().includes('choose') ||
              e.target.textContent.toLowerCase().includes('select') ||
              e.target.textContent.toLowerCase().includes('file') ||
              e.target.textContent.toLowerCase().includes('photo') ||
              e.target.textContent.toLowerCase().includes('image') ||
              e.target.textContent.toLowerCase().includes('camera') ||
              e.target.textContent.toLowerCase().includes('gallery') ||
              e.target.textContent.toLowerCase().includes('browse') ||
              e.target.textContent.toLowerCase().includes('attach') ||
              e.target.textContent.toLowerCase().includes('scan') ||
              e.target.textContent.toLowerCase().includes('zdjęcie') || // Polish for photo
              e.target.textContent.toLowerCase().includes('prześlij') || // Polish for upload
              e.target.textContent.toLowerCase().includes('wybierz') || // Polish for choose
              e.target.textContent.toLowerCase().includes('dodaj') ||
              e.target.textContent.toLowerCase().includes('galeria') ||
              e.target.textContent.toLowerCase().includes('make photo')
            )) {
              // Look for nearby file input
              fileInput = document.querySelector('input[type="file"]');
              if (fileInput) {
                shouldIntercept = true;
              }
            }
            // Check for Vue.js/React components that might be file upload buttons
            else if (e.target.closest('[class*="upload"]') || 
                     e.target.closest('[class*="file"]') ||
                     e.target.closest('[class*="photo"]') ||
                     e.target.closest('[class*="image"]') ||
                     e.target.closest('[data-testid*="upload"]') ||
                     e.target.closest('[data-testid*="file"]')) {
              fileInput = document.querySelector('input[type="file"]') || 
                         e.target.closest('*').querySelector('input[type="file"]');
              if (fileInput) {
                shouldIntercept = true;
              }
            }
            
            // If no real input found near the targeted button, try to reuse an existing one
            if (!shouldIntercept) {
              const existingInputs = Array.from(document.querySelectorAll('input[type="file"]'));
              const candidate = existingInputs.reverse().find(inp => !inp.disabled);
              if (candidate) {
                fileInput = candidate;
                shouldIntercept = true;
              } else {
                // Create a virtual input attached to the closest form/container
                const clickTarget = e.target;
                const host = clickTarget.closest('form') || clickTarget.closest('[data-flutter-file-input="1"]') || document.body;
                const virtualInput = document.createElement('input');
                virtualInput.type = 'file';
                virtualInput.accept = 'image/*';
                virtualInput.style.display = 'none';
                virtualInput.id = 'flutter-virtual-input';
                virtualInput.setAttribute('data-flutter-virtual', '1');
                host.appendChild(virtualInput);
                fileInput = virtualInput;
                shouldIntercept = true;
              }
            }
            
            if (shouldIntercept && fileInput) {
              e.preventDefault();
              e.stopPropagation();
              
              // Store reference to the file input
              window.currentFileInput = fileInput;
              
              if (window.Flutter && window.Flutter.postMessage) {
                window.Flutter.postMessage('file_picker_request');
              } else {
                console.error('❌ Flutter bridge not available');
              }
              return false;
            }
          }, true);
          
          // CONTINUOUS MONITORING for Module Federation apps
          let scanInterval;
          let lastFileInputCount = 0;
          let lastButtonCount = 0;
          
          function scanForDynamicElements() {
            const fileInputs = document.querySelectorAll('input[type="file"]');
            const allButtons = document.querySelectorAll('button, div[role="button"], span[role="button"], a, div, span');
            
            // Only log if counts changed (new elements loaded)
            if (fileInputs.length !== lastFileInputCount || allButtons.length !== lastButtonCount) {
              
              // Log potential upload buttons
              let potentialUploadButtons = [];
              allButtons.forEach(function(btn) {
                const text = btn.textContent ? btn.textContent.toLowerCase().trim() : '';
                const className = btn.className ? btn.className.toLowerCase() : '';
                
                if (text.includes('upload') || text.includes('photo') || text.includes('image') || 
                    text.includes('choose') || text.includes('select') || text.includes('file') ||
                    text.includes('camera') || text.includes('gallery') || text.includes('browse') ||
                    text.includes('zdjęcie') || text.includes('prześlij') || text.includes('wybierz') ||
                    text.includes('scan') || text.includes('dodaj') ||
                    text.includes('galeria') || text.includes('make photo') ||
                    className.includes('upload') || className.includes('file') || className.includes('photo')) {
                  potentialUploadButtons.push({
                    tagName: btn.tagName,
                    text: text,
                    className: className,
                    id: btn.id
                  });
                }
              });
              
              lastFileInputCount = fileInputs.length;
              lastButtonCount = allButtons.length;
            }
          }
          
          // Initial scan
          setTimeout(scanForDynamicElements, 1000);
          
          // Continuous monitoring for Module Federation apps
          scanInterval = setInterval(scanForDynamicElements, 3000);
          
          // Also use MutationObserver for real-time detection
          const observer = new MutationObserver(function(mutations) {
            let shouldRescan = false;
            mutations.forEach(function(mutation) {
              if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
                // Check if any new nodes contain file inputs or buttons
                mutation.addedNodes.forEach(function(node) {
                  if (node.nodeType === 1) { // Element node
                    if (node.querySelector && (
                        node.querySelector('input[type="file"]') || 
                        node.querySelector('button') ||
                        node.tagName === 'BUTTON' ||
                        (node.textContent && node.textContent.toLowerCase().includes('scan'))
                      )) {
                      shouldRescan = true;
                    }
                  }
                });
              }
            });
            
            if (shouldRescan) {
              setTimeout(scanForDynamicElements, 500);
            }
          });
          
          observer.observe(document.body, {
            childList: true,
            subtree: true
          });
          
          // Also handle focus events on file inputs
          document.addEventListener('focus', function(e) {
            if (e.target.type === 'file') {
              e.preventDefault();
              window.currentFileInput = e.target;
              if (window.Flutter && window.Flutter.postMessage) {
                window.Flutter.postMessage('file_picker_request');
              }
            }
          }, true);
          
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
          // const firebaseConfig = {
          //   apiKey: "AIzaSyDTaBY5QfDbPXdQGVYIVifdCsbqF4Ed98A",
          //   authDomain: "development-417611.firebaseapp.com",
          //   projectId: "development-417611",
          //   storageBucket: "development-417611.firebasestorage.app",
          //   messagingSenderId: "159120615271",
          //   appId: "1:159120615271:web:5eab7cf9ecedc12a74f1c2"
          // };

          const firebaseConfig = {
                apiKey: "AIzaSyBXKJg9G1gk8gS1v0Q4w9fLUU3l3G5E3C0",
                authDomain: "newagent-ctokxh.firebaseapp.com",
                databaseURL: "https://newagent-ctokxh.firebaseio.com",
                projectId: "newagent-ctokxh",
                storageBucket: "newagent-ctokxh.appspot.com",
                messagingSenderId: "592596864276",
                appId: "1:592596864276:web:200106eb3c0597e78c4601",
                measurementId: "G-PM23BW4DES"
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
          
          return 'Ultimate Firebase bridge injected successfully';
        })();
      ''');
      
      // Mark on Dart side; JS side prevents duplicates
      _bridgeInjected = true;
      
    } catch (e) {}
  }

  void _handleFirebaseMessage(String message) {}



  Future<void> _persistWebViewUrl(String url) async {
    if (url.isEmpty || !url.startsWith('http')) return;
    if (!_shouldPersistWebViewUrl(url)) return;
    if (widget.config is! SecureAppConfig) return;
    try {
      await MallSelectionStorage.saveWebViewUrl(
        (widget.config as SecureAppConfig).companyId,
        url,
      );
    } catch (e) {
      debugPrint('[WEBVIEW] persist url error: $e');
    }
  }

  bool _isTransientScanUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('/fm/1') || lower.contains('redirectafterlogin');
  }

  bool _shouldPersistWebViewUrl(String url) => !_isTransientScanUrl(url);

  String _sanitize2takeReloadUrl(String url) {
    return url.replaceAll(
      RegExp(r'redirectAfterLogin/\d+/', caseSensitive: false),
      '',
    );
  }

  bool get _inPostDispatchGrace =>
      _postDispatchGraceUntil != null &&
      DateTime.now().isBefore(_postDispatchGraceUntil!);

  Future<void> _prepareWebViewForExternalPicker() async {
    if (!Platform.isAndroid) return;
    try {
      await _inAppController?.pauseTimers();
      await _inAppController?.pause();
    } catch (e) {
      debugPrint('FPK: prepare webview error: $e');
    }
  }

  Future<void> _resumeWebViewAfterExternalPicker() async {
    if (!Platform.isAndroid) return;
    try {
      await _inAppController?.resumeTimers();
      await _inAppController?.resume();
    } catch (e) {
      debugPrint('FPK: resume webview error: $e');
    }
  }

  Future<void> _reloadWebViewAfterRendererCrash(InAppWebViewController controller) async {
    if (_inPostDispatchGrace) {
      debugPrint('[WEBVIEW] skipping crash reload during post-dispatch grace');
      return;
    }
    try {
      final current = await controller.getUrl();
      final currentStr = current?.toString() ?? '';
      if (currentStr.isNotEmpty && !_isTransientScanUrl(currentStr)) {
        _lastKnownUrl = currentStr;
      }
    } catch (_) {}
    final raw = _pendingScanUrl ??
        _lastKnownUrl ??
        widget.initialUrl ??
        widget.config.webviewUrl;
    if (raw.isEmpty) return;
    final url = _sanitize2takeReloadUrl(raw);
    debugPrint('[WEBVIEW] reloading after renderer crash: $url');
    try {
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    } catch (e) {
      debugPrint('[WEBVIEW] reload after crash failed: $e');
    }
  }

  Future<void> _waitFor2takePageReady() async {
    const maxAttempts = 40;
    String lastReason = 'wait';
    for (var i = 0; i < maxAttempts; i++) {
      try {
        final result = await _inAppController?.evaluateJavascript(source: r'''
          (function(){
            try {
              var host = String(location.host || '').toLowerCase();
              if (host.indexOf('2take') === -1) return 'ready';
              var inp = document.querySelector('input[type="file"]');
              if (!inp) return 'wait:no_input';
              if (window.__flutter2tiReceiptReady) return 'ready';
              return 'wait:no_receipt';
            } catch(e) { return 'ready'; }
          })()
        ''');
        final status = result?.toString() ?? '';
        if (status == 'ready') {
          if (i > 0) debugPrint('FPK: 2take scan page ready after ${i * 500}ms');
          await Future.delayed(const Duration(milliseconds: 300));
          return;
        }
        lastReason = status.isEmpty ? 'wait' : status;
        if (i == 0 || i % 4 == 0) {
          debugPrint('FPK: waiting for scan page ($lastReason) t=${i * 500}ms');
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
    }
    debugPrint('FPK: 2take scan page ready timeout ($lastReason), dispatching anyway');
  }

  Future<void> _maybeDispatchDeferredImage() async {
    if (_deferredPickedImage == null || _isDispatchingDeferred) return;
    _isDispatchingDeferred = true;
    final image = _deferredPickedImage!;
    _deferredPickedImage = null;

    try {
      debugPrint('FPK: waiting for page ready before deferred dispatch');
      await _waitFor2takePageReady();
      _rendererCrashedDuringPick = false;
      debugPrint('FPK: dispatching deferred image => ${image.name}');
      await _dispatchPickedImage(image);
      _postDispatchGraceUntil = DateTime.now().add(const Duration(seconds: 60));
      _pendingScanUrl = null;
      try {
        final currentUrl = await _inAppController?.getUrl();
        final urlStr = currentUrl?.toString() ?? '';
        if (urlStr.isNotEmpty) _lastKnownUrl = urlStr;
      } catch (_) {}
    } finally {
      _isDispatchingDeferred = false;
    }
  }

  ImagePicker _createImagePicker() => ImagePicker();

  Future<XFile?> _pickImage(ImagePicker picker, ImageSource source) {
    return picker.pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: _pickImageQuality,
      maxWidth: _pickImageMaxSize,
      maxHeight: _pickImageMaxSize,
    );
  }

  Future<bool> _isWebViewAlive() async {
    try {
      final result = await _inAppController?.evaluateJavascript(source: '1+1');
      return result != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _reloadWebViewIfRendererCrashedDuringPick() async {
    if (!_rendererCrashedDuringPick) return;
    final controller = _inAppController;
    if (controller == null) return;
    debugPrint('FPK: reloading WebView after camera (renderer had crashed)');
    await _reloadWebViewAfterRendererCrash(controller);
  }

  Future<void> _dispatchPickedImageWhenReady(XFile image, {required bool fromCamera}) async {
    if (fromCamera) {
      _deferredPickedImage = image;
      if (_rendererCrashedDuringPick) {
        debugPrint('FPK: WebView recovering after camera, reload then deferred dispatch');
        await _reloadWebViewIfRendererCrashedDuringPick();
        return;
      }
      if (await _isWebViewAlive()) {
        _deferredPickedImage = null;
        await _dispatchPickedImage(image);
        return;
      }
      debugPrint('FPK: WebView dead after camera, reload then deferred dispatch');
      await _reloadWebViewIfRendererCrashedDuringPick();
      return;
    }
    await _dispatchPickedImage(image);
  }

  Future<void> _persistCurrentFileInputRef() async {
    try {
      await _inAppController?.evaluateJavascript(source: r'''
        (function(){
          try {
            var inp = window.currentFileInput;
            if (!inp) return;
            if (inp.id) sessionStorage.setItem('flutter_pending_file_input_id', inp.id);
            else sessionStorage.removeItem('flutter_pending_file_input_id');
            if (inp.name) sessionStorage.setItem('flutter_pending_file_input_name', inp.name);
            else sessionStorage.removeItem('flutter_pending_file_input_name');
          } catch(e) {}
        })();
      ''');
    } catch (e) {
      debugPrint('FPK: persist file input ref error: $e');
    }
  }

  Future<void> _handleFilePicker() async {
    try {
      debugPrint('FPK: _handleFilePicker() start');
      final ImagePicker picker = _createImagePicker();
      
      // Probe the current <input type=file> for capture/accept hints
      String? metaStr;
      try {
        metaStr = await _inAppController?.evaluateJavascript(source: "(function(){try{var i=window.currentFileInput; if(!i) return '{}'; return JSON.stringify({accept:(i.accept||''), capture:(i.getAttribute&&i.getAttribute('capture'))||'', multiple:!!i.multiple, host:location.host||'', href:location.href||''});}catch(e){return '{}';}})()");
      } catch (e) { debugPrint('FPK: meta probe error: ' + e.toString()); }
      String accept = '';
      String capture = '';
      bool multiple = false;
      String host = '';
      String href = '';
      try {
        if (metaStr != null && metaStr.isNotEmpty && metaStr != 'null') {
          final m = jsonDecode(metaStr);
          accept = (m['accept'] ?? '').toString();
          capture = (m['capture'] ?? '').toString();
          multiple = (m['multiple'] ?? false) == true;
          host = (m['host'] ?? '').toString();
          href = (m['href'] ?? '').toString();
        }
      } catch (e) { debugPrint('FPK: meta parse error: ' + e.toString()); }
      final lowerAccept = accept.toLowerCase();
      final lowerCapture = capture.toLowerCase();
      final lowerHost = host.toLowerCase();
      bool forceCamera = false;
      // Heuristics: if capture attr present or accept hints camera-only, force camera
      if (lowerCapture.isNotEmpty && lowerCapture != 'none') {
        forceCamera = true;
      } else if (lowerAccept.contains('image') && !multiple) {
        // any image mime(s) with single selection implies camera intent for our apps
        forceCamera = true;
      } else if ((lowerHost.endsWith('2take.it') || lowerHost.endsWith('.2take.it')) && !multiple) {
        // product requirement: prefer camera on these hosts
        forceCamera = true;
      }
      debugPrint('FPK: meta host=' + host + ' href=' + href + ' accept=' + accept + ' capture=' + capture + ' multiple=' + multiple.toString() + ' forceCamera=' + forceCamera.toString());
      
      // Show options: Camera or Gallery (always show; was skipping when forceCamera)
      debugPrint('FPK: showing chooser dialog');
      String? result = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          final isPl = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('pl');
          final tTitle = isPl ? 'Wybierz obraz' : 'Select Image';
          final tSubtitle = isPl ? 'Wybierz opcję:' : 'Choose an option:';
          final tCamera = isPl ? 'Aparat' : 'Camera';
          final tGallery = isPl ? 'Galeria' : 'Gallery';
          final tCancel = isPl ? 'Anuluj' : 'Cancel';
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(tTitle, textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tSubtitle, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop('camera'),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(tCamera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop('gallery'),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(tGallery),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Theme.of(context).colorScheme.secondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(tCancel),
                  ),
                ),
              ],
            ),
          );
        },
      );
      debugPrint('FPK: dialog result => ' + (result?.toString() ?? 'null'));

      if (result != null) {
        await _persistCurrentFileInputRef();
        try {
          final currentUrl = await _inAppController?.getUrl();
          final urlStr = currentUrl?.toString() ?? '';
          if (urlStr.isNotEmpty) _lastKnownUrl = urlStr;
          await _persistWebViewUrl(urlStr);
        } catch (_) {}

        XFile? image;
        if (result == 'camera') {
          debugPrint('FPK: launching camera');
          await _prepareWebViewForExternalPicker();
          try {
            image = await _pickImage(picker, ImageSource.camera);
          } catch (e) {
            debugPrint('FPK: camera error => $e');
            image = null;
          } finally {
            await _resumeWebViewAfterExternalPicker();
            if (image == null && _rendererCrashedDuringPick) {
              await _reloadWebViewIfRendererCrashedDuringPick();
              _rendererCrashedDuringPick = false;
            }
          }
          if (image == null) {
            debugPrint('FPK: camera cancelled or no image');
            return;
          }
        } else {
          debugPrint('FPK: opening gallery');
          image = await _pickImage(picker, ImageSource.gallery);
        }
        debugPrint('FPK: picker returned => ${image?.name ?? 'null'}');

        if (image != null) {
          if (href.isNotEmpty) {
            _pendingScanUrl = _sanitize2takeReloadUrl(href);
          }
          await _dispatchPickedImageWhenReady(image, fromCamera: result == 'camera');
        }
      } else {
        debugPrint('FPK: dialog cancelled');
      }
    } catch (e) {
      debugPrint('FPK: _handleFilePicker error: $e');
    }
  }
  
  Future<void> _dispatchPickedImage(XFile picked) async {
    try {
      final bytes = await picked.readAsBytes();
      debugPrint('FPK: dispatch bytes=${bytes.length}');
      final b64 = base64Encode(bytes);
      final name = picked.name.isNotEmpty
          ? picked.name
          : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final escName = name.replaceAll('\\', r'\\').replaceAll("'", r"\'");

      await _inAppController?.evaluateJavascript(
        source: "try { window.__flutterB64Buffer = ''; } catch(e) {}",
      );

      for (var i = 0; i < b64.length; i += _b64ChunkSize) {
        final end = min(i + _b64ChunkSize, b64.length);
        final chunk = b64.substring(i, end);
        final escChunk = chunk.replaceAll('\\', r'\\').replaceAll("'", r"\'");
        await _inAppController?.evaluateJavascript(
          source: "try { window.__flutterB64Buffer = (window.__flutterB64Buffer || '') + '$escChunk'; } catch(e) {}",
        );
      }

      await _inAppController?.evaluateJavascript(
        source: """
          (function(){
            try {
              var dataUrl = 'data:image/jpeg;base64,' + (window.__flutterB64Buffer || '');
              window.__flutterB64Buffer = '';
              window.__dispatchFlutterImage(dataUrl, '$escName');
            } catch(e) {
              console.error('FPK: chunked dispatch error', e);
            }
          })();
        """,
      );
    } catch (e) {
      debugPrint('FPK: dispatch error => $e');
    }
  }

  void _handleSecretTap(Offset globalPosition, BuildContext context) {
    // Convert global position to local position relative to Scaffold
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    
    final localPosition = box.globalToLocal(globalPosition);
    final screenWidth = box.size.width;
    
    // Check if tap is in absolute top-right corner (100x100 pixels from top-right of Scaffold)
    // This works regardless of SafeArea - we check absolute position
    final distanceFromRight = screenWidth - localPosition.dx;
    if (distanceFromRight > 100 || localPosition.dy > 100) {
      _secretTapCount = 0;
      _lastTapTime = null;
      return;
    }
    
    final now = DateTime.now();
    
    // Reset if too much time passed since last tap
    if (_lastTapTime != null && now.difference(_lastTapTime!) > _secretTapTimeout) {
      _secretTapCount = 0;
    }
    
    _secretTapCount++;
    _lastTapTime = now;
    
    // Log in release mode too (using print instead of debugPrint)
    print('[SECRET] Tap count: $_secretTapCount/$_secretTapThreshold at (${localPosition.dx}, ${localPosition.dy})');
    
    if (_secretTapCount >= _secretTapThreshold) {
      _secretTapCount = 0;
      _lastTapTime = null;
      _showFcmTokenDialog(context);
    }
  }
  
  void _showFcmTokenDialog(BuildContext context) {
    final token = FirebaseMessagingService.fcmToken;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('FCM Token'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (token != null) ...[
                  Text(
                    'Token length: ${token.length}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    token,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ] else
                  const Text('Token not available yet'),
              ],
            ),
          ),
          actions: [
            if (token != null)
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: token));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Token copied to clipboard')),
                  );
                },
                child: const Text('Copy'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialUrl = widget.initialUrl ?? widget.config.webviewUrl;
    
    // Determine mode from configuration
    final bool isLegacyMode = widget.config is SecureAppConfig 
        ? (widget.config as SecureAppConfig).isLegacy 
        : true;
    final String modeLabel = isLegacyMode ? 'Legacy' : 'Modern';
    final Color modeColor = isLegacyMode ? Colors.blue : Colors.deepPurple;
    
    print('[WebViewScreen] Loading $modeLabel mode, URL: $initialUrl');
    
    return Scaffold(
      body: GestureDetector(
        onTapDown: (TapDownDetails details) {
          _handleSecretTap(details.globalPosition, context);
        },
        child: Stack(
          children: [
            Column(
              children: [
                // Mode indicator (shown only in debug mode)
                if (kDebugMode)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    color: modeColor.withOpacity(0.9),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isLegacyMode ? Icons.history : Icons.rocket_launch,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$modeLabel Mode',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // WebView
                Expanded(
                  child: SafeArea(
                    top: !kDebugMode, // If not debug, add top SafeArea
                    child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            javaScriptCanOpenWindowsAutomatically: true,
            supportMultipleWindows: true,
            thirdPartyCookiesEnabled: true,
            allowsInlineMediaPlayback: true,
            mediaPlaybackRequiresUserGesture: false,
            useShouldOverrideUrlLoading: true,
            transparentBackground: true,
            useHybridComposition: true,
            domStorageEnabled: true,
            databaseEnabled: true,
            userAgent: 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36 SkanujWygrywaj/Flutter',
          ),
          initialUserScripts: UnmodifiableListView<UserScript>([
            // Flutter Config injection - make backend URL available to all scripts
            UserScript(
              source: '''
                (function(){
                  try {
                    window.FlutterConfig = {
                      backendUrl: '${widget.config is SecureAppConfig ? (widget.config as SecureAppConfig).backendUrl.replaceAll("'", "\\'") : ""}'
                    };
                    console.log('[FLUTTER] Config injected, backendUrl:', window.FlutterConfig.backendUrl);
                  } catch(e) { console.error('[FLUTTER] Config injection failed', e); }
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              forMainFrameOnly: false,
            ),
            // APP2TI/postMessage bridge
            UserScript(
              source: _app2tiBridgeJs,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              forMainFrameOnly: false,
            ),
            // Intercept Google sign-in UI clicks to trigger native GoogleSignIn
            UserScript(
              source: '''
                (function(){
                  try {
                    if (window.__googleNativeInterceptorInstalled) return;
                    window.__googleNativeInterceptorInstalled = true;

                    function isGoogleButton(el){
                      try {
                        if (!el) return false;
                        const tag = (el.tagName||'').toString().toLowerCase();
                        if (tag === 'g-signin-button' || tag === 'googlelogin') return true;
                        const cls = (el.className||'').toString().toLowerCase();
                        const id  = (el.id||'').toString().toLowerCase();
                        const txt = (el.textContent||'').toString().toLowerCase();
                        if (cls.includes('gsi') || cls.includes('g-signin') || cls.includes('abcriobutton') ||
                            cls.includes('google') || cls.includes('signin')) return true;
                        if (id.includes('g_id') || id.includes('google') || id.includes('signin')) return true;
                        if (txt.includes('google')) return true;
                        return false;
                      } catch(_) { return false; }
                    }

                    function tryTriggerAgreementError(){
                      try {
                        if (typeof window.triggerAgreementError === 'function') { window.triggerAgreementError(); return true; }
                        var root = document.querySelector('#app, [data-app], .v-application, [data-v-app]');
                        var vm = root && root.__vue__;
                        function walkVue2(c){ if(!c) return null; if (typeof c.triggerAgreementError === 'function') return c; var kids = c['\x24children']||[]; for (var i=0;i<kids.length;i++){ var r = walkVue2(kids[i]); if (r) return r; } return null; }
                        var target2 = vm && walkVue2(vm);
                        if (target2) { try { target2.triggerAgreementError(); return true; } catch(_){} }
                        if (window.__vue_app__ && window.__vue_app__._instance) {
                          var inst = window.__vue_app__._instance;
                          function walkVue3(n){ if(!n) return null; var p=n.proxy; if(p && typeof p.triggerAgreementError==='function') return p; var ch=[]; try { if (n.subTree && n.subTree.component) ch.push(n.subTree.component); if (n.components) { for (var k in n.components){ if(n.components[k]&&n.components[k].component) ch.push(n.components[k].component);} } } catch(_){} for (var i=0;i<ch.length;i++){ var r=walkVue3(ch[i]); if(r) return r; } return null; }
                          var target3 = walkVue3(inst);
                          if (target3) { try { target3.triggerAgreementError(); return true; } catch(_){} }
                        }
                      } catch(e) { console.error('triggerAgreementError call failed', e); }
                      return false;
                    }

                    document.addEventListener('click', function(e){
                      try {
                        var el = e.target; 
                        if (el && el.closest) {
                          el = el.closest('button, a, g-signin-button, googlelogin, .gsi-material-button, .g-signin-button, .abcRioButton, [data-provider="google"], [id*="g_id" i], [class*="google" i], [class*="signin" i]');
                        }
                        if (!isGoogleButton(el)) return;
                        // If button is visually disabled by class, trigger page error
                        var disabledByClass = false;
                        try { disabledByClass = !!(el && el.closest && el.closest('.no-pointer-events')); } catch(_) {}
                        if (disabledByClass) {
                          console.log('[NATIVE->WEB] google button disabled by class; triggering page error');
                          try {
                            if (!window.__flutterTriggeringAgreement) {
                              window.__flutterTriggeringAgreement = true;
                              tryTriggerAgreementError();
                              setTimeout(function(){ window.__flutterTriggeringAgreement = false; }, 50);
                            }
                          } catch(_) {}
                          return; // let page handlers run too
                        }
                        // Check "regulamin" agreement; if not agreed, let the page handle the click (shows error)
                        var agreed = (function(){
                          try {
                            var cb = document.querySelector('.regulamin-checkbox input[type="checkbox"], .regulamin-checkbox [role="checkbox"], input[role="checkbox"][id^="input-"]');
                            if (!cb) return true; // no checkbox on this screen
                            if (cb.type === 'checkbox') return !!cb.checked;
                            var aria = cb.getAttribute('aria-checked');
                            return aria === 'true';
                          } catch(_) { return true; }
                        })();
                        if (!agreed) { 
                          console.log('[NATIVE->WEB] terms not accepted; triggering page error');
                          try {
                            if (!window.__flutterTriggeringAgreement) {
                              window.__flutterTriggeringAgreement = true;
                              tryTriggerAgreementError();
                              setTimeout(function(){ window.__flutterTriggeringAgreement = false; }, 50);
                            }
                          } catch(_) {}
                          return; // allow page handler too
                        }
                        e.preventDefault(); e.stopPropagation();
                        try { window.prompt('google_native_signin', ''); } catch(_) {}
                        return false;
                      } catch(_) {}
                    }, true);

                // Intercept Apple sign-in button clicks and open Apple's OAuth URL expected by backend
                try {
                  document.addEventListener('click', function(e){
                    try {
                      var t = e.target;
                      var el = (t && t.closest) ? t.closest('button, a, div, span') : t;
                      var txt = (el && (el.innerText || el.textContent || '')).toLowerCase();
                      var aria = String((el && el.getAttribute && el.getAttribute('aria-label')) || '').toLowerCase();
                      var cls = String((el && el.className) || '').toLowerCase();
                      var isAppleBtn = /\bapple\b/.test(txt) || /\bapple\b/.test(aria) || /apple/.test(cls);
                      if (!isAppleBtn) return;
                      e.preventDefault(); e.stopPropagation();
                      try {
                        var q = new URLSearchParams(location.search);
                        var company = q.get('company_name') || '';
                        var clientId = 'it.2take.login';
                        var redirectUrl = 'https://login.2take.it/api/web/user/apple-login?cn=' + encodeURIComponent(company);
                        var responseType = 'code%20id_token';
                        var scope = 'name%20email';
                        var responseMode = 'form_post';
                        var link = 'https://appleid.apple.com/auth/authorize?client_id=' + clientId
                          + '&redirect_uri=' + encodeURIComponent(redirectUrl)
                          + '&response_type=' + responseType
                          + '&scope=' + scope
                          + '&response_mode=' + responseMode;
                        try { console.log('[APPLE][intercept] company=', company, ' redirect=', redirectUrl); } catch(_) {}
                        window.prompt('apple_oauth', link);
                      } catch(_) {}
                      return false;
                    } catch(_) {}
                  }, true);
                } catch(_) {}

                    // Observe DOM for dynamically added Google buttons
                    try {
                      const mo = new MutationObserver(function(muts){ /* no-op; click handler is global */ });
                      mo.observe(document.documentElement||document.body, {childList:true, subtree:true});
                    } catch(_) {}
                  } catch(e) { console.error('google native interceptor failed', e); }
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              forMainFrameOnly: false,
            ),
            // Provide onFlutterGoogleSignIn that logs into the web app directly via its API
            UserScript(
              source: r'''
                (function(){
                  if (typeof window.onFlutterGoogleSignIn === 'function') return;
                  window.onFlutterGoogleSignIn = async function(p){
                    try {
                      const idToken = (p && p.idToken) ? String(p.idToken) : '';
                      if (!idToken) { console.error('No idToken provided'); return false; }

                      const q = new URLSearchParams(location.search);
                      const company = q.get('company_name') || (window.companyconfig && window.companyconfig.getCompanyIdfromUrl && window.companyconfig.getCompanyIdfromUrl()) || '';
                      const legacy = !!q.get('legacy');

                      // Legacy app: use fixed URL like in old_system branch
                      if (legacy || company === 'galeria-kazimierz') {
                        try {
                          const fixedUrl = 'https://login.2take.it/api/web/user/google-login';
                          console.log('[NATIVE->WEB] using fixed legacy login URL', fixedUrl);
                          const r = await fetch(fixedUrl, {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            credentials: 'include',
                            body: JSON.stringify({ access_token: idToken, company_url: company, invite_code: '', legacy })
                          });
                          console.log('[NATIVE->WEB] legacy login http', r.status);
                          const ct = (r.headers && r.headers.get && r.headers.get('content-type')) || '';
                          if (r.ok && ct.indexOf('application/json') >= 0) {
                            const data = await r.json();
                            const urlToGo = (data && data.url) ? String(data.url) : '';
                            if (urlToGo) {
                              console.log('[NATIVE->WEB] legacy login ok; redirect:', urlToGo);
                              location.replace(urlToGo);
                              return true;
                            }
                            if (data && data.token) {
                              const ACCESS = 'access_token_' + company;
                              const REFRESH = 'id_token_' + company;
                              const EXP = 'expirationtime_' + company;
                              localStorage.setItem(ACCESS, data.token);
                              localStorage.setItem(REFRESH, data.refresh_token || '');
                              const expMs = (Number(data.expiry_second || 0)*1000);
                              const expDate = new Date(Date.now() + expMs - 18000);
                              localStorage.setItem(EXP, expDate.toString());
                              console.log('[NATIVE->WEB] legacy login ok; no url, reloading');
                              location.reload();
                              return true;
                            }
                            console.warn('[NATIVE->WEB] legacy login: no url or token in response');
                          } else {
                            console.warn('[NATIVE->WEB] legacy login http', r.status, 'at', fixedUrl);
                          }
                        } catch(e) {
                          console.error('[NATIVE->WEB] legacy login error', e);
                        }
                        return false;
                      }

                      // New app: use dynamic backend URLs
                      let bases = [];
                      
                      // Priority 1: Use Flutter-injected backend URL if available
                      try {
                        if (window.FlutterConfig && window.FlutterConfig.backendUrl) {
                          bases.push(String(window.FlutterConfig.backendUrl).replace(/\/+$/,'/'));
                        }
                      } catch(_) {}
                      
                      // Priority 2: Check web app's own GlobalConfig
                      try {
                        if (window.GlobalConfig && window.GlobalConfig.baseUrl) {
                          bases.push(String(window.GlobalConfig.baseUrl).replace(/\/+$/,'/'));
                        }
                      } catch(_) {}
                      
                      // Fallback: Try web app's own endpoints
                      const origin = location.origin.replace(/\/+$/,'');
                      bases.push(origin + '/api/');
                      bases.push(origin + '/api/web/');
                      
                      // Legacy fallbacks (for non-legacy apps that might need them)
                      bases.push('https://login.2take.it/api/web/');
                      bases.push('https://app.dev.2take.it/api/');
                      bases.push('https://app.blovly.com/api/');
                      bases = Array.from(new Set(bases));

                      async function tryLogin(base){
                        try {
                          // New backend (Cloud Functions) uses 'user/google-auth', old uses 'user/google-login'
                          const isNewBackend = base.includes('.cloudfunctions.net');
                          const endpoint = isNewBackend ? 'user/google-auth' : 'user/google-login';
                          const url = base + endpoint;
                          console.log('[NATIVE->WEB] trying', url);
                          
                          // Build request body based on backend type
                          let requestBody;
                          if (isNewBackend) {
                            // New backend format: user data nested in 'user' object
                            requestBody = {
                              company_url_name: company,
                              inviteCode: null,
                              legacy: legacy,
                              user: {
                                email: p.email || '',
                                name: p.name || '',
                                id: p.id || '',
                                imageUrl: p.imageUrl || '',
                                token: idToken
                              }
                            };
                          } else {
                            // Old backend format
                            requestBody = {
                              access_token: idToken,
                              company_url: company,
                              invite_code: '',
                              legacy: legacy
                            };
                          }
                          
                          const r = await fetch(url, {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify(requestBody)
                          });
                          console.log('[NATIVE->WEB] login http', r.status, 'at', url);
                          if (!r.ok) {
                            console.log('[NATIVE->WEB] response not ok, status:', r.status);
                            return null;
                          }
                          // Try to parse JSON even if content-type is missing/wrong
                          try {
                            const jsonData = await r.json();
                            console.log('[NATIVE->WEB] response parsed, has token:', !!(jsonData.token || jsonData.access_token), 'keys:', Object.keys(jsonData));
                            return jsonData;
                          } catch(parseErr) {
                            console.error('[NATIVE->WEB] JSON parse failed for', url, parseErr);
                            return null;
                          }
                        } catch(e) {
                          console.error('[NATIVE->WEB] login fetch error at', base, e);
                          return null;
                        }
                      }

                      let data = null; let usedBase = null;
                      for (let i = 0; i < bases.length && !data; i++) {
                        const d = await tryLogin(bases[i]);
                        console.log('[NATIVE->WEB] tryLogin result for', bases[i], ':', d ? 'has data' : 'null', d ? 'keys: ' + Object.keys(d) : '');
                        // New backend returns 'access_token', old returns 'token'
                        if (d && (d.token || d.access_token)) { 
                          console.log('[NATIVE->WEB] ✅ Found valid response at', bases[i]);
                          data = d; 
                          usedBase = bases[i]; 
                        } else {
                          console.log('[NATIVE->WEB] ❌ Response invalid, missing token/access_token');
                        }
                      }
                      if (!data || (!data.token && !data.access_token)) { 
                        console.error('[NATIVE->WEB] login failed for all bases', bases); 
                        return false; 
                      }
                      console.log('[NATIVE->WEB] login ok at', usedBase, 'redirect:', (data && data.url) ? data.url : '');

                      const ACCESS = 'access_token_' + company;
                      const REFRESH = 'id_token_' + company;
                      const EXP = 'expirationtime_' + company;
                      // New backend uses 'access_token', old uses 'token'
                      const tokenValue = data.access_token || data.token;
                      localStorage.setItem(ACCESS, tokenValue);
                      localStorage.setItem(REFRESH, data.refresh_token || '');
                      const expMs = (Number(data.expiry_second || 0)*1000);
                      const expDate = new Date(Date.now() + expMs - 18000);
                      localStorage.setItem(EXP, expDate.toString());

                      if (data.url) { 
                        location.href = data.url; 
                      } else {
                        // Check if this is new backend (Cloud Functions)
                        const isNewBackend = usedBase && usedBase.includes('.cloudfunctions.net');
                        if (isNewBackend) {
                          // New backend doesn't return 'url', redirect to main page
                          const origin = location.origin;
                          const redirectUrl = origin + '/?company_name=' + encodeURIComponent(company);
                          console.log('[NATIVE->WEB] redirecting to:', redirectUrl);
                          location.href = redirectUrl;
                        } else {
                          // Old backend: try router first, then reload
                          try { 
                            if (window.__appRouter && window.__appRouter.push) { 
                              window.__appRouter.push({ name: 'rules', query: { company_name: company } }); 
                              return true; 
                            } 
                          } catch(_){ }
                          location.reload();
                        }
                      }
                      return true;
                    } catch(e) { console.error('onFlutterGoogleSignIn error', e); return false; }
                  };
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              forMainFrameOnly: false,
            ),
            // Provide onFlutterAppleSignIn that logs into the web app via its Apple endpoint
            UserScript(
              source: r'''
                (function(){
                  if (typeof window.onFlutterAppleSignIn === 'function') return;
                  window.onFlutterAppleSignIn = async function(p){
                    try {
                      const idToken = (p && p.idToken) ? String(p.idToken) : '';
                      if (!idToken) { console.error('No idToken provided (apple)'); return false; }

                      const q = new URLSearchParams(location.search);
                      const company = q.get('company_name') || (window.companyconfig && window.companyconfig.getCompanyIdfromUrl && window.companyconfig.getCompanyIdfromUrl()) || '';
                      const legacy = !!q.get('legacy');

                      // Legacy app: use fixed URL like in old_system branch
                      if (legacy || company === 'galeria-kazimierz') {
                        try {
                          const fixedUrl = 'https://login.2take.it/api/web/user/apple-login';
                          console.log('[NATIVE->WEB][APPLE] using fixed legacy login URL', fixedUrl);
                          const r = await fetch(fixedUrl, {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            credentials: 'include',
                            body: JSON.stringify({ access_token: idToken, company_url: company, invite_code: '', legacy })
                          });
                          const ct = (r.headers && r.headers.get && r.headers.get('content-type')) || '';
                          if (r.ok && ct.indexOf('application/json') >= 0) {
                            const data = await r.json();
                            console.log('[NATIVE->WEB][APPLE] legacy login ok; redirect:', (data && data.url) ? data.url : 'reload');
                            if (data && data.url) { location.replace(data.url); } else { location.reload(); }
                            return true;
                          } else {
                            console.warn('[NATIVE->WEB][APPLE] legacy login http', r && r.status);
                          }
                        } catch (e) { console.error('[NATIVE->WEB][APPLE] legacy login error', e); }
                        return false;
                      }

                      // New app: use dynamic backend URLs
                      let bases = [];
                      try { if (window.FlutterConfig && window.FlutterConfig.backendUrl) { bases.push(String(window.FlutterConfig.backendUrl).replace(/\/+$/,'/')); } } catch(_) {}
                      const origin = location.origin.replace(/\/+$/,'');
                      bases.push(origin + '/api/');

                      for (const base of bases) {
                        try {
                          // New backend uses 'user/apple-auth', old uses 'user/apple-login'
                          const isNewBackend = base.includes('.cloudfunctions.net');
                          const endpoint = isNewBackend ? 'user/apple-auth' : 'user/apple-login';
                          const url = base + endpoint;
                          console.log('[NATIVE->WEB][APPLE] trying', url);
                          const r = await fetch(url, {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ access_token: idToken, company_url: company, invite_code: '', legacy })
                          });
                          console.log('[NATIVE->WEB][APPLE] login http', r.status);
                          if (r.ok) {
                            // Try to parse JSON even if content-type is missing/wrong
                            try {
                              const data = await r.json();
                              console.log('[NATIVE->WEB][APPLE] login ok; redirect:', (data && data.url) ? data.url : 'reload');
                              if (data && data.url) { location.replace(data.url); } else { location.reload(); }
                              return true;
                            } catch(parseErr) {
                              console.error('[NATIVE->WEB][APPLE] JSON parse failed', parseErr);
                            }
                          }
                        } catch (e) { console.error('[NATIVE->WEB][APPLE] login error at', base, e); }
                      }
                      return false;
                    } catch(e) { console.error('onFlutterAppleSignIn error', e); return false; }
                  }
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              forMainFrameOnly: false,
            ),
            // Do not override APP2TI provided by the page; we only call into it.
            // Soft-disable web push errors by stubbing unsupported APIs early
            UserScript(
              source: '''
                (function(){
                  try {
                    // Mark host
                    window.__inFlutterHost = true;
                    // Stub Notification to avoid permission errors
                    try {
                      if (!('Notification' in window) || typeof Notification.requestPermission !== 'function') {
                        var FakeNotification = function(){}; 
                        FakeNotification.permission = 'granted';
                        FakeNotification.requestPermission = function(){ return Promise.resolve('granted'); };
                        Object.defineProperty(window, 'Notification', { value: FakeNotification, configurable: true });
                      }
                    } catch(_){ }
                    // Minimal service worker facade so code that probes it does not explode
                    try {
                      if (!('serviceWorker' in navigator)) {
                        Object.defineProperty(navigator, 'serviceWorker', { value: {
                          addEventListener: function(){},
                          getRegistrations: function(){ return Promise.resolve([]); },
                          register: function(){ return Promise.reject(new Error('unsupported')); }
                        }, configurable: true });
                      }
                    } catch(_){ }
                  } catch(_){ }
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            ),
            UserScript(
              source: '''
                (function(){
                  try {
                    // Lightweight, reliable host marker for the web app
                    if (!window.__inFlutterHost) {
                      window.__inFlutterHost = true;
                      try { window.dispatchEvent(new CustomEvent('flutterHostDetected')); } catch(_){}
                    }
                  } catch(_){ }
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            ),
            UserScript(
              source: '''
                (function(){
                  try {
                    if (window.__pre_oauth_installed) return;
                    window.__pre_oauth_installed = true;
                    // Route window.open and _blank clicks to Flutter via prompt BEFORE libs load
                    const isGoogleOAuth = function(u){
                      try { return /accounts\.google\.com|oauth2|gsi\/client|googleusercontent\.com/.test(String(u||'')); } catch(_) { return false; }
                    };
                    window.open = function(url, name, specs){
                      try {
                        if (isGoogleOAuth(url)) { location.href = String(url); return null; }
                        window.prompt('window_open', String(url || ''));
                      } catch(_) {}
                      return null;
                    };
                    document.addEventListener('click', function(e){
                      var a = e.target && e.target.closest ? e.target.closest('a[target="_blank"]') : null;
                      if (a && a.href) {
                        e.preventDefault(); e.stopPropagation();
                        if (isGoogleOAuth(a.href)) { try { location.href = String(a.href); } catch(_) {} }
                        else { try { window.prompt('window_open', String(a.href)); } catch(_) {} }
                      }
                    }, true);
                    document.addEventListener('submit', function(e){
                      var f = e.target; 
                      if (f && f.getAttribute && f.getAttribute('target') == '_blank') {
                        try { f.setAttribute('target','_self'); } catch(_) {}
                      }
                    }, true);
                  } catch(err) { console.error('⚠️ Pre-inject failed', err); }
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            ),
            UserScript(
              source: '''
                (function(){
                  try {
                    // Track listeners for debugging
                    if (!window.__flutterListenerTrackerInstalled) {
                      window.__flutterListenerTrackerInstalled = true;
                      window.__flutterFileSelectedHandlers = 0;
                      window.__lastDispatchToken = null;
                      window.__lastDispatchTime = 0;
                      var ET = window.EventTarget && window.EventTarget.prototype;
                      if (ET && ET.addEventListener) {
                        var _origAdd = ET.addEventListener;
                        ET.addEventListener = function(type, listener, options){
                          try { if (String(type) === 'flutter_file_selected') { window.__flutterFileSelectedHandlers = (window.__flutterFileSelectedHandlers||0) + 1;} } catch(_) {}
                          return _origAdd.apply(this, arguments);
                        };
                      }
                    }
                  } catch(e) { console.error('⚠️ Listener tracker error', e); }
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            ),
            UserScript(
              source: '''
                (function(){
                  try {
                    // Shim for Flutter bridge using prompt
                    if (!window.Flutter) window.Flutter = {};
                    if (typeof window.Flutter.postMessage !== 'function') {
                      window.Flutter.postMessage = function(message) {
                        try { return window.prompt(String(message || ''), ''); } catch (e) { return null; }
                      };
                      console.log('✅ Flutter.postMessage shim installed');
                    }
                    // Provide HostApp/FlutterHost compatible bridge expected by the web app
                    var hostObj = {
                      postMessage: function(payload) {
                        try {
                          var msg = payload;
                          if (typeof payload === 'string') { try { msg = JSON.parse(payload); } catch(_) {} }
                          console.log('🎯 HostApp.postMessage received:', msg);
                          if (msg && (msg.type === 'chooseImage' || msg.type === 'choosePhoto')) {
                            try { window.prompt('file_picker_request', ''); } catch(_) {}
                            return 'ok';
                          }
                        } catch(err) { console.log('⚠️ HostApp.postMessage error', err); }
                        return null;
                      }
                    };
                    if (!window.HostApp) window.HostApp = hostObj;
                    if (!window.FlutterHost) window.FlutterHost = hostObj;
                    console.log('✅ HostApp/FlutterHost shim installed');
                  } catch (e) { console.log('⚠️ postMessage shim error', e); }
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            ),
            UserScript(
              source: '''
                (function(){
                  try {
                    console.log('✅ File input intercept installed');
                    // Intercept file input programmatic/native openings
                    var HTMLInputProto = window.HTMLInputElement && window.HTMLInputElement.prototype;
                    if (HTMLInputProto) {
                      var __origClick = HTMLInputProto.click;
                      if (typeof __origClick === 'function') {
                        HTMLInputProto.click = function() {
                          try {
                            if (this && String(this.type).toLowerCase() === 'file') {
                              window.currentFileInput = this;
                              try { console.log('[FPK-JS] click() on file input accept=', this.accept, ' capture=', this.getAttribute && this.getAttribute('capture'), ' multiple=', !!this.multiple); } catch(_) {}
                              try { window.Flutter && window.Flutter.postMessage && window.Flutter.postMessage('file_picker_request'); } catch(_) {}
                              return; // swallow native chooser
                            }
                          } catch(_) {}
                          return __origClick.apply(this, arguments);
                        };
                      }
                      var __origShowPicker = HTMLInputProto.showPicker;
                      if (typeof __origShowPicker === 'function') {
                        HTMLInputProto.showPicker = function() {
                          try {
                            if (this && String(this.type).toLowerCase() === 'file') {
                              window.currentFileInput = this;
                              try { console.log('[FPK-JS] showPicker() on file input accept=', this.accept, ' capture=', this.getAttribute && this.getAttribute('capture'), ' multiple=', !!this.multiple); } catch(_) {}
                              try { window.Flutter && window.Flutter.postMessage && window.Flutter.postMessage('file_picker_request'); } catch(_) {}
                              return; // swallow native chooser
                            }
                          } catch(_) {}
                          return __origShowPicker.apply(this, arguments);
                        };
                      }
                    }
                    // Direct tap on input[type=file]
                    document.addEventListener('click', function(e){
                      try {
                        var inp = e.target && e.target.closest ? e.target.closest('input[type="file"]') : null;
                        if (inp && String(inp.type).toLowerCase() === 'file') {
                          e.preventDefault(); e.stopPropagation();
                          window.currentFileInput = inp;
                          try { console.log('[FPK-JS] direct input click accept=', inp.accept, ' capture=', inp.getAttribute && inp.getAttribute('capture'), ' multiple=', !!inp.multiple); } catch(_) {}
                          try { window.Flutter && window.Flutter.postMessage && window.Flutter.postMessage('file_picker_request'); } catch(_) {}
                        }
                      } catch(_) {}
                    }, true);
                    // Capture label clicks that target file inputs
                    document.addEventListener('click', function(e){
                      try {
                        var label = e.target && e.target.closest ? e.target.closest('label[for], label') : null;
                        if (label) {
                          var forAttr = label.getAttribute('for');
                          var inp = forAttr ? document.getElementById(forAttr) : (label.querySelector && label.querySelector('input[type="file"]'));
                          if (inp && String(inp.type).toLowerCase() === 'file') {
                            e.preventDefault(); e.stopPropagation();
                            window.currentFileInput = inp;
                            try { console.log('[FPK-JS] label click -> input accept=', inp.accept, ' capture=', inp.getAttribute && inp.getAttribute('capture'), ' multiple=', !!inp.multiple); } catch(_) {}
                            try { window.Flutter && window.Flutter.postMessage && window.Flutter.postMessage('file_picker_request'); } catch(_) {}
                          }
                        }
                      } catch(_) {}
                    }, true);
                    // Observe inputs becoming type=file to log attributes
                    try {
                      var mo = new MutationObserver(function(muts){
                        muts.forEach(function(m){
                          if (m.type === 'attributes' && m.attributeName === 'type') {
                            var t = m.target; try {
                              if (t && String(t.type).toLowerCase() === 'file') {
                                console.log('[FPK-JS] mutated to type=file accept=', t.accept, ' capture=', t.getAttribute && t.getAttribute('capture'), ' multiple=', !!t.multiple);
                              }
                            } catch(_) {}
                          }
                        });
                      });
                      mo.observe(document.documentElement||document.body, {subtree:true, attributes:true, attributeFilter:['type']});
                    } catch(_) {}
                  } catch (e) { console.error('⚠️ file input intercept failed', e); }
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              forMainFrameOnly: false,
            ),
            UserScript(
              source: '''
                (function(){
                  try {
                    if (!window.__dispatchFlutterImage) {
                      window.__dispatchFlutterImage = function(dataUrl, fileName) {
                        try {
                          var detail = { fileName: String(fileName || 'photo.jpg'), fileData: String(dataUrl || '') };
                          var now = Date.now();
                          window.__lastDispatchTime = now;
                          window.__lastFlutterImage = detail;
                          // Single dispatch path only
                          try { window.dispatchEvent(new CustomEvent('flutter_file_selected', { detail: detail, bubbles: true, composed: true })); } catch(e){}
                          return true;
                        } catch (e) {
                          console.error('⚠️ __dispatchFlutterImage error', e);
                          return false;
                        }
                      };
                    }
                  } catch(e) { console.error('⚠️ install __dispatchFlutterImage failed', e); }
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            ),
            UserScript(
              source: r'''
                (function(){
                  try {
                    function isFacebookButton(el){
                      try {
                        if (!el) return false;
                        var n = (el.nodeName||'').toLowerCase();
                        if (n === 'fblogin') return true;
                        var cls = (el.className||'').toString().toLowerCase();
                        var id  = (el.id||'').toString().toLowerCase();
                        var txt = (el.textContent||'').toString().toLowerCase();
                        if (cls.includes('facebook') || cls.includes('fb-login') || cls.includes('social-icon--facebook')) return true;
                        if (id.includes('facebook') || id.includes('fb')) return true;
                        if (txt.includes('facebook')) return true;
                        return false;
                      } catch(_) { return false; }
                    }

                    document.addEventListener('click', function(e){
                      try {
                        var el = e.target;
                        if (el && el.closest) {
                          el = el.closest('button, a, fblogin, [data-provider="facebook"], [class*="facebook" i], [class*="fb-login" i]');
                        }
                        if (!isFacebookButton(el)) return;
                        // Disabled by class
                        var disabledByClass = false;
                        try { disabledByClass = !!(el && el.closest && el.closest('.no-pointer-events')); } catch(_) {}
                        if (disabledByClass) {
                          console.log('[NATIVE->WEB] facebook button disabled by class; triggering page error');
                          try { if (!window.__flutterTriggeringAgreement) { window.__flutterTriggeringAgreement = true; tryTriggerAgreementError(); setTimeout(function(){ window.__flutterTriggeringAgreement = false; }, 50); } } catch(_) {}
                          return; // let page show its own error too
                        }
                        // Check checkbox
                        var agreed = (function(){
                          try {
                            var cb = document.querySelector('.regulamin-checkbox input[type="checkbox"], .regulamin-checkbox [role="checkbox"], input[role="checkbox"][id^="input-"]');
                            if (!cb) return true;
                            if (cb.type === 'checkbox') return !!cb.checked;
                            var aria = cb.getAttribute('aria-checked');
                            return aria === 'true';
                          } catch(_) { return true; }
                        })();
                        if (!agreed) {
                          console.log('[NATIVE->WEB] terms not accepted; triggering page error (fb)');
                          try { if (!window.__flutterTriggeringAgreement) { window.__flutterTriggeringAgreement = true; tryTriggerAgreementError(); setTimeout(function(){ window.__flutterTriggeringAgreement = false; }, 50); } } catch(_) {}
                          return;
                        }
                        e.preventDefault(); e.stopPropagation();
                        try { window.prompt('facebook_native_signin', ''); } catch(_) {}
                        return false;
                      } catch(_) {}
                    }, true);
                  } catch(e) { console.error('facebook native interceptor failed', e); }
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              forMainFrameOnly: false,
            ),
            // Provide onFlutterFacebookSignIn that logs into the web app directly via its API
            UserScript(
              source: r'''
                (function(){
                  if (typeof window.onFlutterFacebookSignIn === 'function') return;
                  window.onFlutterFacebookSignIn = async function(p){
                    try {
                      const accessToken = (p && p.accessToken) ? String(p.accessToken) : '';
                      if (!accessToken) { console.error('No accessToken provided'); return false; }

                      const q = new URLSearchParams(location.search);
                      const company = q.get('company_name') || (window.companyconfig && window.companyconfig.getCompanyIdfromUrl && window.companyconfig.getCompanyIdfromUrl()) || '';
                      const legacy = !!q.get('legacy');

                      // Legacy app: use fixed URL like in old_system branch
                      if (legacy || company === 'galeria-kazimierz') {
                        try {
                          const fixedUrl = 'https://login.2take.it/api/web/user/fblogin';
                          console.log('[NATIVE->WEB] using fixed legacy login URL', fixedUrl);
                          const r = await fetch(fixedUrl, {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            credentials: 'include',
                            body: JSON.stringify({ access_token: accessToken, company_url: company, invite_code: '', legacy })
                          });
                          console.log('[NATIVE->WEB] legacy login http', r.status);
                          const ct = (r.headers && r.headers.get && r.headers.get('content-type')) || '';
                          if (r.ok && ct.indexOf('application/json') >= 0) {
                            const data = await r.json();
                            const urlToGo = (data && data.url) ? String(data.url) : '';
                            if (urlToGo) {
                              console.log('[NATIVE->WEB] legacy login ok; redirect:', urlToGo);
                              location.replace(urlToGo);
                              return true;
                            }
                            if (data && data.token) {
                              const ACCESS = 'access_token_' + company;
                              const REFRESH = 'id_token_' + company;
                              const EXP = 'expirationtime_' + company;
                              localStorage.setItem(ACCESS, data.token);
                              localStorage.setItem(REFRESH, data.refresh_token || '');
                              const expMs = (Number(data.expiry_second || 0)*1000);
                              const expDate = new Date(Date.now() + expMs - 18000);
                              localStorage.setItem(EXP, expDate.toString());
                              console.log('[NATIVE->WEB] legacy login ok; no url, reloading');
                              location.reload();
                              return true;
                            }
                            console.warn('[NATIVE->WEB] legacy login: no url or token in response');
                          } else {
                            console.warn('[NATIVE->WEB] legacy login http', r.status, 'at', fixedUrl);
                          }
                        } catch(e) {
                          console.error('[NATIVE->WEB] legacy login error', e);
                        }
                        return false;
                      }

                      // New app: use dynamic backend URLs
                      let bases = [];
                      
                      // Priority 1: Use Flutter-injected backend URL if available
                      try {
                        if (window.FlutterConfig && window.FlutterConfig.backendUrl) {
                          bases.push(String(window.FlutterConfig.backendUrl).replace(/\/+$/,'/'));
                        }
                      } catch(_) {}
                      
                      // Priority 2: Check web app's own GlobalConfig
                      try {
                        if (window.GlobalConfig && window.GlobalConfig.baseUrl) {
                          bases.push(String(window.GlobalConfig.baseUrl).replace(/\/+$/,'/'));
                        }
                      } catch(_) {}
                      
                      // Fallback: Try web app's own endpoints
                      const origin = location.origin.replace(/\/+$/,'');
                      bases.push(origin + '/api/');
                      bases.push(origin + '/api/web/');
                      
                      // Legacy fallbacks (for non-legacy apps that might need them)
                      bases.push('https://login.2take.it/api/web/');
                      bases.push('https://app.dev.2take.it/api/');
                      bases.push('https://app.blovly.com/api/');
                      bases = Array.from(new Set(bases));

                      async function tryLogin(base){
                        try {
                          // New backend (Cloud Functions) uses 'user/facebook-auth', old uses 'user/facebook-login'
                          const isNewBackend = base.includes('.cloudfunctions.net');
                          const endpoint = isNewBackend ? 'user/facebook-auth' : 'user/facebook-login';
                          const url = base + endpoint;
                          console.log('[NATIVE->WEB] trying', url);
                          const r = await fetch(url, {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ access_token: accessToken, company_url: company, invite_code: '', legacy })
                          });
                          console.log('[NATIVE->WEB] login http', r.status, 'at', url);
                          if (!r.ok) {
                            return null;
                          }
                          // Try to parse JSON even if content-type is missing/wrong
                          try {
                            return await r.json();
                          } catch(parseErr) {
                            console.error('[NATIVE->WEB] JSON parse failed for', url, parseErr);
                            return null;
                          }
                        } catch(e) {
                          console.error('[NATIVE->WEB] login fetch error at', base, e);
                          return null;
                        }
                      }

                      let data = null; let usedBase = null;
                      for (let i = 0; i < bases.length && !data; i++) {
                        const d = await tryLogin(bases[i]);
                        if (d && d.token) { data = d; usedBase = bases[i]; }
                      }
                      if (!data || !data.token) { console.error('[NATIVE->WEB] login failed for all bases', bases); return false; }
                      console.log('[NATIVE->WEB] login ok at', usedBase, 'redirect:', (data && data.url) ? data.url : '');

                      const ACCESS = 'access_token_' + company;
                      const REFRESH = 'id_token_' + company;
                      const EXP = 'expirationtime_' + company;
                      localStorage.setItem(ACCESS, data.token);
                      localStorage.setItem(REFRESH, data.refresh_token || '');
                      const expMs = (Number(data.expiry_second || 0)*1000);
                      const expDate = new Date(Date.now() + expMs - 18000);
                      localStorage.setItem(EXP, expDate.toString());

                      if (data.url) { location.href = data.url; }
                      else {
                        try { if (window.__appRouter && window.__appRouter.push) { window.__appRouter.push({ name: 'rules', query: { company_name: company } }); return true; } } catch(_){ }
                        location.reload();
                      }
                      return true;
                    } catch(e) { console.error('onFlutterFacebookSignIn error', e); return false; }
                  };
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              forMainFrameOnly: false,
            ),
            UserScript(
              source: '''
                (function(){
                  try {
                    // Shim for Flutter bridge using prompt
                    if (!window.Flutter) window.Flutter = {};
                    if (typeof window.Flutter.postMessage !== 'function') {
                      window.Flutter.postMessage = function(message) {
                        try { return window.prompt(String(message || ''), ''); } catch (e) { return null; }
                      };
                      console.log('✅ Flutter.postMessage shim installed');
                    }
                    // Provide HostApp/FlutterHost compatible bridge expected by the web app
                    var hostObj = {
                      postMessage: function(payload) {
                        try {
                          var msg = payload;
                          if (typeof payload === 'string') { try { msg = JSON.parse(payload); } catch(_) {} }
                          console.log('🎯 HostApp.postMessage received:', msg);
                          if (msg && (msg.type === 'chooseImage' || msg.type === 'choosePhoto')) {
                            try { window.prompt('file_picker_request', ''); } catch(_) {}
                            return 'ok';
                          }
                        } catch(err) { console.log('⚠️ HostApp.postMessage error', err); }
                        return null;
                      }
                    };
                    if (!window.HostApp) window.HostApp = hostObj;
                    if (!window.FlutterHost) window.FlutterHost = hostObj;
                    console.log('✅ HostApp/FlutterHost shim installed');
                  } catch (e) { console.log('⚠️ postMessage shim error', e); }
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            ),
            UserScript(
              source: '''
                (function(){
                  try {
                    // Intercept file input programmatic/native openings
                    var HTMLInputProto = window.HTMLInputElement && window.HTMLInputElement.prototype;
                    if (HTMLInputProto) {
                      var __origClick = HTMLInputProto.click;
                      if (typeof __origClick === 'function') {
                        HTMLInputProto.click = function() {
                          try {
                            if (this && String(this.type).toLowerCase() === 'file') {
                              window.currentFileInput = this;
                              try {
                                console.log('[FPK-JS] click on file input accept=', this.accept, ' capture=', this.getAttribute && this.getAttribute('capture'), ' multiple=', !!this.multiple);
                              } catch(_) {}
                              try { window.Flutter && window.Flutter.postMessage && window.Flutter.postMessage('file_picker_request'); } catch(_) {}
                              return; // swallow native chooser
                            }
                          } catch(_) {}
                          return __origClick.apply(this, arguments);
                        };
                      }
                      var __origShowPicker = HTMLInputProto.showPicker;
                      if (typeof __origShowPicker === 'function') {
                        HTMLInputProto.showPicker = function() {
                          try {
                            if (this && String(this.type).toLowerCase() === 'file') {
                              window.currentFileInput = this;
                              try {
                                console.log('[FPK-JS] showPicker on file input accept=', this.accept, ' capture=', this.getAttribute && this.getAttribute('capture'), ' multiple=', !!this.multiple);
                              } catch(_) {}
                              try { window.Flutter && window.Flutter.postMessage && window.Flutter.postMessage('file_picker_request'); } catch(_) {}
                              return; // swallow native chooser
                            }
                          } catch(_) {}
                          return __origShowPicker.apply(this, arguments);
                        };
                      }
                    }
                    // Capture label clicks that target file inputs
                    document.addEventListener('click', function(e){
                      try {
                        var label = e.target && e.target.closest ? e.target.closest('label[for], label') : null;
                        if (label) {
                          var forAttr = label.getAttribute('for');
                          var inp = forAttr ? document.getElementById(forAttr) : (label.querySelector && label.querySelector('input[type="file"]'));
                          if (inp && String(inp.type).toLowerCase() === 'file') {
                            e.preventDefault(); e.stopPropagation();
                            window.currentFileInput = inp;
                            try { console.log('[FPK-JS] label click -> input accept=', inp.accept, ' capture=', inp.getAttribute && inp.getAttribute('capture'), ' multiple=', !!inp.multiple); } catch(_) {}
                            try { window.Flutter && window.Flutter.postMessage && window.Flutter.postMessage('file_picker_request'); } catch(_) {}
                          }
                        }
                      } catch(_) {}
                    }, true);
                    // Observe inputs becoming type=file to log attributes
                    try {
                      var mo = new MutationObserver(function(muts){
                        muts.forEach(function(m){
                          if (m.type === 'attributes' && m.attributeName === 'type') {
                            var t = m.target; try {
                              if (t && String(t.type).toLowerCase() === 'file') {
                                console.log('[FPK-JS] mutated to type=file accept=', t.accept, ' capture=', t.getAttribute && t.getAttribute('capture'), ' multiple=', !!t.multiple);
                              }
                            } catch(_) {}
                          }
                        });
                      });
                      mo.observe(document.documentElement||document.body, {subtree:true, attributes:true, attributeFilter:['type']});
                    } catch(_) {}
                  } catch (e) { console.error('⚠️ file input intercept failed', e); }
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            ),
            UserScript(
              source: '''
                (function(){
                  try {
                    if (!window.__dispatchFlutterImage) {
                      window.__dispatchFlutterImage = function(dataUrl, fileName) {
                        try {
                          var detail = { fileName: String(fileName || 'photo.jpg'), fileData: String(dataUrl || '') };
                          var now = Date.now();
                          window.__lastDispatchTime = now;
                          window.__lastFlutterImage = detail;
                          // Single dispatch path only
                          try { window.dispatchEvent(new CustomEvent('flutter_file_selected', { detail: detail, bubbles: true, composed: true })); } catch(e){}
                          return true;
                        } catch (e) {
                          console.error('⚠️ __dispatchFlutterImage error', e);
                          return false;
                        }
                      };
                    }
                  } catch(e) { console.error('⚠️ install __dispatchFlutterImage failed', e); }
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            ),
            UserScript(
              source: r'''
                (function(){
                  if (typeof window.onFlutterFacebookLogin === 'function') return;
                  window.onFlutterFacebookLogin = async function(p){
                    try {
                      const accessToken = (p && p.accessToken) ? String(p.accessToken) : '';
                      if (!accessToken) { console.error('No accessToken provided (fb)'); return false; }
                      const q = new URLSearchParams(location.search);
                      const company = q.get('company_name') || (window.companyconfig && window.companyconfig.getCompanyIdfromUrl && window.companyconfig.getCompanyIdfromUrl()) || '';
                      const legacy = !!q.get('legacy');

                      // Legacy app: use fixed URL like in old_system branch
                      if (legacy || company === 'galeria-kazimierz') {
                        try {
                          const fixedUrl = 'https://login.2take.it/api/web/user/fblogin';
                          console.log('[NATIVE->WEB][FB] using fixed legacy login URL', fixedUrl);
                          const r = await fetch(fixedUrl, {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            credentials: 'include',
                            body: JSON.stringify({ access_token: accessToken, company_url: company, invite_code: '', legacy })
                          });
                          const ct = (r.headers && r.headers.get && r.headers.get('content-type')) || '';
                          if (r.ok && ct.indexOf('application/json') >= 0) {
                            const data = await r.json();
                            const urlToGo = (data && data.url) ? String(data.url) : '';
                            if (urlToGo) {
                              console.log('[NATIVE->WEB][FB] legacy login ok; redirect:', urlToGo);
                              location.replace(urlToGo);
                              return true;
                            }
                            if (data && data.token) {
                              const ACCESS = 'access_token_' + company;
                              const REFRESH = 'id_token_' + company;
                              const EXP = 'expirationtime_' + company;
                              localStorage.setItem(ACCESS, data.token);
                              localStorage.setItem(REFRESH, data.refresh_token || '');
                              const expMs = (Number(data.expiry_second || 0)*1000);
                              const expDate = new Date(Date.now() + expMs - 18000);
                              localStorage.setItem(EXP, expDate.toString());
                              console.log('[NATIVE->WEB][FB] legacy login ok; no url, reloading');
                              location.reload();
                              return true;
                            }
                            console.warn('[NATIVE->WEB][FB] legacy login: no url or token in response');
                          } else {
                            console.warn('[NATIVE->WEB][FB] legacy login http', r.status, 'at', fixedUrl);
                          }
                        } catch(e) {
                          console.error('[NATIVE->WEB][FB] legacy login error', e);
                        }
                        return false;
                      }

                      // New app: use dynamic backend URLs
                      const origin = location.origin.replace(/\/+$/,'');
                      let bases = [];
                      try { if (window.FlutterConfig && window.FlutterConfig.backendUrl) { bases.push(String(window.FlutterConfig.backendUrl).replace(/\/+$/,'/')); } } catch(_) {}
                      try { if (window.GlobalConfig && window.GlobalConfig.baseUrl) { bases.push(String(window.GlobalConfig.baseUrl).replace(/\/+$/,'/')); } } catch(_) {}
                      bases.push(origin + '/api/');
                      bases.push(origin + '/api/web/');
                      bases.push('https://login.2take.it/api/web/');
                      bases = Array.from(new Set(bases));

                      async function tryLogin(base){
                        try {
                          // New backend uses 'user/facebook-auth', old uses 'user/fblogin'
                          const isNewBackend = base.includes('.cloudfunctions.net');
                          const endpoint = isNewBackend ? 'user/facebook-auth' : 'user/fblogin';
                          const u = base + endpoint;
                          console.log('[NATIVE->WEB][FB] trying', u);
                          const r = await fetch(u, {
                            method: 'POST', headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ access_token: accessToken, company_url: company, invite_code: '', legacy })
                          });
                          console.log('[NATIVE->WEB][FB] http', r.status, 'at', u);
                          if (!r.ok) { return null; }
                          // Try to parse JSON even if content-type is missing/wrong
                          try {
                            return await r.json();
                          } catch(parseErr) {
                            console.error('[NATIVE->WEB][FB] JSON parse failed for', u, parseErr);
                            return null;
                          }
                        } catch(e) { console.error('[NATIVE->WEB][FB] fetch error at', base, e); return null; }
                      }

                      let data = null, usedBase = null;
                      for (let i=0; i<bases.length && !data; i++) {
                        const d = await tryLogin(bases[i]);
                        if (d) { data = d; usedBase = bases[i]; }
                      }
                      if (!data) { console.error('[NATIVE->WEB][FB] login failed for all bases', bases); return false; }
                      console.log('[NATIVE->WEB][FB] login ok at', usedBase, 'redirect:', (data && data.url) ? data.url : 'reload');
                      if (data.token) {
                        const ACCESS = 'access_token_' + company;
                        const REFRESH = 'id_token_' + company;
                        const EXP = 'expirationtime_' + company;
                        localStorage.setItem(ACCESS, data.token);
                        localStorage.setItem(REFRESH, data.refresh_token || '');
                        const expMs = (Number(data.expiry_second || 0)*1000);
                        const expDate = new Date(Date.now() + expMs - 18000);
                        localStorage.setItem(EXP, expDate.toString());
                      }
                      if (data.url) { location.replace(data.url); } else { location.reload(); }
                      return true;
                    } catch(e) { console.error('onFlutterFacebookLogin error', e); return false; }
                  };
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              forMainFrameOnly: false,
            ),
            UserScript(
              source: '''
                (function(){
                  try {
                    var host = String(location.host || '').toLowerCase();
                    if (!/\.?(2take\.it|2take\.dev)/.test(host)) return;
                    function forceAttrs(inp){
                      try {
                        if (!inp || String(inp.type).toLowerCase() !== 'file') return;
                        inp.setAttribute('accept','image/*');
                        inp.setAttribute('capture','camera');
                        try { inp.multiple = false; } catch(_) {}
                      } catch(_) {}
                    }
                    Array.prototype.forEach.call(document.querySelectorAll('input[type="file"]'), forceAttrs);
                    var mo = new MutationObserver(function(muts){
                      try {
                        muts.forEach(function(m){
                          if (m.type === 'childList') {
                            (m.addedNodes||[]).forEach(function(n){
                              try {
                                if (n && n.querySelectorAll) {
                                  Array.prototype.forEach.call(n.querySelectorAll('input[type="file"]'), forceAttrs);
                                } else if (n && n.nodeName && String(n.nodeName).toLowerCase() === 'input') {
                                  if (String(n.type).toLowerCase() === 'file') forceAttrs(n);
                                }
                              } catch(_) {}
                            });
                          } else if (m.type === 'attributes') {
                            try { if (m.target && m.attributeName === 'type' && String(m.target.type).toLowerCase() === 'file') forceAttrs(m.target); } catch(_) {}
                          }
                        });
                      } catch(_) {}
                    });
                    mo.observe(document.documentElement || document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['type'] });
                    console.log('✅ Forced capture=camera on 2take.it');
                  } catch(e) { console.error('⚠️ force camera attrs failed', e); }
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              forMainFrameOnly: false,
            ),
            UserScript(
              source: r'''
                (function(){
                  try {
                    window.__flutter2tiLoggedIn = false;
                    window.__flutter2tiPageLoaded = false;
                    window.__flutter2tiReceiptReady = false;
                    function markLogged(){ window.__flutter2tiLoggedIn = true; }
                    function markLoaded(){ window.__flutter2tiPageLoaded = true; }
                    function markReceipt(){ window.__flutter2tiReceiptReady = true; }
                    window.addEventListener('logged2ti', markLogged, true);
                    document.addEventListener('logged2ti', markLogged, true);
                    window.addEventListener('loaded2ti', markLoaded, true);
                    document.addEventListener('loaded2ti', markLoaded, true);
                    var origLog = console.log;
                    console.log = function(){
                      try {
                        for (var i = 0; i < arguments.length; i++) {
                          var a = String(arguments[i] || '');
                          if (a.indexOf('logged2ti') >= 0) markLogged();
                          if (a.indexOf('loaded2ti') >= 0) markLoaded();
                          if (a.indexOf('initializing receipt file upload module') >= 0) markReceipt();
                        }
                      } catch(_) {}
                      return origLog.apply(console, arguments);
                    };
                  } catch(e) {}
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              forMainFrameOnly: false,
            ),
            UserScript(
              source: r'''
                (function(){
                  try {
                    function dataUrlToBlob(dataUrl){
                      try {
                        var parts = String(dataUrl||'').split(',');
                        var meta = parts[0]||''; var b64 = parts[1]||'';
                        var match = /data:(.*?);base64/.exec(meta); var mime = match ? match[1] : 'image/jpeg';
                        var bin = atob(b64); var len = bin.length; var arr = new Uint8Array(len);
                        for (var i=0;i<len;i++){ arr[i] = bin.charCodeAt(i); }
                        return new Blob([arr], {type: mime});
                      } catch(e){ console.error('[FPK-JS] dataUrlToBlob failed', e); return null; }
                    }
                    window.addEventListener('flutter_file_selected', function(ev){
                      try {
                        var d = ev && ev.detail || {};
                        console.log('[FPK-JS] flutter_file_selected received name=', d.fileName, ' size=', (d.fileData||'').length);
                        var inp = window.currentFileInput;
                        if (!inp || String(inp.type).toLowerCase() !== 'file') {
                          try {
                            var savedId = sessionStorage.getItem('flutter_pending_file_input_id');
                            if (savedId) inp = document.getElementById(savedId);
                            if (!inp) {
                              var savedName = sessionStorage.getItem('flutter_pending_file_input_name');
                              if (savedName) inp = document.querySelector('input[type="file"][name="' + savedName + '"]');
                            }
                            if (!inp) inp = document.querySelector('input[type="file"]');
                            if (inp) window.currentFileInput = inp;
                          } catch(_) {}
                        }
                        if (!inp || String(inp.type).toLowerCase() !== 'file') { console.warn('[FPK-JS] no currentFileInput to populate'); return; }
                        var blob = dataUrlToBlob(d.fileData);
                        if (!blob) return;
                        var file;
                        try { file = new File([blob], String(d.fileName||'photo.jpg'), {type: blob.type}); } catch(_){ file = blob; file.name = String(d.fileName||'photo.jpg'); }
                        // Show site's progress bar
                        try {
                          if (window.$ && window.$2TI && $2TI.BILL_PROGRESSBAR_WRAPPER_SELECTOR) {
                            window.$($2TI.BILL_PROGRESSBAR_WRAPPER_SELECTOR).stop(true,true).fadeIn(300);
                            if ($2TI.BILL_PROGRESSBAR_ELEMENT_SELECTOR) { window.$($2TI.BILL_PROGRESSBAR_ELEMENT_SELECTOR).css('width','10%'); }
                            try { window.dispatchEvent(new CustomEvent('startspinner')); } catch(_) {}
                            setTimeout(function(){
                              try {
                                window.dispatchEvent(new CustomEvent('stopspinner'));
                                if ($2TI.BILL_PROGRESSBAR_WRAPPER_SELECTOR) {
                                  window.$($2TI.BILL_PROGRESSBAR_WRAPPER_SELECTOR).stop(true,true).fadeOut(300);
                                }
                              } catch(_) {}
                            }, 90000);
                          }
                        } catch(_) {}
                        // Use DataTransfer to set files
                        try {
                          var dt = new DataTransfer();
                          dt.items.add(file);
                          inp.files = dt.files;
                          // Fire events to notify frameworks
                          var ev1 = new Event('input', {bubbles:true, composed:true});
                          var ev2 = new Event('change', {bubbles:true, composed:true});
                          inp.dispatchEvent(ev1);
                          inp.dispatchEvent(ev2);
                          console.log('[FPK-JS] populated input.files and dispatched change');
                        } catch(e){
                          console.error('[FPK-JS] populate input.files failed', e);
                        }
                      } catch(e){ console.error('[FPK-JS] flutter_file_selected handler error', e); }
                    }, true);
                  } catch(e) { console.error('[FPK-JS] install populate handler failed', e); }
                })();
              ''',
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              forMainFrameOnly: false,
            )
          ]),
          onWebViewCreated: (controller) async {
            _inAppController = controller;
            // Get serverClientId from static mapping
            // Priority:
            // 1. googleAuthCompanyId from config (if explicitly set)
            // 2. Flavor-based logic (for galeriaKazimierz - always use old project)
            // 3. companyId from config (for other flavors)
            String serverClientId;
            String companyId = 'galeria-kazimierz'; // default fallback
            String? googleAuthCompanyId; // Company ID specifically for Google Auth
            
            if (widget.config is SecureAppConfig) {
              final secureConfig = widget.config as SecureAppConfig;
              companyId = secureConfig.companyId; // Used for UI/WebView
              googleAuthCompanyId = secureConfig.googleAuthCompanyId; // Used for Google Auth (optional)
            }
            
            // Determine which companyId to use for Google Auth
            // Priority:
            // 1. googleAuthCompanyId from config (if explicitly set) - highest priority, always respected
            // 2. Flavor-based fallback logic (if googleAuthCompanyId not set)
            String authCompanyId;
            if (googleAuthCompanyId != null) {
              // Use explicit googleAuthCompanyId from config (always respected for all flavors)
              authCompanyId = googleAuthCompanyId!;
            } else if (FlavorConfig.isInitialized && 
                (FlavorConfig.instance.flavor == FlavorType.galeriaKazimierz || 
                 FlavorConfig.instance.flavor == FlavorType.galeriaKazimierzNew)) {
              // For galeriaKazimierz and galeriaKazimierzNew flavors, default to old project's companyId
              // This ensures Android OAuth Client (SHA-1) matches the configured google-services.json
              authCompanyId = 'galeria-kazimierz';
            } else {
              // For other flavors without explicit googleAuthCompanyId, use companyId from config
              authCompanyId = companyId;
            }
            
            // Look up client ID from static mapping
            serverClientId = _googleAuthClientIds[authCompanyId] ?? 
                            _googleAuthClientIds['galeria-kazimierz']!; // fallback to default
            
            final flavorInfo = FlavorConfig.isInitialized ? FlavorConfig.instance.flavor.toString() : 'unknown';
            debugPrint('[WEBVIEW] Flavor: $flavorInfo, Company (UI): $companyId, Company (Google Auth): $authCompanyId, Google Auth client: ${serverClientId.substring(0, 20)}...');
            
            _googleSignIn = GoogleSignIn(
              serverClientId: serverClientId,
              scopes: ['email', 'profile'],
            );
            debugPrint('[WEBVIEW] GoogleSignIn initialized');
            // Attempt an early guest token register using the company from URL
            try {
              final currentUrl = await _inAppController?.getUrl();
              final urlStr = currentUrl?.toString() ?? '';
              final uri = Uri.tryParse(urlStr);
              final company = uri?.queryParameters['company_name'];
              if ((company != null) && company.isNotEmpty) {
                debugPrint('[WEBVIEW] early guest register company=' + company);
                await FirebaseMessagingService.register2TakeToken(company: company, uid: null);
              } else {
                debugPrint('[WEBVIEW] early guest register skipped: no company in URL');
              }
            } catch (e) { debugPrint('[WEBVIEW] early guest register error: ' + e.toString()); }

            _inAppController?.addJavaScriptHandler(
              handlerName: 'facebookLogin',
              callback: (args) async {
                try {
                  try {
                    await FacebookAuth.instance.logOut();
                  } catch (e) {
                    debugPrint('FB pre-logout ignored: ' + e.toString());
                  }
                  final res = await FacebookAuth.instance.login(permissions: ['email','public_profile']);
                  if (res.status != LoginStatus.success || res.accessToken == null) {
                    debugPrint('FB login failed: status=${res.status} message=${res.message}');
                    await _inAppController?.evaluateJavascript(source: """
                      try {
                        window.dispatchEvent(new CustomEvent('flutter_facebook_error', { detail: { status: '${res.status}', message: ${jsonEncode(res.message ?? '')} } }));
                      } catch(e) { console.error('FB error dispatch failed', e); }
                    """);
                    return { 'error': res.status.toString(), 'message': res.message };
                  }
                  final atJson = res.accessToken!.toJson();
                  final token = (atJson['token'] ?? atJson['tokenString'] ?? '').toString();
                  final userId = (atJson['userId'] ?? atJson['userID'] ?? '').toString();
                  int? expiresIn;
                  try {
                    final ex = atJson['expires'];
                    if (ex is String) {
                      final dt = DateTime.tryParse(ex);
                      if (dt != null) { expiresIn = ((dt.millisecondsSinceEpoch - DateTime.now().millisecondsSinceEpoch) ~/ 1000); }
                    } else if (ex is int) {
                      expiresIn = ((ex - DateTime.now().millisecondsSinceEpoch) ~/ 1000);
                    }
                  } catch (_) {}
                  await _inAppController?.evaluateJavascript(source: """
                    try {
                      window.dispatchEvent(new CustomEvent('flutter_facebook_tokens', { detail: { accessToken: '${token.replaceAll("'", "\\'")}', userId: '${userId.replaceAll("'", "\\'")}', expiresIn: ${expiresIn ?? 'null'} } }));
                      if (window.onFlutterFacebookLogin) { try { window.onFlutterFacebookLogin({ accessToken: '${token.replaceAll("'", "\\'")}', userId: '${userId.replaceAll("'", "\\'")}', expiresIn: ${expiresIn ?? 'null'} }); } catch(e){} }
                    } catch(e) { console.error('FB tokens dispatch error', e); }
                  """);
                  return {'accessToken': token, 'userId': userId, 'expiresIn': expiresIn};
                } catch (e) {
                  debugPrint('FB login exception: ' + e.toString());
                  // Fallback: try platform channel if plugin missing
                  try {
                    final result = await _fbFallbackChannel.invokeMethod<Map>('login');
                    if (result != null && (result['accessToken'] ?? '').toString().isNotEmpty) {
                      final token = (result['accessToken'] ?? '').toString();
                      final userId = (result['userId'] ?? '').toString();
                      final expiresIn = result['expiresIn'];
                      await _inAppController?.evaluateJavascript(source: """
                        try {
                          window.dispatchEvent(new CustomEvent('flutter_facebook_tokens', { detail: { accessToken: '${token.replaceAll("'", "\\'")}', userId: '${userId.replaceAll("'", "\\'")}', expiresIn: ${expiresIn ?? 'null'} } }));
                        } catch(e) {}
                      """);
                      return {'accessToken': token, 'userId': userId, 'expiresIn': expiresIn};
                    } else {
                      final errMsg = result != null ? (result['error']?.toString() ?? 'unknown') : 'no_result';
                      await _inAppController?.evaluateJavascript(source: """
                        try {
                          window.dispatchEvent(new CustomEvent('flutter_facebook_error', { detail: { status: 'fallback_error', message: ${jsonEncode(errMsg)} } }));
                        } catch(e) {}
                      """);
                      return { 'error': 'fallback_error', 'message': errMsg };
                    }
                  } catch (pe) {
                    debugPrint('FB fallback channel error: ' + pe.toString());
                    await _inAppController?.evaluateJavascript(source: """
                      try {
                        window.dispatchEvent(new CustomEvent('flutter_facebook_error', { detail: { status: 'fallback_exception', message: ${jsonEncode(pe.toString())} } }));
                      } catch(e) {}
                    """);
                    return { 'error': 'fallback_exception', 'message': pe.toString() };
                  }
                }
              },
            );

            _inAppController?.addJavaScriptHandler(
              handlerName: 'facebookLogout',
              callback: (args) async { try { await FacebookAuth.instance.logOut(); } catch(_){} return {'ok': true}; },
            );

            _inAppController?.addJavaScriptHandler(
              handlerName: 'googleSignIn',
              callback: (args) async {
                Future<Map<String, dynamic>> dispatchToWeb(String idToken, String accessToken, String serverAuthCode, String email, String name, String id, String imageUrl, {bool fallback = false}) async {
                  debugPrint('GoogleSignIn: idToken len=${idToken.length}, accessToken len=${accessToken.length}, serverAuthCode len=${serverAuthCode.length}, email=$email, name=$name, id=$id, fallback=$fallback');
                  await _inAppController?.evaluateJavascript(source: """
                    try {
                      window.dispatchEvent(new CustomEvent('flutter_google_tokens', {
                        detail: { idToken: '${idToken.replaceAll("'", "\\'")}', accessToken: '${accessToken.replaceAll("'", "\\'")}', serverAuthCode: '${serverAuthCode.replaceAll("'", "\\'")}', email: '${email.replaceAll("'", "\\'")}', name: '${name.replaceAll("'", "\\'")}', id: '${id.replaceAll("'", "\\'")}', imageUrl: '${imageUrl.replaceAll("'", "\\'")}', fallback: ${fallback ? 'true' : 'false'} }
                      }));
                      if (window.onFlutterGoogleSignIn) {
                        try { window.onFlutterGoogleSignIn({ idToken: '${idToken.replaceAll("'", "\\'")}', accessToken: '${accessToken.replaceAll("'", "\\'")}', serverAuthCode: '${serverAuthCode.replaceAll("'", "\\'")}', email: '${email.replaceAll("'", "\\'")}', name: '${name.replaceAll("'", "\\'")}', id: '${id.replaceAll("'", "\\'")}', imageUrl: '${imageUrl.replaceAll("'", "\\'")}', fallback: ${fallback ? 'true' : 'false'} }); } catch(e) { console.error('onFlutterGoogleSignIn error', e); }
                      }
                    } catch (e) { console.error('Flutter -> Web tokens dispatch error', e); }
                  """);
                  return {
                    'idToken': idToken,
                    'accessToken': accessToken,
                    'serverAuthCode': serverAuthCode,
                    'email': email,
                    'name': name,
                    'id': id,
                    'imageUrl': imageUrl,
                    'fallback': fallback,
                  };
                }

                try {
                  // Primary path: with serverClientId
                  await _googleSignIn!.signOut();
                  final account = await _googleSignIn!.signIn();
                  if (account == null) {
                    debugPrint('GoogleSignIn: cancelled by user');
                    return {'error': 'cancelled'};
                  }
                  var auth = await account.authentication;
                  if ((auth.idToken == null || auth.idToken!.isEmpty) && (auth.accessToken == null || auth.accessToken!.isEmpty)) {
                    await Future.delayed(const Duration(milliseconds: 300));
                    auth = await account.authentication;
                  }
                  return await dispatchToWeb(
                    auth.idToken ?? '', 
                    auth.accessToken ?? '', 
                    account.serverAuthCode ?? '', 
                    account.email, 
                    account.displayName ?? '', 
                    account.id, 
                    account.photoUrl ?? ''
                  );
                } catch (e) {
                  final es = e.toString();
                  debugPrint('GoogleSignIn primary error: $es');
                  // ApiException: 10 => misconfigured Android OAuth client (SHA‑1/package). Try fallback without serverClientId to unblock testing.
                  if (es.contains('ApiException: 10')) {
                    try {
                      final fallbackGsi = GoogleSignIn(scopes: ['email', 'profile']);
                      await fallbackGsi.signOut();
                      final account = await fallbackGsi.signIn();
                      if (account == null) return {'error': 'cancelled'};
                      var auth = await account.authentication;
                      if ((auth.idToken == null || auth.idToken!.isEmpty) && (auth.accessToken == null || auth.accessToken!.isEmpty)) {
                        await Future.delayed(const Duration(milliseconds: 300));
                        auth = await account.authentication;
                      }
                      return await dispatchToWeb(
                        auth.idToken ?? '', 
                        auth.accessToken ?? '', 
                        account.serverAuthCode ?? '', 
                        account.email, 
                        account.displayName ?? '', 
                        account.id, 
                        account.photoUrl ?? '',
                        fallback: true
                      );
                    } catch (e2, st2) {
                      debugPrint('GoogleSignIn fallback error: $e2\n$st2');
                      return {'error': e2.toString(), 'code': 10};
                    }
                  }
                  return {'error': es};
                }
              },
            );
            _inAppController?.addJavaScriptHandler(
              handlerName: 'googleSignOut',
              callback: (args) async {
                try { await _googleSignIn?.signOut(); return {'ok': true}; }
                catch (e) { return {'error': e.toString()}; }
              },
            );

            // Push registration from web app
            _inAppController?.addJavaScriptHandler(
              handlerName: 'registerPush',
              callback: (args) async {
                try {
                  final uid = (args.isNotEmpty ? args[0] : '')?.toString() ?? '';
                  String? company = args.length > 1 ? args[1]?.toString() : null;
                  if (company == null || company.isEmpty) {
                    try {
                      final currentUrl = await _inAppController?.getUrl();
                      final urlStr = currentUrl?.toString() ?? '';
                      final uri = Uri.tryParse(urlStr);
                      final fromUrl = uri?.queryParameters['company_name'];
                      if (fromUrl != null && fromUrl.isNotEmpty) company = fromUrl;
                    } catch (_) {}
                  }
                  debugPrint('[WEBVIEW] registerPush: uid=' + uid + ' company=' + (company ?? '-'));
                  debugPrint('[WEBVIEW] fcmToken(before)=' + (FirebaseMessagingService.fcmToken ?? 'null'));
                  if ((company ?? '').isEmpty) return {'error': 'no_company'};
                  await FirebaseMessagingService.register2TakeToken(company: company!, uid: uid.isEmpty ? null : uid);
                  debugPrint('[WEBVIEW] registerPush done uid=' + uid + ' fcmToken(after)=' + (FirebaseMessagingService.fcmToken ?? 'null'));
                  return {'ok': true, 'token': FirebaseMessagingService.fcmToken};
                } catch (e) {
                  debugPrint('[WEBVIEW] registerPush error: ' + e.toString());
                  return {'error': e.toString()};
                }
              },
            );

            _inAppController?.addJavaScriptHandler(
              handlerName: 'logoutPush',
              callback: (args) async {
                try {
                  final uid = (args.isNotEmpty ? args[0] : '')?.toString() ?? '';
                  debugPrint('[WEBVIEW] logoutPush uid=' + uid);
                  if (uid.isEmpty) return {'error': 'no_user'};
                  await FirebaseMessagingService.unregisterToken(userId: uid);
                  debugPrint('[WEBVIEW] logoutPush done uid=' + uid);
                  return {'ok': true};
                } catch (e) { return {'error': e.toString()}; }
              },
            );

            // Generic setUser handler to auto-upsert token for ANY auth type
            _inAppController?.addJavaScriptHandler(
              handlerName: 'setUser',
              callback: (args) async {
                try {
                  final uid = (args.isNotEmpty ? args[0] : '')?.toString() ?? '';
                  final company = args.length > 1 ? args[1]?.toString() : null;
                  if (uid.isEmpty) return {'error': 'no_user'};
                  debugPrint('[WEBVIEW] setUser uid=' + uid + ' company=' + (company ?? '-'));
                  FirebaseMessagingService.setLoggedInUser(uid, company: company);
                  await FirebaseMessagingService.registerToken(userId: uid, company: company);
                  debugPrint('[WEBVIEW] setUser done uid=' + uid + ' fcmToken=' + (FirebaseMessagingService.fcmToken ?? 'null'));
                  return {'ok': true, 'token': FirebaseMessagingService.fcmToken};
                } catch (e) {
                  debugPrint('[WEBVIEW] setUser error: ' + e.toString());
                  return {'error': e.toString()};
                }
              },
            );

            // DEBUG ONLY: allow forcing a token from web on Simulator to validate backend
            _inAppController?.addJavaScriptHandler(
              handlerName: 'debugRegisterPushWithToken',
              callback: (args) async {
                try {
                  final uid = (args.isNotEmpty ? args[0] : '')?.toString() ?? '';
                  final String token = ((args.length > 1 ? args[1] : '')?.toString() ?? '');
                  final company = args.length > 2 ? args[2]?.toString() : null;
                  if (uid.isEmpty || token.isEmpty) return {'error': 'need_user_and_token'};
                  debugPrint('[WEBVIEW] debugRegisterPushWithToken uid=' + uid + ' tokenLen=' + token.length.toString());
                  await FirebaseMessagingService.registerTokenWith(userId: uid, token: token, company: company);
                  return {'ok': true};
                } catch (e) { return {'error': e.toString()}; }
              },
            );
          },
          onConsoleMessage: (controller, msg) {
            try {
              debugPrint('[WEBVIEW CONSOLE] ' + msg.message);
              final text = msg.message;
              if (text.contains('initializing receipt file upload module')) {
                controller.evaluateJavascript(
                  source: 'try { window.__flutter2tiReceiptReady = true; } catch(e) {}',
                );
              } else if (text.contains('logged2ti')) {
                controller.evaluateJavascript(
                  source: 'try { window.__flutter2tiLoggedIn = true; } catch(e) {}',
                );
              } else if (text.contains('loaded2ti')) {
                controller.evaluateJavascript(
                  source: 'try { window.__flutter2tiPageLoaded = true; } catch(e) {}',
                );
              }
            } catch (_) {}
          },
          onLoadStart: (controller, url) async {
            try {
              await controller.evaluateJavascript(
                source: '''try {
                  window.__flutter2tiLoggedIn = false;
                  window.__flutter2tiPageLoaded = false;
                  window.__flutter2tiReceiptReady = false;
                } catch(e) {}''',
              );
            } catch (_) {}
          },
          onLoadStop: (controller, url) async {
            final urlStr = url?.toString() ?? '';
            if (urlStr.isNotEmpty) _lastKnownUrl = urlStr;
            await _injectPermissionOverrides();
            try { await controller.evaluateJavascript(source: _app2tiBridgeJs); } catch (_) {}
            await _persistWebViewUrl(urlStr);
            await _maybeDispatchDeferredImage();
          },
          onRenderProcessGone: (controller, detail) {
            debugPrint('[WEBVIEW] render process gone didCrash=${detail.didCrash} duringPick=$_isPicking');
            if (_isPicking) {
              _rendererCrashedDuringPick = true;
              debugPrint('[WEBVIEW] deferring reload until camera returns');
              return;
            }
            if (_inPostDispatchGrace) {
              debugPrint('[WEBVIEW] skipping crash reload during post-dispatch grace');
              return;
            }
            _reloadWebViewAfterRendererCrash(controller);
          },
          onLoadError: (controller, url, code, message) {},
          shouldOverrideUrlLoading: (controller, navAction) async {
            final url = navAction.request.url?.toString() ?? '';
            final externalPolicy = await _navigationPolicyForExternalSchemes(url);
            if (externalPolicy == NavigationActionPolicy.CANCEL) {
              return NavigationActionPolicy.CANCEL;
            }
            if (url.contains('accounts.google.com') || url.contains('oauth2') || url.contains('gsi/client')) {
              return NavigationActionPolicy.ALLOW;
            }
            return NavigationActionPolicy.ALLOW;
          },
          onCreateWindow: (controller, createWindowAction) async {
            final uri = createWindowAction.request.url;
            final winId = createWindowAction.windowId;
            if (winId != null) {
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) {
                  return Dialog(
                    insetPadding: const EdgeInsets.all(0),
                    child: SafeArea(
                      child: InAppWebView(
                        windowId: winId,
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          javaScriptCanOpenWindowsAutomatically: true,
                          supportMultipleWindows: true,
                          thirdPartyCookiesEnabled: true,
                          domStorageEnabled: true,
                          databaseEnabled: true,
                          useHybridComposition: true,
                        ),
                        onCloseWindow: (popupController) {
                          Navigator.of(ctx).pop();
                        },
                        onConsoleMessage: (c, m) {},
                        onLoadStop: (c, u) {},
                      ),
                    ),
                  );
                },
              );
              return true;
            }
            if (uri != null) {
              await controller.loadUrl(urlRequest: URLRequest(url: uri));
              return true;
            }
            return false;
          },
          onPermissionRequest: (controller, request) async {
            return PermissionResponse(resources: request.resources, action: PermissionResponseAction.GRANT);
          },
          androidOnPermissionRequest: (controller, origin, resources) async {
            return PermissionRequestResponse(resources: resources, action: PermissionRequestResponseAction.GRANT);
          },
          onJsPrompt: (controller, jsPromptRequest) async {
            // Bridge channel shim: window.Flutter.postMessage
            if (jsPromptRequest.message == 'file_picker_request') {
              // Defer picker to avoid evaluating JS while window.prompt is blocking the JS thread
              Future.microtask(() async {
                try {
                  if (_isPicking) { return; }
                  _isPicking = true;
                  try { await _inAppController?.evaluateJavascript(source: "try { window.__lastFlutterImage = undefined; window.__pendingFlutterFile = undefined; window.__pendingFlutterDataUrl = undefined; } catch(e){}"); } catch (_) {}
                  await _handleFilePicker();
                } catch (e) {} finally {
                  _isPicking = false;
                }
              });
              return JsPromptResponse(handledByClient: true, action: JsPromptResponseAction.CONFIRM, value: 'ok');
            }
            if (jsPromptRequest.message == 'window_open' || jsPromptRequest.message == 'apple_oauth') {
              final url = jsPromptRequest.defaultValue ?? '';
              if (url.isNotEmpty) {
                if (jsPromptRequest.message == 'apple_oauth') {
                  // Keep Apple flow inside the same WebView so we return to the app context
                  debugPrint('[APPLE][open-in-webview] $url');
                  try { await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url))); } catch (_) {}
                } else if (url.contains('accounts.google.com') || url.contains('oauth2') || url.contains('gsi/client')) {
                  try { await ChromeSafariBrowser().open(url: WebUri(url)); } catch (_) {}
                } else {
                  try { await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url))); } catch (_) {}
                }
              }
              return JsPromptResponse(handledByClient: true, action: JsPromptResponseAction.CONFIRM, value: 'ok');
            }
            if (jsPromptRequest.message == 'google_native_signin') {
              // Do not block the JS prompt; run sign-in asynchronously
              Future.microtask(() async {
                try {
                  await _googleSignIn!.signOut();
                  final account = await _googleSignIn!.signIn();
                  if (account != null) {
                    var auth = await account.authentication;
                    if ((auth.idToken == null || auth.idToken!.isEmpty) && (auth.accessToken == null || auth.accessToken!.isEmpty)) {
                      await Future.delayed(const Duration(milliseconds: 300));
                      auth = await account.authentication;
                    }
                    // Prefer calling the page's own API directly if available
                    String jsTpl = r"""
                      (async function(){
                        try {
                          console.log('[NATIVE->WEB] Attempting onFlutterGoogleSignIn hook');
                          var hook = (typeof window.onFlutterGoogleSignIn === 'function') ? window.onFlutterGoogleSignIn : null;
                          if (hook) {
                            var payload = { idToken: '%IDTOKEN%', companyName: (window.__companyName||'') };
                            console.log('[NATIVE->WEB] Calling onFlutterGoogleSignIn with payload', payload);
                            var res = await hook(payload);
                            console.log('[NATIVE->WEB] onFlutterGoogleSignIn result', res);
                          } else {
                            console.warn('[NATIVE->WEB] onFlutterGoogleSignIn not found, dispatching event');
                            try { window.dispatchEvent(new CustomEvent('flutter_google_tokens', { detail: { idToken: '%IDTOKEN%', accessToken: '%ACCTOKEN%', serverAuthCode: '%CODE%', email: '%EMAIL%', fallback: false } })); } catch(_){ console.error('event dispatch failed', _); }
                            try { if (window.APP2TI && typeof window.APP2TI.onFlutterToken === 'function') { await window.APP2TI.onFlutterToken('%IDTOKEN%'); } } catch(_){ console.error('APP2TI.onFlutterToken call failed', _); }
                            // Direct login fallback: call fixed endpoint and redirect
                            try {
                              var params = new URLSearchParams(location.search);
                              var company = params.get('company_name') || '';
                              var legacy = !!params.get('legacy');
                              var url = 'https://login.2take.it/api/web/user/google-login';
                              console.log('[NATIVE->WEB] direct login POST', url, 'company=', company, 'legacy=', legacy);
                              var resp = await fetch(url, {
                                method: 'POST', headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify({ access_token: '%IDTOKEN%', company_url: company, invite_code: '', legacy: legacy })
                              });
                              var ct = (resp.headers && resp.headers.get && resp.headers.get('content-type')) || '';
                              if (resp.ok && ct.indexOf('application/json') >= 0) {
                                var data = await resp.json();
                                console.log('[NATIVE->WEB] direct login ok; redirect:', (data && data.url) ? data.url : 'reload');
                                if (data && data.url) { location.replace(data.url); } else { location.reload(); }
                              } else {
                                console.warn('[NATIVE->WEB] direct login http', resp && resp.status);
                              }
                            } catch(ex) { console.error('[NATIVE->WEB] direct login error', ex); }
                          }
                        } catch(e) { console.error('dispatch native google token failed', e); }
                      })();
                    """;
                    jsTpl = jsTpl
                      .replaceAll('%IDTOKEN%', (auth.idToken ?? '').replaceAll("'", "\\'"))
                      .replaceAll('%ACCTOKEN%', (auth.accessToken ?? '').replaceAll("'", "\\'"))
                      .replaceAll('%CODE%', (account.serverAuthCode ?? '').replaceAll("'", "\\'"))
                      .replaceAll('%EMAIL%', account.email.replaceAll("'", "\\'"));
                    await _inAppController?.evaluateJavascript(source: jsTpl);
                    await _inAppController?.evaluateJavascript(source: "try { window.APP2TI && window.APP2TI.giveApiToken('${(auth.idToken ?? '').replaceAll("'", "\\'")}', '${account.email.replaceAll("'", "\\'")}'); } catch(e){ console.error('APP2TI.giveApiToken failed', e); }");
                  }
                } catch (e) {
                  try { await _inAppController?.evaluateJavascript(source: "try{ console.error('native google sign-in error', '${e.toString().replaceAll("'", "\\'")}'); }catch(_){}"); } catch(_) {}
                }
              });
              return JsPromptResponse(handledByClient: true, action: JsPromptResponseAction.CONFIRM, value: 'ok');
            }
            if (jsPromptRequest.message == 'apple_native_signin') {
              Future.microtask(() async {
                try {
                  final raw = _generateNonce();
                  final hashed = sha256.convert(utf8.encode(raw)).toString();
                  final cred = await SignInWithApple.getAppleIDCredential(
                    scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
                    nonce: hashed,
                  );
                  final idToken = cred.identityToken ?? '';
                  final authCode = cred.authorizationCode ?? '';
                  debugPrint('[APPLE][native] got tokens idTokenLen=' + (idToken.length.toString()) + ' codeLen=' + (authCode.length.toString()));
                  if (idToken.isNotEmpty || authCode.isNotEmpty) {
                    final js = """
                      (function(){
                        try {
                          console.log('[NATIVE->WEB][APPLE] tokens ready, posting to redirect endpoint');
                          // Prefer site hook if present
                          if (typeof window.onFlutterAppleSignIn === 'function') {
                            try { window.onFlutterAppleSignIn({ idToken: '${idToken.replaceAll("'","\\'")}', code: '${authCode.replaceAll("'","\\'")}' }); return; } catch(e) {}
                          }
                          var q = new URLSearchParams(location.search);
                          var company = q.get('company_name') || '';
                          var action = 'https://login.2take.it/api/web/user/apple-login?cn=' + encodeURIComponent(company || '');
                          var f = document.createElement('form');
                          f.method = 'POST';
                          f.action = action;
                          f.target = '_self';
                          function add(name, val){ var i=document.createElement('input'); i.type='hidden'; i.name=name; i.value=val; f.appendChild(i); }
                          if ('${idToken.replaceAll("'","\\'")}'.length) add('id_token', '${idToken.replaceAll("'","\\'")}'.toString());
                          if ('${authCode.replaceAll("'","\\'")}'.length) add('code', '${authCode.replaceAll("'","\\'")}'.toString());
                          // Apple may also send state in web flow; not available here, so omit
                          document.body.appendChild(f);
                          try { console.log('[NATIVE->WEB][APPLE] submitting form to', action, ' idTokenLen=', '${idToken.length}', ' codeLen=', '${authCode.length}'); } catch(_){ }
                          f.submit();
                        } catch(e) { console.error('[NATIVE->WEB][APPLE] form post failed', e); }
                      })();
                    """;
                    await _inAppController?.evaluateJavascript(source: js);
                  }
                } catch (e) {
                  try { await _inAppController?.evaluateJavascript(source: "try{ console.error('native apple sign-in error', '${(e.toString()).replaceAll("'", "\\'")}'); }catch(_){}"); } catch(_) {}
                }
              });
              return JsPromptResponse(handledByClient: true, action: JsPromptResponseAction.CONFIRM, value: 'ok');
            }
            if (jsPromptRequest.message == 'facebook_native_signin') {
              // Do not block the JS prompt; run sign-in asynchronously
              Future.microtask(() async {
                try {
                  await FacebookAuth.instance.logOut();
                  final res = await FacebookAuth.instance.login(permissions: ['email','public_profile']);
                  if (res.status == LoginStatus.success && res.accessToken != null) {
                    final atJson = res.accessToken!.toJson();
                    final token = (atJson['token'] ?? atJson['tokenString'] ?? '').toString();
                    final userId = (atJson['userId'] ?? atJson['userID'] ?? '').toString();
                    int? expiresIn;
                    try {
                      final ex = atJson['expires'];
                      if (ex is String) {
                        final dt = DateTime.tryParse(ex);
                        if (dt != null) { expiresIn = ((dt.millisecondsSinceEpoch - DateTime.now().millisecondsSinceEpoch) ~/ 1000); }
                      } else if (ex is int) {
                        expiresIn = ((ex - DateTime.now().millisecondsSinceEpoch) ~/ 1000);
                      }
                    } catch (_) {}
                    await _inAppController?.evaluateJavascript(source: """
                      try {
                        window.dispatchEvent(new CustomEvent('flutter_facebook_tokens', { detail: { accessToken: '${token.replaceAll("'", "\\'")}', userId: '${userId.replaceAll("'", "\\'")}', expiresIn: ${expiresIn ?? 'null'} } }));
                        if (window.onFlutterFacebookSignIn) { try { window.onFlutterFacebookSignIn({ accessToken: '${token.replaceAll("'", "\\'")}', userId: '${userId.replaceAll("'", "\\'")}', expiresIn: ${expiresIn ?? 'null'} }); } catch(e){} }
                      } catch(e) { console.error('FB tokens dispatch error', e); }
                    """);
                  } else {
                    debugPrint('FB native sign-in failed: status=${res.status} message=${res.message}');
                    await _inAppController?.evaluateJavascript(source: """
                      try {
                        window.dispatchEvent(new CustomEvent('flutter_facebook_error', { detail: { status: '${res.status}', message: ${jsonEncode(res.message ?? '')} } }));
                      } catch(e) { console.error('FB error dispatch failed', e); }
                    """);
                  }
                } catch (e) {
                  debugPrint('FB native sign-in exception: ' + e.toString());
                  try { await _inAppController?.evaluateJavascript(source: "try{ console.error('native facebook sign-in error', '${e.toString().replaceAll("'", "\\'")}'); }catch(_){}"); } catch(_) {}
                }
              });
              return JsPromptResponse(handledByClient: true, action: JsPromptResponseAction.CONFIRM, value: 'ok');
            }
            return JsPromptResponse(handledByClient: false);
          },
        ),
                    ), // SafeArea
                  ), // Expanded
                ], // children of Column
              ), // Column
              // Invisible tap area for secret gesture (top-right corner)
              // GestureDetector on Scaffold body handles taps, this is just a visual marker
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 100,
                  height: 100,
                  color: Colors.transparent,
                ),
              ),
            ], // children of Stack
          ), // Stack
        ), // GestureDetector
      // floatingActionButton: kDebugMode ? FloatingActionButton.small(
      //   onPressed: _setCustomUrlDialog,
      //   child: const Icon(Icons.link),
      //   tooltip: 'Set HTTPS URL',
      // ) : null,
    );
  }
} 