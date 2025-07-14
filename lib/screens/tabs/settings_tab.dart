import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: Icon(Icons.account_circle),
          title: Text('Edit Profile'),
          onTap: () {
            // Add edit profile functionality
          },
        ),
        ListTile(
          leading: Icon(Icons.lock),
          title: Text('Change Password'),
          onTap: () {
            // Add change password functionality
          },
        ),
        ListTile(
          leading: Icon(Icons.notifications),
          title: Text('Notification Settings'),
          onTap: () {
            // Add notification settings
          },
        ),
        ListTile(
          leading: Icon(Icons.vpn_key),
          title: Text('Generate Guest OTP'),
          onTap: () async {
            await _generateAndShowOTP(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.delete),
          title: Text('Delete Account'),
          textColor: Colors.red,
          onTap: () {
            // Add delete account functionality
          },
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
