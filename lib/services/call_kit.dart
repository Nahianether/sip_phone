import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart' show Event, CallEvent;
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:sip_phone/providers/incoming.p.dart';
import 'package:sip_ua/sip_ua.dart';
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
        showNotification: false,
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
  FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
    if (event == null) return;
    log('CallKit Event: -- ${event.event} - ${event.body}');
    String? callId = event.body['id'] ?? '';
    callId = callId?.split('@').first;
    // print('---- $callId');

    switch (event.event) {
      case Event.actionCallIncoming:
        log('CallKit:-- Received incoming call');
        break;
      case Event.actionCallStart:
        await stopNotification(callId ?? '');
        log('CallKit:-- Started outgoing call');
        break;
      case Event.actionCallAccept:
        log('CallKit: Accepted incoming call -- navigating to in-app call screen');

        await _navigateToIncomingCallScreen(event);
        await Future.delayed(const Duration(seconds: 3));
        await answer();
        await stopNotification(callId ?? '');

        break;
      case Event.actionCallDecline:
        await stopNotification(callId ?? '');
        await FlutterCallkitIncoming.endAllCalls();
        log('CallKit:--- Declined incoming call');
        tempCall = null;
        break;
      case Event.actionCallEnded:
        log('CallKit:--- Call ended');
        await FlutterCallkitIncoming.endAllCalls();
        await stopNotification(callId ?? '');
        tempCall = null;
        _navigateToHome();
        break;
      case Event.actionCallTimeout:
        await stopNotification(callId ?? '');
        await FlutterCallkitIncoming.endAllCalls();
        tempCall = null;
        log('CallKit:-- Call timeout');
        break;
      case Event.actionCallCallback:
        log('CallKit:-- Call callback clicked');
        break;
      case Event.actionCallToggleHold:
        await stopNotification(callId ?? '');
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
        log('CallKit:------ Unknown event ${event.event}');
    }
  });
}

Future<void> _navigateToIncomingCallScreen(CallEvent event) async {
  try {
    log('CallKit: Navigating to Flutter incoming call screen');
    final navigationService = NavigationService();
    final context = navigationService.currentContext;

    // Ensure app is brought to foreground properly
    await _bringAppToForeground();

    if (context != null && context.mounted) {
      // Check if tempCall exists and is in a valid state to be answered
      if (tempCall == null) {
        log('_navigateToIncomingCallScreen--------------- Temp Call Null');
        navigationService.navigateToAndClearStack('/home');
        return;
      }

      // Check call state before attempting to answer
      final callState = tempCall!.state;
      log('CallKit: Current call state: $callState');

      // Only attempt to answer if call is in CALL_INITIATION, PROGRESS, or CONNECTING state
      if (callState == CallStateEnum.CALL_INITIATION ||
          callState == CallStateEnum.PROGRESS ||
          callState == CallStateEnum.CONNECTING) {
        await answer();
        log('CallKit: ------Call answered successfully');
        // Use NavigationService to properly bring app to foreground
        navigationService.navigateToAndClearStack('/active_call', arguments: tempCall);
      } else if (callState == CallStateEnum.CONFIRMED || callState == CallStateEnum.ACCEPTED) {
        log('CallKit: Call already answered, navigating to active call');
        // Use NavigationService to properly bring app to foreground
        navigationService.navigateToAndClearStack('/active_call', arguments: tempCall);
      } else {
        log('CallKit: Call in invalid state for answering: $callState, navigating to home');
        navigationService.navigateToAndClearStack('/home');
      }

      log('CallKit: Navigation successful');
    } else {
      log('CallKit:Context not found ---------- No context available for navigation');
    }
  } catch (e) {
    log('CallKit:----------- Navigation/Answer error - $e');
    // Fallback navigation to home on any error
    try {
      final navigationService = NavigationService();
      navigationService.navigateToAndClearStack('/home');
    } catch (navError) {
      log('CallKit: Fallback navigation error - $navError');
    }
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

Future<void> stopNotification(String id) async {
  CallKitParams params = CallKitParams(id: id);
  await FlutterCallkitIncoming.hideCallkitIncoming(params);
}

Future<void> _bringAppToForeground() async {
  // This method ensures the app is properly brought to foreground
  // without creating multiple instances
  try {
    log('CallKit: Bringing app to foreground');

    // Check current app lifecycle state
    final binding = WidgetsBinding.instance;
    log('CallKit: Current app lifecycle state: ${binding.lifecycleState}');

    // If app is in background, it will automatically come to foreground
    // when CallKit triggers the action. We just need to ensure proper
    // navigation state management.

    // Wait a moment for the app to initialize if needed
    if (NavigationService.navigatorKey.currentContext == null) {
      log('CallKit: Waiting for app to initialize...');
      await Future.delayed(Duration(milliseconds: 1000));
    }

    final context = NavigationService.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      log('CallKit: App is ready for navigation');

      // Trigger a frame callback to ensure UI is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        log('CallKit: UI frame ready for navigation');
      });
    } else {
      log('CallKit: Warning - Navigation context still not available');
    }
  } catch (e) {
    log('CallKit: Error in foreground management: $e');
  }
}
