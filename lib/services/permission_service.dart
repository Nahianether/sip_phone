import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // Request all required permissions (platform-aware)
  Future<bool> requestAllPermissions(BuildContext context) async {
    try {
      List<Permission> requiredPermissions = [];
      
      // Core permissions for both platforms
      requiredPermissions.add(Permission.microphone);
      requiredPermissions.add(Permission.contacts);
      
      // Platform-specific permissions
      if (Platform.isAndroid) {
        // Android-specific permissions
        requiredPermissions.addAll([
          Permission.notification,
          Permission.phone,
          Permission.storage, // For call logs
        ]);
      } else if (Platform.isIOS) {
        // iOS-specific permissions
        requiredPermissions.addAll([
          Permission.notification,
          // Add audio permission for VoIP calls on iOS
          // Note: Permission.audio might not be available, we'll handle it in iOS natively
        ]);
      }

      Map<Permission, PermissionStatus> statuses = {};
      List<String> deniedPermissions = [];

      // Request permissions sequentially to ensure proper iOS native dialogs
      for (Permission permission in requiredPermissions) {
        try {
          final status = await permission.request();
          statuses[permission] = status;
          
          if (status != PermissionStatus.granted) {
            deniedPermissions.add(_getPermissionName(permission));
            debugPrint('${_getPermissionName(permission)} permission denied');
          } else {
            debugPrint('${_getPermissionName(permission)} permission granted');
          }
        } catch (e) {
          debugPrint('Error requesting ${_getPermissionName(permission)}: $e');
          statuses[permission] = PermissionStatus.denied;
          deniedPermissions.add(_getPermissionName(permission));
        }
      }

      // Check critical permissions (microphone is essential for VoIP)
      bool microphoneGranted = statuses[Permission.microphone] == PermissionStatus.granted;
      bool notificationGranted = statuses[Permission.notification] == PermissionStatus.granted;
      
      // Show dialog only if critical permissions are denied
      bool criticalPermissionsDenied = !microphoneGranted || !notificationGranted;
      
      if (criticalPermissionsDenied && context.mounted && deniedPermissions.isNotEmpty) {
        await _showPermissionDialog(context, deniedPermissions);
      }

      // Log permission status for debugging
      debugPrint('Permission Status Summary:');
      debugPrint('- Microphone: ${microphoneGranted ? "✓" : "✗"}');
      debugPrint('- Notifications: ${notificationGranted ? "✓" : "✗"}');
      debugPrint('- Platform: ${Platform.operatingSystem}');

      // Return true if at least microphone permission is granted (minimum for VoIP)
      return microphoneGranted;
      
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  // Request specific permission
  Future<bool> requestPermission(Permission permission, BuildContext context) async {
    final status = await permission.request();
    
    if (status != PermissionStatus.granted) {
      if (context.mounted) {
        await _showSinglePermissionDialog(context, _getPermissionName(permission));
      }
      return false;
    }
    
    return status == PermissionStatus.granted;
  }

  // Check if permission is granted
  Future<bool> isPermissionGranted(Permission permission) async {
    return await permission.isGranted;
  }

  // Check microphone permission specifically
  Future<bool> checkMicrophonePermission(BuildContext context) async {
    if (await Permission.microphone.isGranted) {
      return true;
    }
    if (context.mounted) {
      return await requestPermission(Permission.microphone, context);
    }
    return false;
  }

  // Check contacts permission specifically
  Future<bool> checkContactsPermission(BuildContext context) async {
    try {
      // First check if permission is already granted
      if (await Permission.contacts.isGranted) {
        debugPrint('✅ Contacts permission already granted');
        return true;
      }
      
      // Request permission if not granted
      debugPrint('📱 Requesting contacts permission...');
      if (context.mounted) {
        final status = await Permission.contacts.request();
        
        if (status == PermissionStatus.granted) {
          debugPrint('✅ Contacts permission granted');
          return true;
        } else if (status == PermissionStatus.permanentlyDenied) {
          debugPrint('❌ Contacts permission permanently denied');
          if (context.mounted) {
            await _showPermanentlyDeniedDialog(context, 'Contacts');
          }
        } else {
          debugPrint('⚠️ Contacts permission denied: $status');
          // Don't show dialog for simple denials, let the UI handle it
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking contacts permission: $e');
      return false;
    }
  }

  // Check if all critical permissions are granted (microphone + notifications)
  Future<bool> areEssentialPermissionsGranted() async {
    final microphoneGranted = await Permission.microphone.isGranted;
    final notificationGranted = await Permission.notification.isGranted;
    
    debugPrint('Essential Permissions Check:');
    debugPrint('- Microphone: ${microphoneGranted ? "✓" : "✗"}');
    debugPrint('- Notifications: ${notificationGranted ? "✓" : "✗"}');
    
    return microphoneGranted && notificationGranted;
  }

  // Get current permission status for all permissions
  Future<Map<String, bool>> getPermissionStatus() async {
    Map<String, bool> status = {};
    
    status['microphone'] = await Permission.microphone.isGranted;
    status['contacts'] = await Permission.contacts.isGranted;
    status['notification'] = await Permission.notification.isGranted;
    
    if (Platform.isAndroid) {
      status['phone'] = await Permission.phone.isGranted;
      status['storage'] = await Permission.storage.isGranted;
    }
    
    return status;
  }

  // Force request contacts permission (useful for triggering from UI)
  Future<bool> forceRequestContactsPermission(BuildContext context) async {
    try {
      debugPrint('Force requesting contacts permission...');
      final status = await Permission.contacts.request();
      
      debugPrint('Contacts permission status: $status');
      
      if (status == PermissionStatus.granted) {
        debugPrint('✅ Contacts permission granted');
        return true;
      } else if (status == PermissionStatus.permanentlyDenied) {
        debugPrint('❌ Contacts permission permanently denied');
        if (context.mounted) {
          await _showPermanentlyDeniedDialog(context, 'Contacts');
        }
      } else {
        debugPrint('❌ Contacts permission denied: $status');
        if (context.mounted) {
          await _showSinglePermissionDialog(context, 'Contacts');
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Error force requesting contacts permission: $e');
      return false;
    }
  }

  String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.microphone:
        return 'Microphone';
      case Permission.contacts:
        return 'Contacts';
      case Permission.notification:
        return 'Notifications';
      case Permission.phone:
        return 'Phone';
      case Permission.storage:
        return 'Storage';
      default:
        return permission.toString();
    }
  }

  Future<void> _showPermissionDialog(BuildContext context, List<String> deniedPermissions) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permissions Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This app needs the following permissions to work properly:'),
              const SizedBox(height: 12),
              ...deniedPermissions.map((permission) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(permission),
                  ],
                ),
              )),
              const SizedBox(height: 12),
              const Text(
                'Please grant these permissions in the app settings.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Later'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSinglePermissionDialog(BuildContext context, String permissionName) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$permissionName Permission Required'),
          content: Text('This feature requires $permissionName permission. Please grant permission in settings.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPermanentlyDeniedDialog(BuildContext context, String permissionName) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$permissionName Permission Denied'),
          content: Text('$permissionName permission was permanently denied. Please enable it in Settings > Privacy & Security > $permissionName to use this feature.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }
}