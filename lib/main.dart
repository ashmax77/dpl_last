import 'package:dlp_last/screens/home_screen.dart';
import 'package:dlp_last/screens/login_screen.dart';
import 'package:dlp_last/screens/admin_user_management_screen.dart';
import 'package:dlp_last/screens/intruder_alert_screen.dart';
import 'package:dlp_last/services/auth_wrapper.dart';
import 'package:dlp_last/services/firebase_notify.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/register_screen.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'amplifyconfiguration.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('Handling a background message: ${message.messageId}');
  print('Message data: ${message.data}');
  print('Message notification: ${message.notification?.title}');
  print('⚠️ Background message received - NO automatic notifications shown');
  // Do not show any notifications here - only process the message data
}

Future<void> _configureAmplifyPlugins() async {
  try {
    await Amplify.addPlugins([
      AmplifyAuthCognito(),
      AmplifyStorageS3(),
    ]);
    await Amplify.configure(amplifyconfig);
  } catch (e) {
    print('Amplify configuration failed: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set background message handler BEFORE Firebase initialization
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  await _configureAmplifyPlugins();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await notificationService.initialize();
  runApp(MyApp());
}
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Set the navigator key for the notification service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notificationService.setNavigatorKey(_navigatorKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Role-Based App',
      navigatorKey: _navigatorKey,
      home: const AuthWrapper(),
      routes: {
        '/register': (context) => RegisterScreen(),
        '/admin/users': (context) => AdminUserManagementScreen(),
        '/intruder-alert': (context) => IntruderAlertScreen(),
      },
    );
  }
}
