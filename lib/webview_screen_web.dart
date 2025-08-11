import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;

const url = 'https://skanuj-staging.web.app?company_name=kazimierz-club-new';

// Register the view factory only once
void _registerIFrameViewFactory() {
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(
    'iframeElement',
    (int viewId) => html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%',
  );
}

final _iframeRegistered = (() {
  _registerIFrameViewFactory();
  return true;
})();

class WebViewScreen extends StatelessWidget {
  const WebViewScreen({super.key});
  @override
  Widget build(BuildContext context) {
    _iframeRegistered; // Ensures registration
    
    // Inject Firebase bridge for web
    _injectWebFirebaseBridge();
    
    return Scaffold(
      body: HtmlElementView(viewType: 'iframeElement'),
    );
  }
  
  void _injectWebFirebaseBridge() {
    // For web, inject a comprehensive Firebase bridge
    print('Web version: Injecting Firebase bridge for web app');
    
    // This will be injected into the iframe when it loads
    html.window.addEventListener('load', (event) {
      _injectFirebaseBridgeIntoIframe();
    });
  }
  
  void _injectFirebaseBridgeIntoIframe() {
    try {
      // Get the iframe element
      final iframe = html.document.querySelector('iframe') as html.IFrameElement?;
      if (iframe == null) {
        print('Iframe not found');
        return;
      }
      
      // Wait for iframe to load and then inject
      iframe.onLoad.listen((event) {
        _injectScriptIntoIframe(iframe);
      });
      
    } catch (e) {
      print('Error setting up iframe injection: $e');
    }
  }
  
  void _injectScriptIntoIframe(html.IFrameElement iframe) {
    try {
      // Access the iframe's document safely
      final iframeWindow = iframe.contentWindow;
      if (iframeWindow == null) {
        print('Iframe window not accessible');
        return;
      }
      
      // Cast to proper type to access document
      final iframeDoc = (iframeWindow as html.Window).document as html.HtmlDocument;
      
      // Inject the Firebase bridge into the iframe
      final script = iframeDoc.createElement('script');
      script.text = '''
        (function() {
          console.log('Injecting Firebase bridge into iframe...');
          
          // Mock serviceWorkerVersion
          if (typeof serviceWorkerVersion === 'undefined') {
            window.serviceWorkerVersion = '1.0.0';
            console.log('serviceWorkerVersion defined:', window.serviceWorkerVersion);
          }
          
          // Override Notification.requestPermission
          if (typeof Notification !== 'undefined') {
            const originalRequestPermission = Notification.requestPermission;
            Notification.requestPermission = function() {
              console.log('Notification.requestPermission called, granting permission');
              return Promise.resolve('granted');
            };
            console.log('Notification.requestPermission overridden');
          }
          
          // Create mock Firebase messaging
          if (typeof firebase === 'undefined') {
            window.firebase = {};
          }
          
          firebase.messaging = function() {
            console.log('Firebase messaging() called, returning mock implementation');
            return {
              getToken: function(options) {
                console.log('Firebase messaging getToken called, returning mock token');
                return Promise.resolve('web-mock-fcm-token-' + Date.now());
              },
              onMessage: function(callback) {
                console.log('Firebase messaging onMessage registered');
                return Promise.resolve();
              },
              onBackgroundMessage: function(callback) {
                console.log('Firebase messaging onBackgroundMessage registered');
                return Promise.resolve();
              },
              requestPermission: function() {
                console.log('Firebase messaging requestPermission called');
                return Promise.resolve('granted');
              }
            };
          };
          
          // Override the messaging property
          Object.defineProperty(firebase, 'messaging', {
            get: function() {
              return firebase.messaging();
            },
            configurable: true
          });
          
          console.log('Firebase bridge injected successfully into iframe');
        })();
      ''';
      
      if (iframeDoc.head != null) {
        iframeDoc.head!.children.add(script);
      }
      print('Firebase bridge script injected into iframe');
      
    } catch (e) {
      print('Error injecting Firebase bridge into iframe: $e');
    }
  }
} 