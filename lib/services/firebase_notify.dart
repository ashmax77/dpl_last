import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Added for Color

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<QuerySnapshot>? _doorAlertsSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _backgroundSubscription;
  
  // Track last notification to avoid duplicates
  String? _lastNotificationId;
  DateTime? _lastNotificationTime;

  /// Initialize notification service
  Future<void> initialize() async {
    try {
      print('Starting notification service initialization...');
      
      // Request permissions
      await _requestPermissions();
      
      // Get FCM token
      await _getFCMToken();
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Set up message handlers
      await _setupMessageHandlers();
      
      // Start listening to door alerts
      await _startDoorAlertsListener();
      
      print('Notification service initialized successfully');
    } catch (e) {
      print('Error initializing notification service: $e');
      rethrow; // Re-throw to see the error in main
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
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
    } catch (e) {
      print('Error requesting notification permissions: $e');
    }
  }

  /// Get FCM token
  Future<void> _getFCMToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        
        // Store token in Firestore for server-side notifications
        await _storeFCMToken(token);
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  /// Store FCM token in Firestore
  Future<void> _storeFCMToken(String token) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user logged in, cannot store FCM token');
        return;
      }

      // Store token in Firestore with device identification
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

  /// Get unique device identifier
  Future<String> _getDeviceId() async {
    try {
      // Use FCM token as device identifier (it's unique per device)
      String? token = await _messaging.getToken();
      return token ?? DateTime.now().millisecondsSinceEpoch.toString();
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// Get platform information
  String _getPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    try {
      // Android initialization settings
      const AndroidInitializationSettings androidSettings = 
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization settings
      const DarwinInitializationSettings iOSSettings = 
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      // Combined initialization settings
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iOSSettings,
      );

      // Initialize the plugin
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels for Android
      await _createNotificationChannels();
      
      print('Local notifications initialized');
    } catch (e) {
      print('Error initializing local notifications: $e');
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    try {
      // Door alerts channel
      const AndroidNotificationChannel doorAlertsChannel = AndroidNotificationChannel(
        'door_alerts_channel',
        'Door Alerts',
        description: 'Notifications for door security alerts',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      // General notifications channel
      const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
        'general_channel',
        'General Notifications',
        description: 'General app notifications',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: false,
        showBadge: true,
      );

      // Create channels
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

  /// Set up message handlers
  Future<void> _setupMessageHandlers() async {
    try {
      // Handle foreground messages
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle when app is opened from notification
      _backgroundSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      
      // Handle app launch from notification
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage);
      }
      
      print('Message handlers set up');
    } catch (e) {
      print('Error setting up message handlers: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground message: ${message.notification?.title}');
    
    // Show local notification
    _showLocalNotification(
      title: message.notification?.title ?? 'New Message',
      body: message.notification?.body ?? 'You have a new notification',
      payload: message.data.toString(),
    );
  }

  /// Handle background messages
  void _handleBackgroundMessage(RemoteMessage message) {
    print('Received background message: ${message.notification?.title}');
    
    // Handle navigation or other actions based on message data
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

  /// Start listening to door alerts from Firestore
  Future<void> _startDoorAlertsListener() async {
    try {
      _doorAlertsSubscription = FirebaseFirestore.instance
          .collection('door_alerts')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen(
        (QuerySnapshot snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final latestDoc = snapshot.docs.first;
            _processDoorAlert(latestDoc);
          }
        },
        onError: (error) {
          print('Error listening to door alerts: $error');
        },
      );
      
      print('Door alerts listener started');
    } catch (e) {
      print('Error starting door alerts listener: $e');
    }
  }

  /// Process door alert and send notification
  void _processDoorAlert(DocumentSnapshot document) {
    try {
      final data = document.data() as Map<String, dynamic>?;
      if (data == null) return;

      final alertId = document.id;
      final timestamp = data['timestamp'] as Timestamp?;
      
      // Check if this is a new alert (avoid duplicates)
      if (_lastNotificationId == alertId) {
        final timeDiff = DateTime.now().difference(_lastNotificationTime ?? DateTime.now());
        if (timeDiff.inMinutes < 1) {
          return; // Skip if same alert within 1 minute
        }
      }

      // Update tracking
      _lastNotificationId = alertId;
      _lastNotificationTime = DateTime.now();

      // Extract alert information
      final alertType = data['type'] ?? 'Unknown';
      final description = data['description'] ?? 'Door activity detected';
      final location = data['location'] ?? 'Main entrance';
 
      // Show notification
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

  /// Show door alert notification
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
        color: Color(0xFFE53935), // Red color for alerts
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
        alertId.hashCode, // Use hash as notification ID
        title,
        body,
        details,
        payload: data?.toString(),
      );

      print('Door alert notification sent: $alertId');
    } catch (e) {
      print('Error showing door alert notification: $e');
    }
  }

  /// Show general local notification
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
        DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    
    // Handle navigation based on notification type
    if (response.payload != null) {
      // You can add navigation logic here
      print('Notification payload: ${response.payload}');
    }
  }

  /// Send test notification
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

  /// Create a test door alert in Firestore
  Future<void> createTestDoorAlert() async {
    try {
      await FirebaseFirestore.instance
          .collection('door_alerts')
          .add({
        'type': 'Test Alert',
        'description': 'This is a test door alert',
        'location': 'Test Location',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid ?? 'test_user',
      });
      print('Test door alert created in Firestore');
    } catch (e) {
      print('Error creating test door alert: $e');
    }
  }

  /// Check notification permissions
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
      
      // Get device info
      final deviceId = await _getDeviceId();
      final platform = _getPlatform();
      print('Device ID: $deviceId');
      print('Platform: $platform');
    } catch (e) {
      print('Error checking permissions: $e');
    }
  }

  /// Get device information
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

  /// Dispose resources
  void dispose() {
    _doorAlertsSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _backgroundSubscription?.cancel();
    print('Notification service disposed');
  }
}

// Global instance for easy access
final notificationService = NotificationService();