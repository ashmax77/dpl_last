import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _SmartLockHomeState createState() => _SmartLockHomeState();
}

class _SmartLockHomeState extends State<HomePage> {
  bool _isLocked = true;
  String? _username;
  String? _role;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    setState(() {
      _username = userDoc.data()?['username'] ?? 'Unknown';
      _role = userDoc.data()?['role'] ?? 'user';
    });
  }

  void updateLockStatus(bool lockStatus) async {
    try {
      setState(() {
        _isLocked = lockStatus;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User not logged in!")),
        );
        return;
      }

      // Fetch username and role from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final username = userDoc.data()?['username'] ?? 'Unknown';
      final role = userDoc.data()?['role'] ?? 'user';

      // Send to Firestore (lockEvents)
      await FirebaseFirestore.instance.collection('lockEvents').add({
        'locked': lockStatus,
        'timestamp': DateTime.now(),
        'username': username,
        'role': role,
      });
    } catch (e) {
      print("Firebase Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update lock status!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusBar(),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isLocked ? Icons.lock : Icons.lock_open,
                    size: 150,
                    color: _isLocked ? Colors.redAccent : Colors.green,
                  ),
                  SizedBox(height: 20),
                  Text(
                    _isLocked ? "Door is Locked" : "Door is Unlocked",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _isLocked ? Colors.redAccent : Colors.green,
                    ),
                  ),
                  if (_role == 'admin') ...[
                    SizedBox(height: 20),
                    Text(
                      "You are an admin",
                      style: TextStyle(fontSize: 16, color: Colors.blue),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isLocked ? null : () => updateLockStatus(true),
                      icon: Icon(Icons.lock),
                      label: Text('Lock'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        textStyle: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          !_isLocked ? null : () => updateLockStatus(false),
                      icon: Icon(Icons.lock_open),
                      label: Text('Unlock'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        textStyle: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Test door alert button (for testing notifications)
            if (_role == 'admin') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton.icon(
                  onPressed: () => _testDoorAlert(),
                  icon: const Icon(Icons.notification_add),
                  label: const Text('Test Door Alert'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _testDoorAlert() async {
    try {
      await FirebaseFirestore.instance.collection('door-alerts').add({
        'type': 'Test Alert',
        'description': 'This is a test door alert',
        'location': 'Main Entrance',
        'timestamp': FieldValue.serverTimestamp(),
        'severity': 'medium',
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test door alert created! Check notifications.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating test alert: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------- UI WIDGETS BELOW ----------

  Widget _buildStatusBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      // child: Row(
      //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //   children: [
      //     Row(
      //       children: [
      //         Icon(Icons.bluetooth,
      //             color: _isConnected ? Colors.blue : Colors.grey, size: 20),
      //         SizedBox(width: 6),
      //         Text(
      //           _isConnected ? "Connected" : "Disconnected",
      //           style: TextStyle(color: Colors.black),
      //         ),
      //       ],
      //     ),
      //     Row(
      //       children: [
      //         Icon(Icons.battery_full, size: 20, color: Colors.black),
      //         SizedBox(width: 6),
      //         Text(
      //           "${(_batteryLevel * 100).toInt()}%",
      //           style: TextStyle(color: Colors.black),
      //         ),
      //       ],
      //     ),
      //   ],
      // ),
    );
  }
}
