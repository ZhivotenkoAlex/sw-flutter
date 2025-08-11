import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:image_picker/image_picker.dart';
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
          if (message.message == 'file_picker_request') {
            _handleFilePicker();
          }
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
      
    // Load the page first; inject after page navigation events
    controller.loadRequest(Uri.parse('https://skanuj-staging.web.app?company_name=kazimierz-club-new'));
  }

  Future<void> _injectPermissionOverrides() async {
    final fcmToken = FirebaseMessagingService.fcmToken;
    print('Injecting ULTIMATE permission overrides with token: $fcmToken');
    
    try {
      await controller.runJavaScript('''
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
          
          // Override getUserMedia for camera/microphone access
          if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
            const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
            navigator.mediaDevices.getUserMedia = function(constraints) {
              console.log('📷 getUserMedia called with constraints:', constraints);
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
            console.log('🎯 Target file button matched:', matchedSelector);
            
            // From here on, we will drive the native picker
            e.preventDefault();
            e.stopPropagation();
            
            let fileInput = null;
            let shouldIntercept = false;
            
            // Direct file input click
            if (e.target.type === 'file') {
              fileInput = e.target;
              shouldIntercept = true;
              console.log('📁 Direct file input clicked');
            }
            // Label pointing to file input
            else if (e.target.tagName === 'LABEL') {
              const forAttr = e.target.getAttribute('for');
              if (forAttr) {
                fileInput = document.getElementById(forAttr);
                if (fileInput && fileInput.type === 'file') {
                  shouldIntercept = true;
                  console.log('📁 Label for file input clicked');
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
                console.log('📁 Element associated with file input clicked');
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
              e.target.textContent.toLowerCase().includes('dodaj') // Polish for add
            )) {
              // Look for nearby file input
              fileInput = document.querySelector('input[type="file"]');
              if (fileInput) {
                shouldIntercept = true;
                console.log('📁 Upload-related element clicked, found file input');
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
                console.log('📁 Component with file-related classes clicked');
              }
            }
            
            // If no real input found near the targeted button, try to reuse an existing one
            if (!shouldIntercept) {
              const existingInputs = Array.from(document.querySelectorAll('input[type="file"]'));
              const candidate = existingInputs.reverse().find(inp => !inp.disabled);
              if (candidate) {
                fileInput = candidate;
                shouldIntercept = true;
                console.log('🧭 Using existing file input found on page');
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
                console.log('🧪 Created virtual file input for targeted button');
              }
            }
            
            if (shouldIntercept && fileInput) {
              console.log('📁 Intercepting file input interaction');
              e.preventDefault();
              e.stopPropagation();
              
              // Store reference to the file input
              window.currentFileInput = fileInput;
              
              if (window.Flutter && window.Flutter.postMessage) {
                console.log('📱 Sending file_picker_request to Flutter');
                window.Flutter.postMessage('file_picker_request');
              } else {
                console.log('❌ Flutter bridge not available');
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
              console.log('🔄 DOM CHANGED - Rescanning for new elements...');
              console.log('📁 Found', fileInputs.length, 'file inputs on page');
              
              fileInputs.forEach(function(input, index) {
                if (index >= lastFileInputCount) { // Only log new ones
                  console.log('📁 NEW File input', index + 1, ':', {
                    id: input.id,
                    name: input.name,
                    accept: input.accept,
                    multiple: input.multiple,
                    hidden: input.style.display === 'none' || input.hidden,
                    className: input.className
                  });
                }
              });
              
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
                    className.includes('upload') || className.includes('file') || className.includes('photo')) {
                  potentialUploadButtons.push({
                    tagName: btn.tagName,
                    text: text,
                    className: className,
                    id: btn.id
                  });
                }
              });
              
              if (potentialUploadButtons.length > 0) {
                console.log('🎯 Found', potentialUploadButtons.length, 'potential upload buttons:');
                potentialUploadButtons.forEach(function(btn, index) {
                  console.log('🎯 Button', index + 1, ':', btn);
                });
              }
              
              lastFileInputCount = fileInputs.length;
              lastButtonCount = allButtons.length;
              console.log('✅ Scan completed - Monitoring for Module Federation changes...');
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
              console.log('🔄 MutationObserver detected new elements - rescanning...');
              setTimeout(scanForDynamicElements, 500);
            }
          });
          
          observer.observe(document.body, {
            childList: true,
            subtree: true
          });
          
          console.log('✅ Module Federation monitoring active - watching for dynamic content');
          
          // Also handle focus events on file inputs
          document.addEventListener('focus', function(e) {
            if (e.target.type === 'file') {
              console.log('📁 File input focused, using Flutter bridge');
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
          
          console.log('🎉 ULTIMATE Firebase bridge injection completed');
          console.log('🔥 FCM Token available:', '$fcmToken');
          console.log('📱 Notification permissions FAKED and LOCKED');
          console.log('⚙️ Service worker should work with fake permissions');
          
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
      final ImagePicker picker = ImagePicker();
      
      // Show options: Camera or Gallery
      final result = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Select Image'),
            content: const Text('Choose an option:'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('camera'),
                child: const Text('Camera'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('gallery'),
                child: const Text('Gallery'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );

      if (result != null) {
        final XFile? image;
        if (result == 'camera') {
          image = await picker.pickImage(source: ImageSource.camera);
        } else {
          image = await picker.pickImage(source: ImageSource.gallery);
        }

        if (image != null) {
          // Convert image to base64 and send back to web app
          final bytes = await image.readAsBytes();
          final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          
          // Send the image data back to the web app
          await controller.runJavaScript('''
            if (window.currentFileInput) {
              console.log('📁 Processing selected image for file input');
              
              // Convert base64 to blob
              const base64Data = '$base64Image'.split(',')[1];
              const byteCharacters = atob(base64Data);
              const byteNumbers = new Array(byteCharacters.length);
              for (let i = 0; i < byteCharacters.length; i++) {
                byteNumbers[i] = byteCharacters.charCodeAt(i);
              }
              const byteArray = new Uint8Array(byteNumbers);
              const blob = new Blob([byteArray], { type: 'image/jpeg' });
              
              // Create a File object
              const file = new File([blob], '${image.name}', { type: 'image/jpeg' });
              
              // Create a FileList-like object
              const dataTransfer = new DataTransfer();
              dataTransfer.items.add(file);
              
              try {
                // Set the files property of the input
                window.currentFileInput.files = dataTransfer.files;
              } catch (err) {
                console.log('⚠️ Setting input.files failed (likely read-only):', err);
              }
              
              // Trigger change event
              const changeEvent = new Event('change', { bubbles: true, composed: true });
              window.currentFileInput.dispatchEvent(changeEvent);
              
              // Also trigger input event for some frameworks
              const inputEvent = new Event('input', { bubbles: true, composed: true });
              window.currentFileInput.dispatchEvent(inputEvent);
              
              // Fallback: dispatch a drag-drop style event many libs listen to
              try {
                const dropEvent = new DragEvent('drop', { bubbles: true, composed: true, dataTransfer: dataTransfer });
                window.currentFileInput.dispatchEvent(dropEvent);
                const container = window.currentFileInput.closest('form') || window.currentFileInput.parentElement;
                if (container) container.dispatchEvent(dropEvent);
              } catch (err) {
                console.log('⚠️ Creating DragEvent failed:', err);
              }
              
              // Inform host and federated module listeners
              try {
                // 1) Global event with full data URL for Vue listener
                window.dispatchEvent(new CustomEvent('flutter_file_selected', {
                  detail: { fileName: '${image.name}', fileData: '$base64Image' }
                }));

                // 2) Element-scoped event as well (if needed)
                const targetBtn = document.querySelector('[data-flutter-file-input="1"]');
                if (targetBtn) {
                  targetBtn.dispatchEvent(new CustomEvent('flutter_file_selected', {
                    detail: { fileName: '${image.name}', fileData: '$base64Image' },
                    bubbles: true
                  }));
                }

                // 3) Direct global handler hook if module exposes it
                if (typeof window.appUploadOrScanHandler === 'function') {
                  window.appUploadOrScanHandler([file]);
                } else {
                  // 4) Queue for when module mounts
                  window.__pendingFlutterFile = file;
                  window.__pendingFlutterDataUrl = '$base64Image';
                }
              } catch (err) {
                console.log('⚠️ Dispatch to app failed:', err);
              }

              console.log('📁 Image dispatched to page events:', '${image.name}');
              
              // Clear the reference
              window.currentFileInput = null;
            } else {
              console.log('❌ No file input reference found');
            }
          ''');
        }
      }
    } catch (e) {
      print('Error handling file picker: $e');
    }
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