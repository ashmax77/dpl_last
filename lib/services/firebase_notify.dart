import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; 
import 'package:dlp_last/screens/intruder_alert_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<QuerySnapshot>? _doorAlertsSubscription;
  StreamSubscription<RemoteMessage>? _backgroundSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription; 
  
  String? _lastNotificationId;
  DateTime? _lastNotificationTime;
  
  bool _isInitializing = false;
  
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize() async {
    try {
      _isInitializing = true; 
      print('Starting notification service initialization...');
      print('⚠️ IMPORTANT: No notifications will be shown during initialization');
      
      await _requestPermissions();
      
      await _getFCMToken();
      
      await _initializeLocalNotifications();
      
      await _setupMessageHandlers();
      
      await _startDoorAlertsListener();
      
      _isInitializing = false; 
      print('✅ Notification service initialized successfully');
      print('✅ No automatic notifications shown during startup');
      print('✅ Only NEW door alerts will trigger notifications');
    } catch (e) {
      _isInitializing = false; 
      print('Error initializing notification service: $e');
      rethrow; 
    }
  }

  Future<void> _requestPermissions() async {
    try {
      print('Requesting notification permissions (this should not show any notifications)...');
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      print('User granted permission: ${settings.authorizationStatus}');
      print('✅ Permission request completed - no notifications shown');
    } catch (e) {
      print('Error requesting notification permissions: $e');
    }
  }

  Future<void> _getFCMToken() async {
    try {
      print('Getting FCM token (this should not trigger any notifications)...');
      String? token = await _messaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        await _storeFCMToken(token);
        print('✅ FCM token stored - no notifications shown');
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  Future<void> _storeFCMToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user logged in, cannot store FCM token');
        return;
      }

      await FirebaseFirestore.instance
          .collection('device_tokens')
          .doc(user.uid)
          .set({
        'token': token,
        'userId': user.uid,
        'deviceId': await _getDeviceId(),
        'platform': _getPlatform(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isActive': true,
      }, SetOptions(merge: true));

      print('FCM Token stored for user: ${user.uid}');
      print('Device ID: ${await _getDeviceId()}');
    } catch (e) {
      print('Error storing FCM token: $e');
    }
  }

  Future<String> _getDeviceId() async {
    try {
      final platform = _getPlatform();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return '${platform}_$timestamp';
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  String _getPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      const AndroidInitializationSettings androidSettings = 
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings iOSSettings = 
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iOSSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      await _createNotificationChannels();
      
      print('Local notifications initialized');
    } catch (e) {
      print('Error initializing local notifications: $e');
    }
  }

  Future<void> _createNotificationChannels() async {
    try {
      const AndroidNotificationChannel doorAlertsChannel = AndroidNotificationChannel(
        'door_alerts_channel',
        'Door Alerts',
        description: 'Notifications for door security alerts',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );
      const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
        'general_channel',
        'General Notifications',
        description: 'General app notifications',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: false,
        showBadge: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(doorAlertsChannel);
          
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(generalChannel);
          
      print('Notification channels created');
    } catch (e) {
      print('Error creating notification channels: $e');
    }
  }
  Future<void> _setupMessageHandlers() async {
    try {
      _backgroundSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage);
      }
      
      print('Message handlers set up (foreground messages disabled)');
    } catch (e) {
      print('Error setting up message handlers: $e');
    }
  }
  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message received but ignored: ${message.notification?.title}');
  }

  Future<void> enableForegroundMessaging() async {
    try {
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      print('Foreground messaging enabled');
    } catch (e) {
      print('Error enabling foreground messaging: $e');
    }
  }

  void disableForegroundMessaging() {
    _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
    print('Foreground messaging disabled');
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    print('Received background message: ${message.notification?.title}');
    
    if (message.data.containsKey('type')) {
      switch (message.data['type']) {
        case 'door_alert':
          print('Door alert received');
          break;
        case 'lock_alert':
          print('Lock alert received');
          break;
        case 'user_activity':
          print('User activity notification');
          break;
        default:
          print('Unknown message type: ${message.data['type']}');
      }
    }
  }

  Future<void> _startDoorAlertsListener() async {
    try {
      print('Starting door alerts listener...');
      
      String? lastProcessedId;
      
      _doorAlertsSubscription = FirebaseFirestore.instance
          .collection('door_alerts')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen(
        (QuerySnapshot snapshot) {
          print('Door alerts snapshot received: ${snapshot.docs.length} documents');
          if (snapshot.docs.isNotEmpty) {
            final latestDoc = snapshot.docs.first;
            final latestId = latestDoc.id;
            
            if (lastProcessedId == null) {
              lastProcessedId = latestId;
              print('Initial door alerts snapshot - storing latest ID: $latestId (no notification)');
            } else if (latestId != lastProcessedId) {
              print('New door alert detected: $latestId');
              _processDoorAlert(latestDoc);
              lastProcessedId = latestId;
            } else {
              print('No new door alerts - latest ID unchanged: $latestId');
            }
          }
        },
        onError: (error) {
          print('Error listening to door alerts: $error');
        },
      );
      
      print('Door alerts listener started successfully - will only notify for NEW alerts');
    } catch (e) {
      print('Error starting door alerts listener: $e');
    }
  }

  void _processDoorAlert(DocumentSnapshot document) {
    try {
      if (_isInitializing) {
        print('⚠️ Skipping door alert processing during initialization: ${document.id}');
        return;
      }
      
      final data = document.data() as Map<String, dynamic>?;
      if (data == null) return;

      final alertId = document.id;
      final timestamp = data['timestamp'] as Timestamp?;
      
      if (_lastNotificationId == alertId) {
        final timeDiff = DateTime.now().difference(_lastNotificationTime ?? DateTime.now());
        if (timeDiff.inMinutes < 1) {
          return;
        }
      }
      _lastNotificationId = alertId;
      _lastNotificationTime = DateTime.now();

      final alertType = data['type'] ?? 'Intruder';
      final description = data['description'] ?? 'Door activity detected';
      final location = data['location'] ?? 'Main entrance';
 
      _showDoorAlertNotification(
        title: 'Door Alert: $alertType',
        body: '$description at $location',
        alertId: alertId,
        data: data,
      );

      print('Door alert processed: $alertId');
    } catch (e) {
      print('Error processing door alert: $e');
    }
  }

  void _showDoorAlertNotification({
    required String title,
    required String body,
    required String alertId,
    Map<String, dynamic>? data,
  }) {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'door_alerts_channel',
        'Door Alerts',
        channelDescription: 'Notifications for door security alerts',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFE53935), 
      );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      final payload = {
        'type': data?['type'] ?? 'Security Alert',
        'description': data?['description'] ?? 'Door activity detected',
        'location': data?['location'] ?? 'Main entrance',
        'timestamp': data?['timestamp']?.toDate()?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'alertId': alertId,
      };

      _localNotifications.show(
        alertId.hashCode, 
        title,
        body,
        details,
        payload: payload.toString(),
      );

      print('Door alert notification sent: $alertId');
      print('Notification payload: $payload');
    } catch (e) {
      print('Error showing door alert notification: $e');
    }
  }

  void _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'general_channel',
        'General Notifications',
        channelDescription: 'General app notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showWhen: true,
      );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, 
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    print('Navigator key set for notification service');
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    
    if (response.payload != null) {
      try {
        final payloadString = response.payload!;
        Map<String, dynamic>? alertData;
        
        if (payloadString.startsWith('{') && payloadString.endsWith('}')) {
          final cleanPayload = payloadString.substring(1, payloadString.length - 1);
          final pairs = cleanPayload.split(',');
          alertData = {};
          
          for (final pair in pairs) {
            final keyValue = pair.split(':');
            if (keyValue.length == 2) {
              final key = keyValue[0].trim().replaceAll('"', '').replaceAll("'", '');
              var value = keyValue[1].trim().replaceAll('"', '').replaceAll("'", '');
              
              if (key == 'timestamp') {
                try {
                  final dateTime = DateTime.parse(value);
                  alertData[key] = dateTime;
                } catch (e) {
                  alertData[key] = DateTime.now();
                }
              } else {
                alertData[key] = value;
              }
            }
          }
        } else {
          alertData = {
            'type': 'Security Alert',
            'description': 'Door activity detected',
            'location': 'Main entrance',
            'timestamp': DateTime.now(),
          };
        }
        
        print('Parsed alert data: $alertData');
        
        if (_navigatorKey?.currentState != null) {
          _navigatorKey!.currentState!.pushNamed(
            '/intruder-alert',
            arguments: alertData,
          );
          print('✅ Navigated to intruder alert screen');
        } else {
          print('⚠️ Navigator key not available for navigation');
        }
      } catch (e) {
        print('Error handling notification tap: $e');
        if (_navigatorKey?.currentState != null) {
          _navigatorKey!.currentState!.pushNamed(
            '/intruder-alert',
            arguments: {
              'type': 'Security Alert',
              'description': 'Door activity detected',
              'location': 'Main entrance',
              'timestamp': DateTime.now(),
            },
          );
        }
      }
    }
  }

  Future<void> sendTestNotification() async {
    try {
      print('Sending test notification...');
      _showLocalNotification(
        title: 'Test Notification',
        body: 'This is a test notification from the app',
        payload: 'test',
      );
      print('Test notification sent successfully');
    } catch (e) {
      print('Error sending test notification: $e');
    }
  }

  Future<void> createTestDoorAlert() async {
    try {
      print('Creating test door alert...');
      final docRef = await FirebaseFirestore.instance
          .collection('door_alerts')
          .add({
        'type': 'Alert',
        'description': 'door alert',
        'location': 'Test Location',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid ?? 'test_user',
        'test': true,
      });
      print('Test door alert created in Firestore with ID: ${docRef.id}');
      print('This should trigger a notification if the listener is working properly');
    } catch (e) {
      print('Error creating test door alert: $e');
    }
  }

  Future<void> testDoorAlertsListener() async {
    try {
      print('Testing door alerts listener...');
      print('Current subscription status: ${_doorAlertsSubscription != null ? 'Active' : 'Inactive'}');
      
      if (_doorAlertsSubscription != null) {
        print('Door alerts listener is active and listening for changes');
        print('Create a test door alert to verify notifications are working');
      } else {
        print('Door alerts listener is not active');
      }
    } catch (e) {
      print('Error testing door alerts listener: $e');
    }
  }

  Map<String, dynamic> getServiceStatus() {
    return {
      'doorAlertsListenerActive': _doorAlertsSubscription != null,
      'foregroundMessagingEnabled': _foregroundSubscription != null,
      'backgroundMessagingEnabled': _backgroundSubscription != null,
      'localNotificationsInitialized': _localNotifications != null,
      'lastNotificationId': _lastNotificationId,
      'lastNotificationTime': _lastNotificationTime?.toIso8601String(),
    };
  }

  Future<void> checkPermissions() async {
    try {
      NotificationSettings settings = await _messaging.getNotificationSettings();
      print('Notification settings:');
      print('- Authorization status: ${settings.authorizationStatus}');
      print('- Alert: ${settings.alert}');
      print('- Badge: ${settings.badge}');
      print('- Sound: ${settings.sound}');
      
      String? token = await _messaging.getToken();
      print('FCM Token: ${token ?? 'Not available'}');
      
      final deviceId = await _getDeviceId();
      final platform = _getPlatform();
      print('Device ID: $deviceId');
      print('Platform: $platform');
    } catch (e) {
      print('Error checking permissions: $e');
    }
  }

  Future<Map<String, String>> getDeviceInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await _messaging.getToken();
      final deviceId = await _getDeviceId();
      final platform = _getPlatform();
      
      return {
        'userId': user?.uid ?? 'Not logged in',
        'deviceId': deviceId,
        'platform': platform,
        'fcmToken': token ?? 'Not available',
      };
    } catch (e) {
      print('Error getting device info: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  void dispose() {
    _doorAlertsSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _backgroundSubscription?.cancel();
    print('Notification service disposed');
  }
}
final notificationService = NotificationService();