import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
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
}
