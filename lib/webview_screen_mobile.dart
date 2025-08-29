import 'dart:convert';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'firebase_messaging_service.dart';
import 'package:flutter/foundation.dart'; // for kDebugMode
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    // _loadCustomUrl();
    final fcmToken = FirebaseMessagingService.fcmToken;
    
    // Probe: confirm FB plugin is bound on this engine
    FacebookAuth.instance.accessToken
        .then((_) => debugPrint('FB plugin OK'))
        .catchError((e) => debugPrint('FB plugin missing: ' + e.toString()));
    
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
    print('Injecting ULTIMATE permission overrides with token: $fcmToken');
    
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
          
          return 'Ultimate Firebase bridge injected successfully';
        })();
      ''');
      
      // Mark on Dart side for diagnostics only; JS side prevents duplicates
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



  Future<void> _handleFilePicker() async {
    try {
      debugPrint('FPK: _handleFilePicker() start');
      final ImagePicker picker = ImagePicker();
      
      // Show options: Camera or Gallery
      final result = await showDialog<String>(
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
        final XFile? image;
        if (result == 'camera') {
          debugPrint('FPK: launching camera');
          image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600, maxHeight: 1600);
        } else {
          debugPrint('FPK: opening gallery');
          image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1600, maxHeight: 1600);
        }
        debugPrint('FPK: picker returned => ' + (image?.name ?? 'null'));

        if (image != null) {
          // Convert image to base64 and send back to web app
          final bytes = await image.readAsBytes();
          final base64Payload = base64Encode(bytes);
          debugPrint('FPK: bytes=' + bytes.length.toString() + ' base64Len=' + base64Payload.length.toString());

          // Extra diagnostics: current page URL and bridge state
          try {
            final currentUrl = await _inAppController?.getUrl();
            debugPrint('FPK: page url=' + (currentUrl?.toString() ?? 'null'));
          } catch (e) { debugPrint('FPK: getUrl error: ' + e.toString()); }
          try {
            final probe = await _inAppController?.evaluateJavascript(source: '''(function(){try{return JSON.stringify({
              href: location.href,
              vis: document.visibilityState,
              ready: document.readyState,
              hasPoller: !!window.__flutterImagePollerInstalled,
              hasDispatch: (typeof __dispatchFlutterImage),
              handlers: (window.__flutterFileSelectedHandlers||0),
              hasOnResult: (typeof window.onFlutterScanResult),
              hasHostApp: (typeof window.HostApp),
              hasFlutterPostMessage: !!(window.Flutter && window.Flutter.postMessage)
            });}catch(e){return 'ERR:'+e;}})()''');
            debugPrint('FPK: page probe => ' + (probe?.toString() ?? 'null'));
          } catch (e) { debugPrint('FPK: page probe error: ' + e.toString()); }

          const mime = 'image/jpeg';
          final dataUrl = 'data:$mime;base64,' + base64Payload;
          debugPrint('FPK: dataUrl length=' + dataUrl.length.toString());
          _pendingImageDataUrl = null; // do not cache for poller; avoid reuse

          // Longer wait to ensure WebView fully resumes after picker
          await Future.delayed(const Duration(milliseconds: 1600));

          // Log controller state and attempt resilient dispatch via JS function with retries
          debugPrint('FPK: controller is ' + (_inAppController == null ? 'null' : 'ready'));
          // Single dispatch only; no retries
          try {
            final js = "try { console.log('🟢 CALL __dispatchFlutterImage'); (typeof __dispatchFlutterImage==='function') && __dispatchFlutterImage(${jsonEncode(dataUrl)}, ${jsonEncode(image.name)}); 'ok'; } catch(e) { console.log('⚠️ __dispatchFlutterImage call error', e); 'err'; }";
            final res = await _inAppController?.evaluateJavascript(source: js);
            debugPrint('FPK: __dispatchFlutterImage res=' + (res?.toString() ?? 'null'));
            try { await _inAppController?.evaluateJavascript(source: "try { window.__lastFlutterImage = undefined; } catch(e){}"); } catch (_) {}
          } catch (e) {
            debugPrint('FPK: __dispatchFlutterImage eval error: ' + e.toString());
          }

          // Give WebView a bit more time after dispatch attempts
          await Future.delayed(const Duration(milliseconds: 600));
          try {
            await _inAppController?.evaluateJavascript(source: "try { console.log('DBG visibility=', document.visibilityState, 'handlers=', (window.__flutterFileSelectedHandlers||0)); } catch(e) { console.log('DBG tracker missing', e); }");
          } catch (_) {}

          // Done
          debugPrint('FPK: dispatch finished');
        } else {
          debugPrint('FPK: picker returned null');
        }
      } else {
        debugPrint('FPK: dialog cancelled');
      }
    } catch (e) {
      print('Error handling file picker: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialUrl = 'https://skanuj-staging.web.app?company_name=kazimierz-club-new';
    return Scaffold(
      body: SafeArea(
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
            userAgent: 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
          ),
          initialUserScripts: UnmodifiableListView<UserScript>([
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
                    // Intercept file input programmatic/native openings
                    var HTMLInputProto = window.HTMLInputElement && window.HTMLInputElement.prototype;
                    if (HTMLInputProto) {
                      var __origClick = HTMLInputProto.click;
                      if (typeof __origClick === 'function') {
                        HTMLInputProto.click = function() {
                          try {
                            if (this && String(this.type).toLowerCase() === 'file') {
                              window.currentFileInput = this;
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
                            try { window.Flutter && window.Flutter.postMessage && window.Flutter.postMessage('file_picker_request'); } catch(_) {}
                          }
                        }
                      } catch(_) {}
                    }, true);
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
            )
          ]),
          onWebViewCreated: (controller) async {
            _inAppController = controller;
            _googleSignIn = GoogleSignIn(
              serverClientId: '159120615271-80ftbidbjk2a75idsuuqu8tklbu9fugb.apps.googleusercontent.com',
              scopes: ['email', 'profile'],
            );
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
                Future<Map<String, dynamic>> dispatchToWeb(String idToken, String accessToken, String serverAuthCode, String email, {bool fallback = false}) async {
                  debugPrint('GoogleSignIn: idToken len=${idToken.length}, accessToken len=${accessToken.length}, serverAuthCode len=${serverAuthCode.length}, email=$email, fallback=$fallback');
                  await _inAppController?.evaluateJavascript(source: """
                    try {
                      window.dispatchEvent(new CustomEvent('flutter_google_tokens', {
                        detail: { idToken: '${idToken.replaceAll("'", "\\'")}', accessToken: '${accessToken.replaceAll("'", "\\'")}', serverAuthCode: '${serverAuthCode.replaceAll("'", "\\'")}', email: '${email.replaceAll("'", "\\'")}', fallback: ${fallback ? 'true' : 'false'} }
                      }));
                      if (window.onFlutterGoogleSignIn) {
                        try { window.onFlutterGoogleSignIn({ idToken: '${idToken.replaceAll("'", "\\'")}', accessToken: '${accessToken.replaceAll("'", "\\'")}', serverAuthCode: '${serverAuthCode.replaceAll("'", "\\'")}', email: '${email.replaceAll("'", "\\'")}', fallback: ${fallback ? 'true' : 'false'} }); } catch(e) { console.error('onFlutterGoogleSignIn error', e); }
                      }
                    } catch (e) { console.error('Flutter -> Web tokens dispatch error', e); }
                  """);
                  return {
                    'idToken': idToken,
                    'accessToken': accessToken,
                    'serverAuthCode': serverAuthCode,
                    'email': email,
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
                  return await dispatchToWeb(auth.idToken ?? '', auth.accessToken ?? '', account.serverAuthCode ?? '', account.email);
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
                      return await dispatchToWeb(auth.idToken ?? '', auth.accessToken ?? '', account.serverAuthCode ?? '', account.email, fallback: true);
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
          },
          onConsoleMessage: (controller, msg) {
            debugPrint('WebView Console: \u001b[33m${msg.message}\u001b[0m');
          },
          onLoadStart: (controller, url) async {
            print('Page started loading: $url');
          },
          onLoadStop: (controller, url) async {
            print('Page finished loading: $url');
            await _injectPermissionOverrides();
          },
          onLoadError: (controller, url, code, message) {
            print('Web resource error: $message');
          },
          shouldOverrideUrlLoading: (controller, navAction) async {
            final url = navAction.request.url?.toString() ?? '';
            debugPrint('NAV: $url');
            if (url.contains('accounts.google.com') || url.contains('oauth2') || url.contains('gsi/client')) {
              debugPrint('NAV-OAUTH: forcing same view');
              return NavigationActionPolicy.ALLOW;
            }
            return NavigationActionPolicy.ALLOW;
          },
          onCreateWindow: (controller, createWindowAction) async {
            final uri = createWindowAction.request.url;
            final winId = createWindowAction.windowId;
            debugPrint('POPUP (main): uri=$uri, windowId=$winId');
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
                        onConsoleMessage: (c, m) => debugPrint('POPUP Console: ${m.message}'),
                        onLoadStop: (c, u) => debugPrint('POPUP loadStop: $u'),
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
              debugPrint('PROMPT file_picker_request received');
              // Defer picker to avoid evaluating JS while window.prompt is blocking the JS thread
              Future.microtask(() async {
                try {
                  if (_isPicking) {
                    debugPrint('FPK: duplicate picker request ignored (inflight)');
                    return;
                  }
                  _isPicking = true;
                  try {
                    await _inAppController?.evaluateJavascript(source: "try { window.__lastFlutterImage = undefined; window.__pendingFlutterFile = undefined; window.__pendingFlutterDataUrl = undefined; } catch(e){}");
                  } catch (_) {}
                  debugPrint('FPK: deferred picker start');
                  await _handleFilePicker();
                } catch (e) {
                  debugPrint('FPK: deferred picker error: ' + e.toString());
                } finally {
                  _isPicking = false;
                }
              });
              return JsPromptResponse(handledByClient: true, action: JsPromptResponseAction.CONFIRM, value: 'ok');
            }
            if (jsPromptRequest.message == 'window_open') {
              final url = jsPromptRequest.defaultValue ?? '';
              if (url.isNotEmpty) {
                debugPrint('PROMPT window_open -> $url');
                try { await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url))); } catch (_) {}
              }
              return JsPromptResponse(handledByClient: true, action: JsPromptResponseAction.CONFIRM, value: 'ok');
            }
            return JsPromptResponse(handledByClient: false);
          },
        ),
      ),
      // floatingActionButton: kDebugMode ? FloatingActionButton.small(
      //   onPressed: _setCustomUrlDialog,
      //   child: const Icon(Icons.link),
      //   tooltip: 'Set HTTPS URL',
      // ) : null,
    );
  }
} 