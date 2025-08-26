import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // Request all required permissions
  Future<bool> requestAllPermissions(BuildContext context) async {
    final permissions = [
      Permission.microphone,
      Permission.contacts,
      Permission.notification,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    bool allGranted = true;
    List<String> deniedPermissions = [];

    for (var entry in statuses.entries) {
      if (entry.value != PermissionStatus.granted) {
        allGranted = false;
        deniedPermissions.add(_getPermissionName(entry.key));
      }
    }

    if (!allGranted && context.mounted) {
      await _showPermissionDialog(context, deniedPermissions);
    }

    return allGranted;
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
    if (await Permission.contacts.isGranted) {
      return true;
    }
    if (context.mounted) {
      return await requestPermission(Permission.contacts, context);
    }
    return false;
  }

  String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.microphone:
        return 'Microphone';
      case Permission.contacts:
        return 'Contacts';
      case Permission.notification:
        return 'Notifications';
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
}