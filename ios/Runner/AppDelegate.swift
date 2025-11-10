import Flutter
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    
    // Note: Firebase will be initialized in Dart code after app launch
    // We'll set the Messaging delegate later when Firebase is initialized
    // This is handled in _setMessagingDelegateIfNeeded()
    
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Helper to set Messaging delegate when Firebase is initialized
  private func _setMessagingDelegateIfNeeded() {
    if FirebaseApp.app() != nil {
      Messaging.messaging().delegate = self
      print("[AppDelegate] Firebase Messaging delegate set")
    }
  }
  
  // Manually forward APNs token to Firebase Messaging (required with FirebaseAppDelegateProxyEnabled=false)
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Set delegate if Firebase is initialized
    _setMessagingDelegateIfNeeded()
    
    // Forward APNs token to Firebase Messaging
    if FirebaseApp.app() != nil {
      Messaging.messaging().apnsToken = deviceToken
      print("[AppDelegate] APNs token set to Firebase Messaging (project: \(FirebaseApp.app()!.options.projectId))")
    } else {
      print("[AppDelegate] Firebase not initialized yet, APNs token will be set later")
      // Store token temporarily - Firebase Messaging will request it when initialized
    }
    // Also call super to ensure Flutter plugins receive the token
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[AppDelegate] Failed to register for remote notifications: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}

// Extension to handle Firebase Messaging delegate methods
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("[AppDelegate] FCM registration token: \(fcmToken ?? "nil")")
    // Forward to Flutter via method channel if needed
    // The Flutter plugin will handle this automatically
  }
}
