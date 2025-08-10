import 'package:flutter/material.dart';
import '../services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_schedule_management_screen.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _onlineUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadOnlineUsers();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final users = await UserService.getAllUsers();
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadOnlineUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isOnline', isEqualTo: true)
          .get();
      setState(() {
        _onlineUsers = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
      });
    } catch (e) {
      print("Error loading online users: $e");
    }
  }

  Future<void> _deleteUser(String userId, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete user "$username"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await UserService.deleteUser(userId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User "$username" deleted successfully')),
        );
        _loadUsers(); 
        _loadOnlineUsers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting user: $e')),
        );
      }
    }
  }

  Future<void> _updateUserRole(String userId, String currentRole, String username) async {
    final newRole = currentRole == 'admin' ? 'user' : 'admin';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Role Change'),
        content: Text('Change role of "$username" from $currentRole to $newRole?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Change'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await UserService.updateUserRole(userId, newRole);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role updated successfully')),
        );
        _loadUsers();
        _loadOnlineUsers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating role: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadUsers();
              _loadOnlineUsers();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          _loadUsers();
                          _loadOnlineUsers();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_onlineUsers.isNotEmpty)
                      Card(
                        margin: const EdgeInsets.all(16),
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Currently Online Users',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._onlineUsers.map((user) => ListTile(
                                    leading: const Icon(Icons.circle, color: Colors.green, size: 16),
                                    title: Text(user['username'] ?? 'Unknown'),
                                    subtitle: Text(user['email'] ?? ''),
                                    trailing: user['deviceId'] != null
                                        ? Text('Device: ${user['deviceId']}')
                                        : null,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: _users.isEmpty
                          ? const Center(
                              child: Text('No users found'),
                            )
                          : ListView.builder(
                              itemCount: _users.length,
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                final isCurrentUser = user['id'] == UserService.currentUser?.uid;
                                final isOnline = user['isOnline'] ?? false;
                                final role = user['role'] ?? 'user';
                                final isFirstUser = user['firstUser'] ?? false;

                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isOnline ? Colors.green : Colors.grey,
                                      child: Icon(
                                        isOnline ? Icons.person : Icons.person_off,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(user['username'] ?? 'Unknown'),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(user['email'] ?? ''),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: role == 'admin' ? Colors.red : Colors.blue,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                role,
                                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                              ),
                                            ),
                                            if (isFirstUser) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  'FIRST',
                                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: isCurrentUser
                                        ? const Text('Current User', style: TextStyle(color: Colors.grey))
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  role == 'admin' ? Icons.person : Icons.admin_panel_settings,
                                                  color: role == 'admin' ? Colors.red : Colors.blue,
                                                ),
                                                onPressed: () => _updateUserRole(
                                                  user['id'],
                                                  role,
                                                  user['username'],
                                                ),
                                                tooltip: 'Change role',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.schedule, color: Colors.deepPurple),
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => UserScheduleManagementScreen(userId: user['id'], username: user['username'] ?? ''),
                                                    ),
                                                  );
                                                },
                                                tooltip: 'Manage Schedules',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                onPressed: () => _deleteUser(
                                                  user['id'],
                                                  user['username'],
                                                ),
                                                tooltip: 'Delete user',
                                              ),
                                            ],
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
} 