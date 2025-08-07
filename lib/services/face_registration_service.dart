import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';

class FaceRegistrationService {
  static const String _collectionName = 'registered_faces';

  /// Check if user is admin before allowing face registration
  static Future<bool> _isUserAdmin() async {
    try {
      return await UserService.isAdmin();
    } catch (e) {
      safePrint('Error checking admin status: $e');
      return false;
    }
  }

  /// Upload face image to S3 and store metadata in Firestore
  static Future<void> uploadFaceImage(File imageFile) async {
    try {
      // Check if user is admin
      final isAdmin = await _isUserAdmin();
      if (!isAdmin) {
        throw Exception('Only admins can register faces');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Validate image file
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'faces/${user.uid}/face_$timestamp.jpg';
      
      safePrint('Starting upload for file: $fileName');

      try {
        // Upload to S3 with proper error handling
        final uploadResult = await Amplify.Storage.uploadFile(
          localFile: AWSFile.fromPath(imageFile.path),
          path: StoragePath.fromString(fileName),
        ).result;
        
        safePrint('S3 upload successful: $fileName');
      } catch (e) {
        safePrint('S3 upload failed: $e');
        throw Exception('Failed to upload image to cloud storage: $e');
      }

      // Store metadata in Firestore
      final faceData = {
        'userId': user.uid,
        'userEmail': user.email,
        'fileName': fileName,
        's3Key': fileName,
        'uploadedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'uploadedBy': user.email,
        'fileSize': await imageFile.length(),
        'imagePath': imageFile.path,
      };

      await FirebaseFirestore.instance
          .collection(_collectionName)
          .add(faceData);

      safePrint('Face image metadata stored successfully: $fileName');
    } catch (e) {
      safePrint('Error uploading face image: $e');
      rethrow;
    }
  }

  /// Get all registered faces for a user
  static Future<List<Map<String, dynamic>>> getRegisteredFaces() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await FirebaseFirestore.instance
          .collection(_collectionName)
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('uploadedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      safePrint('Error getting registered faces: $e');
      rethrow;
    }
  }

  /// Delete a registered face
  static Future<void> deleteFace(String faceId) async {
    try {
      final isAdmin = await _isUserAdmin();
      if (!isAdmin) {
        throw Exception('Only admins can delete faces');
      }

      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(faceId)
          .update({'isActive': false});

      safePrint('Face deactivated successfully: $faceId');
    } catch (e) {
      safePrint('Error deleting face: $e');
      rethrow;
    }
  }
} 