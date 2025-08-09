import 'package:flutter/material.dart';

class IntruderAlertScreen extends StatelessWidget {
  final Map<String, dynamic>? alertData;
  
  const IntruderAlertScreen({super.key, this.alertData});

  @override
  Widget build(BuildContext context) {
    // Get alert data from route arguments if not passed directly
    final Map<String, dynamic>? data = alertData ?? 
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?);
    
    // Extract alert information from the data
    final alertType = data?['type'] ?? 'Security Alert';
    final description = data?['description'] ?? 'Door activity detected';
    final location = data?['location'] ?? 'Main entrance';
    final timestamp = data?['timestamp'] is DateTime 
        ? data!['timestamp'] as DateTime
        : DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Alert'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Warning Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Alert Title
              Text(
                '🚨 INTRUDER ALERT 🚨',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[800],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Alert Type
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Text(
                  alertType,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[800],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Description
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Description:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Location
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Location:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      location,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Timestamp
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Time Detected:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')} - ${timestamp.day}/${timestamp.month}/${timestamp.year}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Acknowledge'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // You can add emergency contact functionality here
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Emergency contacts will be notified'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                      icon: const Icon(Icons.emergency),
                      label: const Text('Emergency'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
