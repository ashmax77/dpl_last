import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class notificationService {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  StreamSubscription<QuerySnapshot>? _doorAlertsSubscription;

  void initialize() {
    messaging.requestPermission();
    messaging.getToken().then((token) {
      print("Firebase Messaging Token: $token");
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Received message on foreground: ${message.notification!.body}");
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Message opened app: ${message.notification!.body}");
    });

    // Initialize local notifications
    _initializeLocalNotifications();
    
    // Start listening to door-alerts collection
    _startDoorAlertsListener();
  }

  void _initializeLocalNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification tapped: ${response.payload}');
      },
    );
  }

  void _startDoorAlertsListener() {
    _doorAlertsSubscription = FirebaseFirestore.instance
        .collection('door-alerts')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      if (snapshot.docs.isNotEmpty) {
        // Get the most recent document
        DocumentSnapshot latestDoc = snapshot.docs.first;
        
        // Check if this is a new document (you might want to add additional logic here)
        // For now, we'll send a notification for any document in the snapshot
        _sendDoorAlertNotification(latestDoc);
      }
    }, onError: (error) {
      print('Error listening to door-alerts: $error');
    });
  }

  void _sendDoorAlertNotification(DocumentSnapshot document) {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'door_alerts_channel',
      'Door Alerts',
      channelDescription: 'Notifications for door alert events',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      'Door Alert',
      'A new door alert has been detected!',
      platformChannelSpecifics,
    );

    print('Door alert notification sent for document: ${document.id}');
  }

  void dispose() {
    _doorAlertsSubscription?.cancel();
  }
}