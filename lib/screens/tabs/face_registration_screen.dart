import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/face_registration_service.dart';
import '../../services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isUploading = false;
  bool _isAdmin = false;
  bool _loadingAdminCheck = true;
  List<Map<String, dynamic>> _registeredFaces = [];
  bool _loadingFaces = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadRegisteredFaces();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final isAdmin = await UserService.isAdmin();
      setState(() {
        _isAdmin = isAdmin;
        _loadingAdminCheck = false;
      });
    } catch (e) {
      setState(() {
        _isAdmin = false;
        _loadingAdminCheck = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking admin status: $e')),
      );
    }
  }

  Future<void> _loadRegisteredFaces() async {
    if (!_isAdmin) return;
    
    setState(() {
      _loadingFaces = true;
    });

    try {
      final faces = await FaceRegistrationService.getRegisteredFaces();
      setState(() {
        _registeredFaces = faces;
        _loadingFaces = false;
      });
    } catch (e) {
      setState(() {
        _loadingFaces = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading registered faces: $e')),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _uploadFaceImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      await FaceRegistrationService.uploadFaceImage(_selectedImage!);
      
      setState(() {
        _isUploading = false;
        _selectedImage = null;
      });

      // Reload the faces list
      await _loadRegisteredFaces();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face image uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteFace(String faceId) async {
    try {
      await FaceRegistrationService.deleteFace(faceId);
      await _loadRegisteredFaces();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting face: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAdminCheck) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Face Registration'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Only administrators can register faces.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Registration'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRegisteredFaces,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Admin Face Registration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Select face images from gallery to register them for door access. Only admins can perform this operation.',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Image Selection Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Face Image',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    if (_selectedImage != null) ...[
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _pickImageFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Select from Gallery'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    
                    if (_selectedImage != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isUploading ? null : _uploadFaceImage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isUploading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Uploading...'),
                                  ],
                                )
                              : const Text('Upload to S3'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Registered Faces Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.face, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Registered Faces',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (_loadingFaces) ...[
                      const Center(child: CircularProgressIndicator()),
                    ] else if (_registeredFaces.isEmpty) ...[
                      const Center(
                        child: Column(
                          children: [
                            Icon(Icons.face_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'No faces registered yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ..._registeredFaces.map((face) => _buildFaceCard(face)).toList(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceCard(Map<String, dynamic> face) {
    final uploadedAt = face['uploadedAt'];
    final fileName = face['fileName'] ?? 'Unknown';
    final fileSize = face['fileSize'] ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.face),
        ),
        title: Text(fileName.split('/').last),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Size: ${(fileSize / 1024).toStringAsFixed(1)} KB'),
            if (uploadedAt != null)
              Text('Uploaded: ${_formatTimestamp(uploadedAt)}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _showDeleteConfirmation(face['id']),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String faceId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Face'),
        content: const Text('Are you sure you want to delete this registered face?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFace(faceId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'Unknown';
  }
} 