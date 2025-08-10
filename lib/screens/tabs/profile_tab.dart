import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/user_service.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Center(child: Text('No user logged in'));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('No user data found'));
        }

        Map<String, dynamic> userData = 
            snapshot.data!.data() as Map<String, dynamic>;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileItem(
                        'Username',
                        userData['username'] ?? 'Not set',
                        Icons.person_outline,
                      ),
                      const Divider(),
                      _buildProfileItem(
                        'Email',
                        userData['email'] ?? 'Not set',
                        Icons.email_outlined,
                      ),
                      const Divider(),
                      _buildProfileItem(
                        'User ID',
                        userData['userId'] ?? 'Not set',
                        Icons.badge_outlined,
                      ),
                      const Divider(),
                      _buildProfileItem(
                        'Role',
                        _getRoleDisplay(userData['role'], userData['firstUser']),
                        Icons.admin_panel_settings_outlined,
                      ),
                      const Divider(),
                      _buildProfileItem(
                        'Status',
                        userData['isOnline'] == true ? 'Online' : 'Offline',
                        Icons.circle,
                        valueColor: userData['isOnline'] == true ? Colors.green : Colors.grey,
                      ),
                      const Divider(),
                      _buildProfileItem(
                        'Joined',
                        _formatTimestamp(userData['createdAt']),
                        Icons.calendar_today_outlined,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await UserService.logoutUser();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Logout error: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileItem(String label, String value, IconData icon, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.blue),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleDisplay(String? role, bool? firstUser) {
    if (firstUser == true) {
      return 'Admin (First User)';
    } else if (role == 'admin') {
      return 'Admin';
    } else {
      return 'User';
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Not set';
    if (timestamp is Timestamp) {
      DateTime dateTime = timestamp.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    return 'Invalid date';
  }
}