import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initNotifications() async {
    // Request permission (Required for Android 13+ and iOS)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted permission');
      
      // 📍 SIMPLE TOPIC SUBSCRIPTION
      // Every user who opens the app joins this "broadcast group"
      await _firebaseMessaging.subscribeToTopic('blood_alerts');
      print('📡 Subscribed to blood_alerts topic');

    } else {
      print('❌ User declined permission');
    }
  }
}