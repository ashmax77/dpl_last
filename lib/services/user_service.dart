import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Check if user is admin
  static Future<bool> isAdmin() async {
    final user = currentUser;
    if (user == null) return false;
    
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    
    final isFirstUser = data?['firstUser'] ?? false;
    final role = data?['role'] ?? 'user';
    final isAdmin = isFirstUser || role == 'admin';
    
    print('Admin check: email=${user.email}, role=$role, firstUser=$isFirstUser, isAdmin=$isAdmin');
    
    // Admin is either the first user OR has admin role
    return isAdmin;
  }

  // Check if user is first user (admin)
  static Future<bool> isFirstUser() async {
    final users = await _firestore.collection('users').get();
    return users.docs.isEmpty;
  }

  // Get user role
  static Future<String> getUserRole() async {
    final user = currentUser;
    if (user == null) return 'user';
    
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    final role = data?['role'] ?? 'user';
    final isFirstUser = data?['firstUser'] ?? false;
    
    print('User role check: role=$role, firstUser=$isFirstUser, email=${user.email}');
    return role;
  }

  // Check if user is online on another device
  static Future<bool> isUserOnlineOnAnotherDevice() async {
    final user = currentUser;
    if (user == null) return false;
    
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    final isOnline = data?['isOnline'] ?? false;
    final lastLoginAt = data?['lastLoginAt'];
    
    if (!isOnline) return false;
    
    // Check if last login was more than 5 minutes ago (session expired)
    if (lastLoginAt != null) {
      final lastLogin = lastLoginAt.toDate();
      final now = DateTime.now();
      final difference = now.difference(lastLogin);
      
      if (difference.inMinutes > 5) {
        // Session expired, allow login
        await _firestore.collection('users').doc(user.uid).update({
          'isOnline': false,
        });
        return false;
      }
    }
    
    return true;
  }

  // Register new user
  static Future<void> registerUser({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      // Check if this is the first user
      final isFirst = await isFirstUser();
      final role = isFirst ? 'admin' : 'user';
      final firstUser = isFirst;

      // Create user in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user data to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'username': username,
        'email': email,
        'role': role,
        'firstUser': firstUser,
        'createdAt': FieldValue.serverTimestamp(),
        'isOnline': false,
        'lastLoginAt': null,
        'deviceId': null,
      });

      print("User registered: $email, role: $role, firstUser: $firstUser");
    } catch (e) {
      print("Registration error: $e");
      throw e;
    }
  }

  // Login user
  static Future<void> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      // Authenticate with Firebase
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if user is already online on another device
      final isOnlineElsewhere = await isUserOnlineOnAnotherDevice();
      if (isOnlineElsewhere) {
        await _auth.signOut();
        throw Exception('User is already logged in on another device');
      }

      // Get user data
      final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      final userData = userDoc.data();
      final isAdmin = userData?['firstUser'] == true || userData?['role'] == 'admin';

      // If not admin, check schedule
      if (!isAdmin) {
        final now = DateTime.now();
        final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final today = weekDays[now.weekday - 1];
        final schedulesSnapshot = await _firestore
            .collection('User-schedule')
            .where('userId', isEqualTo: userCredential.user!.uid)
            .where('isActive', isEqualTo: true)
            .get();
        bool allowed = false;
        List<String> allowedTimes = [];
        for (final doc in schedulesSnapshot.docs) {
          final data = doc.data();
          final List days = data['days'] ?? [];
          if (!days.contains(today)) continue;
          final startParts = (data['startTime'] as String).split(':');
          final endParts = (data['endTime'] as String).split(':');
          final start = TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1]));
          final end = TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1]));
          allowedTimes.add('${_formatTime(start)} - ${_formatTime(end)}');
          final nowTime = TimeOfDay(hour: now.hour, minute: now.minute);
          if (_isTimeInRange(nowTime, start, end)) {
            allowed = true;
            break;
          }
        }
        if (!allowed) {
          await _auth.signOut();
          String timesMsg = allowedTimes.isNotEmpty
              ? '\nYour access times today: ${allowedTimes.join(', ')}'
              : '\n(No access scheduled for today)';
          throw Exception('You can only log in during your scheduled access time.' + timesMsg);
        }
      }

      // Update user status
      await _firestore.collection('users').doc(userCredential.user!.uid).update({
        'isOnline': true,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'deviceId': DateTime.now().millisecondsSinceEpoch.toString(), // Simple device ID
      });

    } catch (e) {
      print("Login error: $e");
      throw e;
    }
  }

  static bool _isTimeInRange(TimeOfDay now, TimeOfDay start, TimeOfDay end) {
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (startMinutes <= endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    } else {
      // Overnight schedule (e.g., 22:00-06:00)
      return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
    }
  }

  static String _formatTime(TimeOfDay t) {
    return t.hour.toString().padLeft(2, '0') + ':' + t.minute.toString().padLeft(2, '0');
  }

  // Logout user
  static Future<void> logoutUser() async {
    try {
      final user = currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'isOnline': false,
          'deviceId': null,
        });
      }
      await _auth.signOut();
    } catch (e) {
      print("Logout error: $e");
      throw e;
    }
  }

  // Get all users (admin only)
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    if (!await isAdmin()) {
      throw Exception('Only admins can view all users');
    }

    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
  }

  // Delete user (admin only)
  static Future<void> deleteUser(String userId) async {
    if (!await isAdmin()) {
      throw Exception('Only admins can delete users');
    }

    // Don't allow admin to delete themselves
    if (userId == currentUser?.uid) {
      throw Exception('Admin cannot delete their own account');
    }

    await _firestore.collection('users').doc(userId).delete();
  }

  // Update user role (admin only)
  static Future<void> updateUserRole(String userId, String newRole) async {
    if (!await isAdmin()) {
      throw Exception('Only admins can update user roles');
    }

    if (newRole != 'admin' && newRole != 'user') {
      throw Exception('Invalid role');
    }

    await _firestore.collection('users').doc(userId).update({
      'role': newRole,
    });
  }

  // Get user data
  static Future<Map<String, dynamic>?> getUserData() async {
    final user = currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  // Stream user data changes
  static Stream<Map<String, dynamic>?> getUserDataStream() {
    final user = currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.data());
  }
} 