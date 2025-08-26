import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BackgroundAppLauncher {
  static const MethodChannel _channel = MethodChannel('background_app_launcher');
  
  static final BackgroundAppLauncher _instance = BackgroundAppLauncher._internal();
  factory BackgroundAppLauncher() => _instance;
  BackgroundAppLauncher._internal();

  /// Launch the app automatically from background
  static Future<bool> launchAppFromBackground() async {
    try {
      debugPrint('🔥 Background Launcher: Attempting to launch app from background');
      
      if (Platform.isAndroid) {
        // Use Android-specific method to bring app to foreground
        final result = await _channel.invokeMethod('launchAppFromBackground');
        debugPrint('🔥 Background Launcher: Android launch result: $result');
        return result ?? false;
      } else if (Platform.isIOS) {
        // iOS handles this through CallKit integration
        debugPrint('🔥 Background Launcher: iOS - app should launch via CallKit');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('🔥 Background Launcher: Error launching app: $e');
      return false;
    }
  }

  /// Request system alert window permission (Android)
  static Future<bool> requestOverlayPermission() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('requestOverlayPermission');
        debugPrint('🔥 Background Launcher: Overlay permission result: $result');
        return result ?? false;
      }
      return true; // iOS doesn't need this
    } catch (e) {
      debugPrint('🔥 Background Launcher: Error requesting overlay permission: $e');
      return false;
    }
  }

  /// Check if the app has overlay permission
  static Future<bool> hasOverlayPermission() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('hasOverlayPermission');
        return result ?? false;
      }
      return true; // iOS doesn't need this
    } catch (e) {
      debugPrint('🔥 Background Launcher: Error checking overlay permission: $e');
      return false;
    }
  }

  /// Show the app on lock screen for incoming calls
  static Future<bool> showOnLockScreen() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('showOnLockScreen');
        debugPrint('🔥 Background Launcher: Show on lock screen result: $result');
        return result ?? false;
      }
      return true; // iOS handles this via CallKit
    } catch (e) {
      debugPrint('🔥 Background Launcher: Error showing on lock screen: $e');
      return false;
    }
  }

  /// Launch full-screen intent for incoming calls (bypasses notification tap requirement)
  static Future<bool> launchFullScreenIntent({
    required String callerName,
    required String callerId,
    String? callUuid,
  }) async {
    try {
      debugPrint('🔥 Background Launcher: Launching full-screen intent for $callerName');
      
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('launchFullScreenIntent', {
          'caller_name': callerName,
          'caller_id': callerId,
          'call_uuid': callUuid ?? DateTime.now().millisecondsSinceEpoch.toString(),
        });
        debugPrint('🔥 Background Launcher: Full-screen intent result: $result');
        return result ?? false;
      }
      
      return true; // iOS uses CallKit which handles this automatically
    } catch (e) {
      debugPrint('🔥 Background Launcher: Error launching full-screen intent: $e');
      return false;
    }
  }
}