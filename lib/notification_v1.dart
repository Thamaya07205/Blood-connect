import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/foundation.dart';

class NotificationV1 {
  // 📍 Your specific Service Account Credentials
 

  static const _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  static Future<String> getAccessToken() async {
    final accountCredentials = ServiceAccountCredentials.fromJson(_serviceAccountCredentials);
    final client = await clientViaServiceAccount(accountCredentials, _scopes);
    return client.credentials.accessToken.data;
  }

  // Broadcast to all users via topic
  static Future<void> sendBroadcast(String requestId, String bloodType, String name) async {
    try {
      final String token = await getAccessToken();
      final String projectID = _serviceAccountCredentials['project_id']!;
      const String topicName = "blood_alerts";

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/$projectID/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "message": {
            "topic": topicName,
            "notification": {
              "title": "Urgent Blood Request!",
              "body": "$name needs $bloodType blood urgently."
            },
            "data": {
              "type": "blood_request",
              "requestId": requestId,
              "bloodType": bloodType,
              "requesterName": name,
            },
            "android": {
              "priority": "high",
            }
          }
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ Broadcast Notification Sent Successfully");
      } else {
        debugPrint("❌ FCM Error: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Exception in Notification Broadcast: $e");
    }
  }

  // 📍 NEW: Send private notification to a specific requester
  static Future<void> sendResponseNotification({
    required String targetToken,
    required String donorName,
    required String bloodType,
  }) async {
    try {
      final String accessToken = await getAccessToken();
      final String projectID = _serviceAccountCredentials['project_id']!;

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/$projectID/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          "message": {
            "token": targetToken, 
            "notification": {
              "title": "Volunteer Found!",
              "body": "$donorName wants to help with your $bloodType request."
            },
            "data": {
              "type": "donor_response",
            },
          }
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ Response Notification Sent to Requester");
      } else {
        debugPrint("❌ FCM Response Error: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Exception in Response Notification: $e");
    }
  }
}