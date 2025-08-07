# Notification System & Face Registration Setup Guide

## 🔧 Fixed Issues

### 1. Face Registration (Admin Only)
- ✅ **Fixed**: S3 storage configuration in Amplify
- ✅ **Added**: Admin validation before upload
- ✅ **Added**: Better error handling and file validation
- ✅ **Added**: Face management (view/delete registered faces)
- ✅ **Added**: File size and metadata tracking

### 2. Notification System
- ✅ **Fixed**: Proper notification channel creation
- ✅ **Added**: Background message handling
- ✅ **Added**: Foreground and background message processing
- ✅ **Added**: Door alerts monitoring from Firestore
- ✅ **Added**: Duplicate notification prevention
- ✅ **Added**: Test notification functionality

## 🚀 Setup Instructions

### Prerequisites
1. **Firebase Project**: Ensure your Firebase project is configured
2. **AWS Amplify**: Configure S3 storage for face images
3. **Firebase Cloud Messaging**: Enable FCM in Firebase console

### 1. Firebase Configuration

#### Enable Firebase Cloud Messaging:
1. Go to Firebase Console → Your Project
2. Navigate to **Project Settings** → **Cloud Messaging**
3. Generate a new **Server Key** (if not already done)
4. Enable **Cloud Messaging API** in Google Cloud Console

#### Update Firebase Rules:
```javascript
// Firestore Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Door alerts collection
    match /door-alerts/{document} {
      allow read, write: if request.auth != null;
    }
    
    // Registered faces collection
    match /registered_faces/{document} {
      allow read, write: if request.auth != null && 
        (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin' ||
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.firstUser == true);
    }
  }
}
```

### 2. AWS Amplify S3 Configuration

#### Update Amplify Configuration:
The `amplifyconfiguration.dart` file has been updated with S3 storage configuration:

```dart
const amplifyconfig = '''{
    "UserAgent": "aws-amplify-cli/2.0",
    "Version": "1.0",
    "auth": {
        "plugins": {
            "awsCognitoAuthPlugin": {
                "UserAgent": "aws-amplify-cli/0.1.0",
                "Version": "0.1.0",
                "IdentityManager": {
                    "Default": {}
                }
            }
        }
    },
    "storage": {
        "plugins": {
            "awsS3StoragePlugin": {
                "bucket": "dlp-last-storage",
                "region": "us-east-1"
            }
        }
    }
}''';
```

#### Create S3 Bucket:
1. Go to AWS S3 Console
2. Create a new bucket named `dlp-last-storage` (or update the name in config)
3. Configure bucket permissions for Amplify access
4. Enable CORS if needed for web access

### 3. Android Configuration

#### Update AndroidManifest.xml:
Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Existing permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    
    <!-- Notification permissions -->
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    
    <application>
        <!-- Existing application configuration -->
        
        <!-- Firebase messaging service -->
        <service
            android:name="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT"/>
            </intent-filter>
        </service>
        
        <!-- Default notification icon -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@mipmap/ic_launcher" />
            
        <!-- Default notification color -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_color"
            android:resource="@color/notification_color" />
    </application>
</manifest>
```

#### Add Notification Color:
Create `android/app/src/main/res/values/colors.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="notification_color">#E53935</color>
</resources>
```

### 4. iOS Configuration (if applicable)

#### Update Info.plist:
Add to `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## 🧪 Testing the Fixes

### 1. Test Face Registration:
1. Login as an admin user
2. Go to **Settings** → **Face Registration**
3. Select an image from gallery
4. Upload to S3
5. Verify the face appears in the registered faces list

### 2. Test Notifications:
1. Login as an admin user
2. Go to **Settings** → **Test Notification**
3. Tap to send a test notification
4. Verify notification appears

### 3. Test Door Alerts:
1. Login as an admin user
2. Go to **Home** tab
3. Tap **"Test Door Alert"** button
4. Verify notification appears for door alert

### 4. Test Background Notifications:
1. Send a test notification
2. Put app in background
3. Send another notification
4. Verify it appears even when app is backgrounded

## 🔍 Troubleshooting

### Face Registration Issues:
- **S3 Upload Failed**: Check AWS credentials and bucket permissions
- **Admin Access Denied**: Verify user has admin role in Firestore
- **Image Not Loading**: Check file permissions and image format

### Notification Issues:
- **No Notifications**: Check notification permissions in device settings
- **Background Not Working**: Verify background message handler is registered
- **FCM Token Issues**: Check Firebase project configuration

### Common Solutions:
1. **Clear app data** and reinstall
2. **Check device notification settings**
3. **Verify Firebase project configuration**
4. **Check AWS S3 bucket permissions**
5. **Ensure all dependencies are up to date**

## 📱 Features Added

### Face Registration:
- ✅ Admin-only access control
- ✅ S3 image upload with metadata
- ✅ Face management (view/delete)
- ✅ File validation and error handling
- ✅ Progress indicators

### Notification System:
- ✅ Firebase Cloud Messaging integration
- ✅ Local notifications for door alerts
- ✅ Background message handling
- ✅ Notification channels (Android)
- ✅ Duplicate prevention
- ✅ Test notification functionality
- ✅ Real-time door alert monitoring

## 🎯 Next Steps

1. **Configure Firebase Cloud Functions** for server-side notifications
2. **Add push notification scheduling**
3. **Implement notification preferences**
4. **Add notification history**
5. **Configure notification sounds and vibrations**

---

**Note**: Make sure to test thoroughly on both Android and iOS devices, and verify all permissions are granted by the user. 