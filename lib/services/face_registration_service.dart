import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FaceRegistrationService {
  static const String _collectionName = 'registered_faces';

  /// Upload face image to S3 and store metadata in Firestore
  static Future<void> uploadFaceImage(File imageFile) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'faces/${user.uid}/face_$timestamp.jpg';
      
      // Upload to S3
      final key = DateTime.now().millisecondsSinceEpoch.toString() + '.jpg';

      try {
        final result = await Amplify.Storage.uploadFile(
          localFile: AWSFile.fromPath(imageFile.path),
          path: StoragePath.fromString(key),
        ).result;
        print('Uploaded: $key');
      } catch (e) {
        print('Failed to upload: $e');
        rethrow;
      }

      // Store metadata in Firestore
      final faceData = {
        'userId': user.uid,
        'userEmail': user.email,
        'fileName': fileName,
        's3Key': fileName,
        'uploadedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await FirebaseFirestore.instance
          .collection(_collectionName)
          .add(faceData);

      safePrint('Face image uploaded successfully: $fileName');
    } catch (e) {
      safePrint('Error uploading face image: $e');
      rethrow;
    }
  }
} 