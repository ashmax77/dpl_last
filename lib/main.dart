import 'package:dlp_last/screens/home_screen.dart';
import 'package:dlp_last/screens/login_screen.dart';
import 'package:dlp_last/screens/admin_user_management_screen.dart';
import 'package:dlp_last/services/auth_wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Role-Based App',
      home: const AuthWrapper(),
      routes: {
        '/register': (context) => RegisterScreen(),
        '/admin/users': (context) => AdminUserManagementScreen(),
      },
    );
  }
}
