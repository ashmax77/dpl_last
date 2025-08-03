import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../../services/user_service.dart';
import '../admin_user_management_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'face_registration_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isAdmin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final isAdmin = await UserService.isAdmin();
      setState(() {
        _isAdmin = isAdmin;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _isAdmin = false;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        // Admin-only features
        if (_isAdmin) ...[
          const ListTile(
            leading: Icon(Icons.admin_panel_settings, color: Colors.red),
            title: Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ListTile(
            leading: const Icon(Icons.people),
            title: const Text('User Management'),
            subtitle: const Text('Manage all users'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminUserManagementScreen(),
                ),
              );
            },
          ),
          const Divider(),
        ],
        
        // General settings
        ListTile(
          leading: const Icon(Icons.account_circle),
          title: const Text('Edit Profile'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditProfileScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.lock),
          title: const Text('Change Password'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChangePasswordScreen(),
              ),
            );
          },
        ),
        const ListTile(
          leading: Icon(Icons.notifications),
          title: Text('Notification Settings'),
        ),
        ListTile(
          leading: const Icon(Icons.vpn_key),
          title: const Text('Generate Guest OTP'),
          onTap: () async {
            await _generateAndShowOTP(context);
          },
        ),
        if (_isAdmin) ...[
          ListTile(
            leading: const Icon(Icons.face),
            title: const Text('Face Registration'),
            subtitle: const Text('Register faces for door access (Admin Only)'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FaceRegistrationScreen(),
                ),
              );
            },
          ),
        ],
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Logout', style: TextStyle(color: Colors.red)),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Confirm Logout'),
                content: const Text('Are you sure you want to logout?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Logout'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              try {
                await UserService.logoutUser();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Logout error: $e')),
                );
              }
            }
          },
        ),
        const ListTile(
          leading: Icon(Icons.delete),
          title: Text('Delete Account'),
          textColor: Colors.red,
        ),
      ],
    );
  }

  Future<void> _generateAndShowOTP(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be logged in to generate OTP.')),
      );
      return;
    }
    final code = _generateOTP();
    final now = DateTime.now();
    final expiresAt = now.add(Duration(minutes: 10));
    final otpData = {
      'code': code,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'used': false,
      'ownerId': user.uid,
      'ownerEmail': user.email,
      'lockId': 'mainLock',
    };
    try {
      await FirebaseFirestore.instance.collection('otps').doc(code).set(otpData);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Guest OTP Generated'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Share this code with your guest:'),
              SizedBox(height: 16),
              SelectableText(
                code,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              SizedBox(height: 16),
              Text('Expires at: ${expiresAt.hour.toString().padLeft(2, '0')}:${expiresAt.minute.toString().padLeft(2, '0')}'),
            ],
          ),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate OTP: $e')),
      );
    }
  }

  String _generateOTP() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10).toString()).join();
  }
}
