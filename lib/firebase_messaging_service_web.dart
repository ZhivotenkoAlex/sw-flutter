// This file contains mock Firebase implementations for web platforms
// The main service file will import this conditionally

// Mock Firebase classes for web
class Firebase {
  static Future<void> initializeApp() async {
    // Mock implementation for web
  }
}

class FirebaseMessaging {
  static FirebaseMessaging get instance => FirebaseMessaging();
  
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
  }) async {
    return NotificationSettings(
      authorizationStatus: AuthorizationStatus.authorized,
      alert: alert,
      announcement: announcement,
      badge: badge,
      carPlay: carPlay,
      criticalAlert: criticalAlert,
      provisional: provisional,
      sound: sound,
    );
  }
  
  Future<String?> getToken() async {
    return 'web-mock-token-${DateTime.now().millisecondsSinceEpoch}';
  }
  
  static Stream<RemoteMessage> get onMessage => Stream.empty();
  static Stream<RemoteMessage> get onMessageOpenedApp => Stream.empty();
  static Future<RemoteMessage?> getInitialMessage() async => null;
}

class NotificationSettings {
  final AuthorizationStatus authorizationStatus;
  final bool alert;
  final bool announcement;
  final bool badge;
  final bool carPlay;
  final bool criticalAlert;
  final bool provisional;
  final bool sound;
  
  NotificationSettings({
    required this.authorizationStatus,
    required this.alert,
    required this.announcement,
    required this.badge,
    required this.carPlay,
    required this.criticalAlert,
    required this.provisional,
    required this.sound,
  });
}

enum AuthorizationStatus { authorized, denied, notDetermined, provisional }

class RemoteMessage {
  final String? messageId;
  final Map<String, dynamic> data;
  final RemoteNotification? notification;
  
  RemoteMessage({
    this.messageId,
    required this.data,
    this.notification,
  });
}

class RemoteNotification {
  final String? title;
  final String? body;
  final String? icon;
  
  RemoteNotification({
    this.title,
    this.body,
    this.icon,
  });
}

// Mock background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Mock implementation for web
} 