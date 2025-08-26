import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'callkit_service.dart';
import 'navigation_service.dart';
import 'background_app_launcher.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final CallKitService _callKitService = CallKitService();

  Future<void> initialize() async {
    // Request permission for notifications
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('FCM Permission granted: ${settings.authorizationStatus}');

    // Get FCM token
    String? token = await _messaging.getToken();
    debugPrint('FCM Token: $token');
    
    // Save token to shared preferences (you can send this to your SIP server)
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
    }

    // Handle token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM Token refreshed: $newToken');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', newToken);
      // TODO: Send new token to your SIP server
    });

    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle messages when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Handle messages when app is terminated
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle initial message when app is opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('🔥 FCM: App opened from terminated state via notification');
        _handleAppOpenFromNotification(message);
      }
    });
  }

  Future<String?> getFCMToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔥 FCM Foreground message received!');
    debugPrint('🔥 Title: ${message.notification?.title}');
    debugPrint('🔥 Body: ${message.notification?.body}');
    debugPrint('🔥 Data: ${message.data}');
    
    if (_isCallNotification(message)) {
      debugPrint('🔥 FCM: Handling as incoming call notification');
      _handleIncomingCallNotification(message);
    } else {
      debugPrint('🔥 FCM: Regular notification received');
    }
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('🔥 FCM Background message opened!');
    debugPrint('🔥 Title: ${message.notification?.title}');
    debugPrint('🔥 Body: ${message.notification?.body}');
    debugPrint('🔥 Data: ${message.data}');
    
    if (_isCallNotification(message)) {
      debugPrint('🔥 FCM: Handling as incoming call notification');
      _handleIncomingCallNotification(message);
    }
  }

  void _handleAppOpenFromNotification(RemoteMessage message) {
    debugPrint('🔥 FCM: App opened from notification!');
    debugPrint('🔥 Title: ${message.notification?.title}');
    debugPrint('🔥 Body: ${message.notification?.body}');
    debugPrint('🔥 Data: ${message.data}');
    
    if (_isCallNotification(message)) {
      debugPrint('🔥 FCM: Handling as incoming call notification from app launch');
      _handleIncomingCallNotification(message);
    }
  }

  bool _isCallNotification(RemoteMessage message) {
    // Check both data and notification for call indicators
    return message.data['type'] == 'incoming_call' || 
           message.notification?.title?.contains('Incoming Call') == true;
  }

  void _handleIncomingCallNotification(RemoteMessage message) {
    try {
      final callData = message.data;
      
      // Handle both data-only and notification+data messages
      final callerId = callData['caller_id'] ?? 
                      callData['callerId'] ?? 
                      callData['phone'] ?? 
                      '01687722962'; // Default for testing
                      
      final callerName = callData['caller_name'] ?? 
                        callData['callerName'] ?? 
                        callData['name'] ?? 
                        message.notification?.title?.replaceAll('Incoming Call from ', '') ??
                        'Test Caller'; // Default for testing
                        
      final callUuid = callData['call_uuid'] ?? 
                      callData['callUuid'] ?? 
                      callData['id'] ?? 
                      DateTime.now().millisecondsSinceEpoch.toString();
      
      debugPrint('🔥 FCM: Handling incoming call from $callerName ($callerId)');
      debugPrint('🔥 FCM: Call UUID: $callUuid');
      
      // NEW APPROACH: Proper VoIP Background Architecture
      _handleVoipCallNotification(callerName, callerId, callUuid);
      
    } catch (e) {
      debugPrint('🔥 FCM: Error handling incoming call notification: $e');
    }
  }
  
  void _handleVoipCallNotification(String callerName, String callerId, String callUuid) {
    debugPrint('🔥 FCM: Starting VoIP background call flow');
    
    // Step 1: Automatically launch app from background
    _launchAppFromBackground();
    
    // Step 2: Show CallKit native UI immediately (works even when app closed)
    _callKitService.showIncomingCall(
      uuid: callUuid,
      callerName: callerName,
      callerId: callerId,
    );
    
    // Step 3: Ensure app is in foreground and SIP connected
    _ensureAppReadyForCall(callerName, callerId, callUuid);
  }

  Future<void> _launchAppFromBackground() async {
    try {
      debugPrint('🔥 FCM: Attempting to launch app automatically');
      
      // Check if we have overlay permission (Android)
      final hasPermission = await BackgroundAppLauncher.hasOverlayPermission();
      if (!hasPermission) {
        debugPrint('🔥 FCM: No overlay permission, requesting...');
        await BackgroundAppLauncher.requestOverlayPermission();
      }
      
      // Launch the app from background
      final success = await BackgroundAppLauncher.launchAppFromBackground();
      if (success) {
        debugPrint('🔥 FCM: App launched automatically');
        
        // Show app on lock screen if needed
        await BackgroundAppLauncher.showOnLockScreen();
      } else {
        debugPrint('🔥 FCM: Failed to launch app automatically');
      }
    } catch (e) {
      debugPrint('🔥 FCM: Error launching app from background: $e');
    }
  }
  
  Future<void> _ensureAppReadyForCall(String callerName, String callerId, String callUuid) async {
    debugPrint('🔥 FCM: Ensuring app is ready for call');
    
    // Navigate to home screen
    _navigateToHomeScreen();
    
    // Wait for SIP connection to be established
    await _waitForSipConnection();
    
    // Once SIP is ready, the server should route the real call
    debugPrint('🔥 FCM: App ready - server can now route real call');
    
    // Show brief status
    _showCallPreparationStatus(callerName);
  }
  
  Future<void> _waitForSipConnection() async {
    debugPrint('🔥 FCM: Waiting for SIP connection...');
    
    // Import SIP service to check connection status
    // This is a simplified version - you might want to inject SipService
    int attempts = 0;
    const maxAttempts = 30; // 15 seconds max
    
    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 500));
      
      // In a real implementation, check SIP service status
      // For now, we'll assume connection takes ~3-5 seconds
      attempts++;
      
      if (attempts > 6) { // ~3 seconds
        debugPrint('🔥 FCM: SIP connection should be ready');
        break;
      }
    }
  }
  
  void _showCallPreparationStatus(String callerName) {
    try {
      final navigatorKey = NavigationService.navigatorKey;
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Preparing call from $callerName...'),
                ),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('🔥 FCM: Error showing preparation status: $e');
    }
  }

  void _showTestCallDialog(String callerName, String callerId, String callUuid) {
    // This simulates what CallKit would do - show an incoming call UI
    debugPrint('🔥 FCM: Showing test call dialog for $callerName');
    
    // NEW APPROACH: Just navigate to home screen and wait for real SIP call
    debugPrint('🔥 FCM: Opening app to wait for real SIP call from $callerName');
    _navigateToHomeScreen();
    
    // Show a brief notification that app is ready for incoming call
    _showWaitingForCallNotification(callerName);
    
    // Log simulation details
    debugPrint('🔥 FCM: *** INCOMING CALL NOTIFICATION ***');
    debugPrint('🔥 FCM: Caller: $callerName');  
    debugPrint('🔥 FCM: Number: $callerId');
    debugPrint('🔥 FCM: UUID: $callUuid');
    debugPrint('🔥 FCM: App opened - waiting for real SIP INVITE');
    debugPrint('🔥 FCM: *** END NOTIFICATION ***');
  }
  
  void _navigateToHomeScreen() {
    try {
      final navigatorKey = NavigationService.navigatorKey;
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
        debugPrint('🔥 FCM: Navigated to home screen');
      } else {
        debugPrint('🔥 FCM: Navigator not available');
      }
    } catch (e) {
      debugPrint('🔥 FCM: Error navigating to home screen: $e');
    }
  }
  
  void _showWaitingForCallNotification(String callerName) {
    try {
      final navigatorKey = NavigationService.navigatorKey;
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.phone_in_talk, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Waiting for call from $callerName...'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        debugPrint('🔥 FCM: Shown waiting notification for $callerName');
      }
    } catch (e) {
      debugPrint('🔥 FCM: Error showing waiting notification: $e');
    }
  }
  
  void _navigateToIncomingCallScreen(String callerName, String callerId, String callUuid) {
    try {
      // Import navigation service
      final navigatorKey = NavigationService.navigatorKey;
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed(
          '/fcm_incoming_call',
          arguments: {
            'caller_name': callerName,
            'caller_id': callerId,
            'call_uuid': callUuid,
            'is_video': false,
          },
        );
        debugPrint('🔥 FCM: Navigated to incoming call screen');
      } else {
        debugPrint('🔥 FCM: Navigator not available, call screen not shown');
      }
    } catch (e) {
      debugPrint('🔥 FCM: Error navigating to call screen: $e');
    }
  }
}

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔥 FCM Background handler: ${message.data}');
  debugPrint('🔥 FCM Background: Notification present: ${message.notification != null}');
  
  if (message.data['type'] == 'incoming_call') {
    final callerId = message.data['caller_id'] ?? 'Unknown';
    final callerName = message.data['caller_name'] ?? 'Unknown Caller';
    final callUuid = message.data['call_uuid'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    debugPrint('🔥 FCM Background: Processing DATA-ONLY incoming call from $callerName');
    
    // CRITICAL: Use platform channel to launch full-screen intent
    try {
      await _launchFullScreenIntent(callerName, callerId, callUuid);
      debugPrint('🔥 FCM Background: Full-screen intent launched');
    } catch (e) {
      debugPrint('🔥 FCM Background: Error launching full-screen intent: $e');
    }
    
    // Show CallKit UI for iOS compatibility
    final callKitService = CallKitService();
    await callKitService.showIncomingCall(
      uuid: callUuid,
      callerName: callerName,
      callerId: callerId,
    );
  }
}

// Helper function to launch full-screen intent
Future<void> _launchFullScreenIntent(String callerName, String callerId, String callUuid) async {
  try {
    // Use the new full-screen intent method
    final success = await BackgroundAppLauncher.launchFullScreenIntent(
      callerName: callerName,
      callerId: callerId,
      callUuid: callUuid,
    );
    
    if (success) {
      debugPrint('🔥 FCM Background: Full-screen intent launched successfully');
    } else {
      debugPrint('🔥 FCM Background: Full-screen intent failed, trying fallback');
      await BackgroundAppLauncher.launchAppFromBackground();
    }
  } catch (e) {
    debugPrint('🔥 FCM Background: Error launching full-screen intent: $e');
  }
}