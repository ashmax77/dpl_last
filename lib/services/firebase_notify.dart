import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Added for Color
import 'package:dlp_last/screens/intruder_alert_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<QuerySnapshot>? _doorAlertsSubscription;
  StreamSubscription<RemoteMessage>? _backgroundSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription; // Added for foreground messaging
  
  // Track last notification to avoid duplicates
  String? _lastNotificationId;
  DateTime? _lastNotificationTime;
  
  // Flag to prevent notifications during initialization
  bool _isInitializing = false;
  
  // Global navigation key for handling notification taps
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize notification service
  Future<void> initialize() async {
    try {
      _isInitializing = true; // Prevent any notifications during initialization
      print('Starting notification service initialization...');
      print('⚠️ IMPORTANT: No notifications will be shown during initialization');
      
      // Request permissions (this should not trigger any notifications)
      await _requestPermissions();
      
      // Get FCM token (for server-side notifications only)
      await _getFCMToken();
      
      // Initialize local notifications (this should not trigger any notifications)
      await _initializeLocalNotifications();
      
      // Set up message handlers (background only, no foreground alerts)
      await _setupMessageHandlers();
      
      // Start listening to door alerts from Firestore (will not process existing alerts)
      await _startDoorAlertsListener();
      
      _isInitializing = false; // Allow notifications after initialization
      print('✅ Notification service initialized successfully');
      print('✅ No automatic notifications shown during startup');
      print('✅ Only NEW door alerts will trigger notifications');
    } catch (e) {
      _isInitializing = false; // Reset flag on error
      print('Error initializing notification service: $e');
      rethrow; // Re-throw to see the error in main
    }
  }

  /// Request notification permissions
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

  /// Get FCM token
  Future<void> _getFCMToken() async {
    try {
      print('Getting FCM token (this should not trigger any notifications)...');
      String? token = await _messaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        
        // Store token in Firestore for server-side notifications only
        // This does NOT trigger automatic alerts on login
        await _storeFCMToken(token);
        print('✅ FCM token stored - no notifications shown');
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
      // Use a combination of platform and timestamp for device identification
      // Avoid calling getToken() again to prevent triggering Firebase events
      final platform = _getPlatform();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return '${platform}_$timestamp';
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
      // Only handle background messages when app is opened from notification
      // Don't set up foreground message handler to prevent automatic alerts on login
      _backgroundSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      
      // Handle app launch from notification
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage);
      }
      
      print('Message handlers set up (foreground messages disabled)');
    } catch (e) {
      print('Error setting up message handlers: $e');
    }
  }

  /// Handle foreground messages - DISABLED to prevent automatic alerts on login
  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message received but ignored: ${message.notification?.title}');
    // Do not show any notifications for foreground messages
    // This prevents the messaging alert that appears on every login
  }

  /// Enable foreground messaging (call this only if you want to receive foreground notifications)
  Future<void> enableForegroundMessaging() async {
    try {
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      print('Foreground messaging enabled');
    } catch (e) {
      print('Error enabling foreground messaging: $e');
    }
  }

  /// Disable foreground messaging
  void disableForegroundMessaging() {
    _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
    print('Foreground messaging disabled');
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
      print('Starting door alerts listener...');
      
      // Track the last processed document to avoid processing existing alerts on startup
      String? lastProcessedId;
      
      _doorAlertsSubscription = FirebaseFirestore.instance
          .collection('door_alerts')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen(
        (QuerySnapshot snapshot) {
          print('Door alerts snapshot received: ${snapshot.docs.length} documents');
          if (snapshot.docs.isNotEmpty) {
            final latestDoc = snapshot.docs.first;
            final latestId = latestDoc.id;
            
            // Only process if this is a new document (not processed before)
            if (lastProcessedId == null) {
              // First time - just store the ID without processing
              lastProcessedId = latestId;
              print('Initial door alerts snapshot - storing latest ID: $latestId (no notification)');
            } else if (latestId != lastProcessedId) {
              // New document detected - process it
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

  /// Process door alert and send notification
  void _processDoorAlert(DocumentSnapshot document) {
    try {
      // Prevent notifications during initialization
      if (_isInitializing) {
        print('⚠️ Skipping door alert processing during initialization: ${document.id}');
        return;
      }
      
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
      final alertType = data['type'] ?? 'Intruder Alert';
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

      // Create a proper payload for navigation
      final payload = {
        'type': data?['type'] ?? 'Security Alert',
        'description': data?['description'] ?? 'Door activity detected',
        'location': data?['location'] ?? 'Main entrance',
        'timestamp': data?['timestamp']?.toDate()?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'alertId': alertId,
      };

      _localNotifications.show(
        alertId.hashCode, // Use hash as notification ID
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

  /// Set the navigator key for handling notification taps
  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    print('Navigator key set for notification service');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    
    // Handle navigation based on notification type
    if (response.payload != null) {
      try {
        // Parse the payload to extract alert data
        final payloadString = response.payload!;
        Map<String, dynamic>? alertData;
        
        // Try to parse the payload as a structured string
        if (payloadString.startsWith('{') && payloadString.endsWith('}')) {
          // Remove the curly braces and parse
          final cleanPayload = payloadString.substring(1, payloadString.length - 1);
          final pairs = cleanPayload.split(',');
          alertData = {};
          
          for (final pair in pairs) {
            final keyValue = pair.split(':');
            if (keyValue.length == 2) {
              final key = keyValue[0].trim().replaceAll('"', '').replaceAll("'", '');
              var value = keyValue[1].trim().replaceAll('"', '').replaceAll("'", '');
              
              // Handle timestamp conversion
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
          // Use default values if payload can't be parsed
          alertData = {
            'type': 'Security Alert',
            'description': 'Door activity detected',
            'location': 'Main entrance',
            'timestamp': DateTime.now(),
          };
        }
        
        print('Parsed alert data: $alertData');
        
        // Navigate to intruder alert screen if navigator key is available
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
        // Fallback: try to navigate with default data
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
      print('Creating test door alert...');
      final docRef = await FirebaseFirestore.instance
          .collection('door_alerts')
          .add({
        'type': 'Test Alert',
        'description': 'This is a test door alert',
        'location': 'Test Location',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid ?? 'test_user',
        'test': true, // Mark as test alert
      });
      print('Test door alert created in Firestore with ID: ${docRef.id}');
      print('This should trigger a notification if the listener is working properly');
    } catch (e) {
      print('Error creating test door alert: $e');
    }
  }

  /// Test the door alerts listener
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

  /// Get current notification service status
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