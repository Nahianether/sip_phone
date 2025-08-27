import 'dart:developer';

import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart' show Event, CallEvent;
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'navigation_service.dart';

Future<void> showIncomming(String uid, String no) async {
  try {
    log('CallKit: Attempting to show incoming call - ID: $uid, Number: $no');
    
    // Validate parameters
    if (uid.isEmpty || no.isEmpty) {
      log('CallKit: Invalid parameters - using defaults');
      uid = DateTime.now().millisecondsSinceEpoch.toString();
      no = 'Unknown';
    }
    
    CallKitParams callKitParams = CallKitParams(
      id: uid,
      nameCaller: no,
      appName: 'SIP Phone',
      avatar: 'https://i.pravatar.cc/100',
      handle: no,
      type: 0,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      callingNotification: NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Calling... $no',
        callbackText: 'Hang Up',
      ),
      duration: 30000,
      extra: <String, dynamic>{'userId': uid, 'no': no},
      headers: <String, dynamic>{'apiKey': 'Abc@123!', 'platform': 'flutter'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        logoUrl: 'https://i.pravatar.cc/100',
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        backgroundUrl: 'https://i.pravatar.cc/500',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: "Incoming Call",
        missedCallNotificationChannelName: "Missed Call",
        isShowCallID: false,
      ),
      ios: IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: false, // Changed to false to reduce complexity
        maximumCallGroups: 1, // Reduced from 2 to 1
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );
    
    await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
    log('CallKit: Successfully shown incoming call interface');
  } catch (e) {
    log('CallKit: Error showing incoming call - $e');
    // Re-throw the error so calling code can handle it
    throw Exception('CallKit failed: $e');
  }
}

Future<void> init_() async {
  try {
    await FlutterCallkitIncoming.requestNotificationPermission({
      "title": "Notification permission",
      "rationaleMessagePermission": "Notification permission is required, to show notification.",
      "postNotificationMessageRequired":
          "Notification permission is required, Please allow notification permission from setting.",
    });

    // Check if can use full screen intent
    await FlutterCallkitIncoming.canUseFullScreenIntent();

    // Request full intent permission
    await FlutterCallkitIncoming.requestFullIntentPermission();
  } catch (e) {
    log(e.toString());
  }
}

void listenCallkit() {
  FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
    if (event == null) return;
    log('CallKit Event: ${event.event} - ${event.body}');
    
    switch (event.event) {
      case Event.actionCallIncoming:
        log('CallKit: Received incoming call');
        break;
      case Event.actionCallStart:
        log('CallKit: Started outgoing call');
        break;
      case Event.actionCallAccept:
        log('CallKit: Accepted incoming call - navigating to in-app call screen');
        // Navigate to incoming call screen in app when CallKit call is accepted
        _navigateToIncomingCallScreen(event);
        break;
      case Event.actionCallDecline:
        log('CallKit: Declined incoming call');
        break;
      case Event.actionCallEnded:
        log('CallKit: Call ended');
        // Navigate back to home when CallKit call ends
        _navigateToHome();
        break;
      case Event.actionCallTimeout:
        log('CallKit: Call timeout');
        break;
      case Event.actionCallCallback:
        log('CallKit: Call callback clicked');
        break;
      case Event.actionCallToggleHold:
        log('CallKit: Toggle hold');
        break;
      case Event.actionCallToggleMute:
        log('CallKit: Toggle mute');
        break;
      case Event.actionCallToggleDmtf:
        log('CallKit: Toggle DTMF');
        break;
      case Event.actionCallToggleGroup:
        log('CallKit: Toggle group');
        break;
      case Event.actionCallToggleAudioSession:
        log('CallKit: Toggle audio session');
        break;
      case Event.actionDidUpdateDevicePushTokenVoip:
        log('CallKit: VoIP token updated');
        break;
      case Event.actionCallCustom:
        log('CallKit: Custom action');
        break;
      default:
        log('CallKit: Unknown event ${event.event}');
    }
  });
}

void _navigateToIncomingCallScreen(CallEvent event) {
  try {
    log('CallKit: Navigating to Flutter incoming call screen');
    final navigationService = NavigationService();
    final context = navigationService.currentContext;
    
    if (context != null && context.mounted) {
      // For now, navigate to home since we don't have the actual Call object
      // In a full implementation, you'd need to store the call reference
      navigationService.navigateToAndClearStack('/home');
      log('CallKit: Navigation to home successful');
    } else {
      log('CallKit: No context available for navigation');
    }
  } catch (e) {
    log('CallKit: Navigation error - $e');
  }
}

void _navigateToHome() {
  try {
    log('CallKit: Navigating to home screen');
    final navigationService = NavigationService();
    final context = navigationService.currentContext;
    
    if (context != null && context.mounted) {
      navigationService.navigateToAndClearStack('/home');
      log('CallKit: Navigation to home successful');
    } else {
      log('CallKit: No context available for home navigation');
    }
  } catch (e) {
    log('CallKit: Home navigation error - $e');
  }
}
