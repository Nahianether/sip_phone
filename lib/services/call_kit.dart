import 'dart:developer';

import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart' show Event, CallEvent;
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

Future<void> showIncomming(String uid, String no) async {
  try {
    // this._currentUuid = _uuid.v4();
    CallKitParams callKitParams = CallKitParams(
      id: '_currentUuid',
      nameCaller: 'Hien Nguyen',
      appName: 'Callkit',
      avatar: 'https://i.pravatar.cc/100',
      handle: '0123456789',
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
        supportsVideo: true,
        maximumCallGroups: 2,
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
  } catch (e) {
    log(e.toString());
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
    switch (event.event) {
      case Event.actionCallIncoming:
        // TODO: received an incoming call
        break;
      case Event.actionCallStart:
        // TODO: started an outgoing call
        // TODO: show screen calling in Flutter
        break;
      case Event.actionCallAccept:
        // TODO: accepted an incoming call
        // TODO: show screen calling in Flutter
        break;
      case Event.actionCallDecline:
        // TODO: declined an incoming call
        break;
      case Event.actionCallEnded:
        // TODO: ended an incoming/outgoing call
        break;
      case Event.actionCallTimeout:
        // TODO: missed an incoming call
        break;
      case Event.actionCallCallback:
        // TODO: click action `Call back` from missed call notification
        break;
      case Event.actionCallToggleHold:
        // TODO: only iOS
        break;
      case Event.actionCallToggleMute:
        // TODO: only iOS
        break;
      case Event.actionCallToggleDmtf:
        // TODO: only iOS
        break;
      case Event.actionCallToggleGroup:
        // TODO: only iOS
        break;
      case Event.actionCallToggleAudioSession:
        // TODO: only iOS
        break;
      case Event.actionDidUpdateDevicePushTokenVoip:
        // TODO: only iOS
        break;
      case Event.actionCallCustom:
        // TODO: for custom action
        break;
      default:
        {}
    }
  });
}
