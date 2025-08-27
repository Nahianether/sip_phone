import 'dart:async';
import 'dart:developer' show log;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:sip_phone/providers/connection.p.dart';
import 'package:sip_phone/services/call_kit.dart' show showIncomming;
import 'package:sip_ua/sip_ua.dart';
import '../models/sip_settings_model.dart';
import '../models/call_history_model.dart';
import '../providers/incoming.p.dart' show tempCall;
import '../utils/phone_utils.dart';
import 'storage_service.dart';
import 'navigation_service.dart';
import 'notification_service.dart';

class SipService extends SipUaHelperListener {
  static final SipService _instance = SipService._internal();
  factory SipService() => _instance;
  SipService._internal();

  // SIPUAHelper? _helper;
  RegistrationState _registrationState = RegistrationState(state: RegistrationStateEnum.NONE);
  // bool _connected = false;
  bool _handlingIncomingCall = false; // Prevent multiple simultaneous calls

  // Navigation service
  final NavigationService _navigationService = NavigationService();

  // Notification service
  final NotificationService _notificationService = NotificationService();

  final StreamController<RegistrationState> _registrationStateController =
      StreamController<RegistrationState>.broadcast();
  final StreamController<Call> _callStateController = StreamController<Call>.broadcast();
  final StreamController<String> _reconnectStatusController = StreamController<String>.broadcast();

  Stream<RegistrationState> get registrationStream {
    // Emit current state immediately for new subscribers
    Future.microtask(() {
      if (!_registrationStateController.isClosed) {
        _registrationStateController.add(_registrationState);
      }
    });
    return _registrationStateController.stream;
  }

  Stream<Call> get callStream => _callStateController.stream;
  // Stream<String> get reconnectStatusStream {
  //   // Emit initial status for new subscribers
  //   Future.microtask(() {
  //     if (!_reconnectStatusController.isClosed) {
  //       _reconnectStatusController.add(_connected ? 'Connected' : 'Disconnected');
  //     }
  //   });
  //   return _reconnectStatusController.stream;
  // }

  RegistrationState get registrationState => _registrationState;
  /*
  Future<bool> connect(
    WidgetRef ref, {
    required String username,
    required String password,
    required String server,
    required String wsUrl,
    String? displayName,
    bool isSave = true,
  }) async {
    final helper_ = ref.read(sipHelpersProvider);
    final helperNotifier = ref.read(sipHelpersProvider.notifier);
    log('Connecting --------------------------$username');
    try {
      // Parameter validation
      if (username.isEmpty || password.isEmpty || server.isEmpty || wsUrl.isEmpty) {
        _reconnectStatusController.add('Invalid connection parameters');
        return false;
      }

      // Validate WebSocket URL format
      if (!wsUrl.startsWith('ws://') && !wsUrl.startsWith('wss://')) {
        _reconnectStatusController.add('Invalid WebSocket URL format');
        return false;
      }

      // Graceful disconnect of existing connection
      if (helper_ != null) {
        try {
          helperNotifier.stop();
          _reconnectStatusController.add('Disconnecting previous session...');
        } catch (e) {
          debugPrint('Error during cleanup: $e');
        }
        helperNotifier.set(null);
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      helperNotifier.set(SIPUAHelper());

      final UaSettings settings = UaSettings();
      settings.webSocketUrl = wsUrl;
      settings.uri = 'sip:$username@$server';
      settings.authorizationUser = username;
      settings.password = password;
      settings.displayName = displayName?.isNotEmpty == true ? displayName : username;
      settings.userAgent = 'SIP Phone Flutter v1.0';
      settings.dtmfMode = DtmfMode.RFC2833;
      settings.transportType = TransportType.WS;

      // Basic settings
      settings.register = true;
      settings.sessionTimers = true;
      settings.iceGatheringTimeout = 60000;
      settings.register_expires = 300;

      // WebRTC configuration
      settings.iceServers = [
        {'url': 'stun:stun.l.google.com:19302'},
        {'url': 'stun:stun1.l.google.com:19302'},
        {'url': 'stun:stun2.l.google.com:19302'},
      ];

      // Final validation
      if (settings.webSocketUrl == null || settings.uri == null || settings.transportType == null) {
        _reconnectStatusController.add('Invalid SIP settings configuration');
        return false;
      }

      helperNotifier.addService(this);

      try {
        await helperNotifier.start(settings);
        _reconnectStatusController.add('Initializing SIP connection...');
      } catch (startError) {
        _reconnectStatusController.add('Failed to start SIP connection: $startError');
        helperNotifier.set(null);
        return false;
      }

      if (isSave) {
        await saveCredentials(username, password, server, wsUrl, displayName);
      }

      return true;
    } catch (e) {
      _reconnectStatusController.add('Connection error: ${e.toString()}');
      helperNotifier.set(null);
      return false;
    }
  }
*/
  Future<void> disconnect(WidgetRef ref) async {
    final helper_ = ref.read(sipHelpersProvider);
    final helperNotifier = ref.read(sipHelpersProvider.notifier);
    if (helper_ != null) {
      try {
        helperNotifier.stop();
      } catch (e) {
        // Ignore errors during disconnect
      }
      helperNotifier.set(null);
    }
    ref.read(serverConnectionProvider.notifier).set(false);
    _registrationState = RegistrationState(state: RegistrationStateEnum.NONE);
    _registrationStateController.add(_registrationState);
    _reconnectStatusController.add('Disconnected');
  }

  Future<bool> makeCall(String target, WidgetRef ref) async {
    final connected_ = await ref.read(serverConnectionProvider.future);
    final helper_ = ref.read(sipHelpersProvider);
    final helperNotifier = ref.read(sipHelpersProvider.notifier);
    if (helper_ == null) {
      _reconnectStatusController.add('SIP service not initialized');
      return false;
    }

    if (!connected_) {
      _reconnectStatusController.add('Not connected to SIP server');
      return false;
    }

    try {
      debugPrint('🔥 DEBUG: makeCall called - target: $target, connected: $connected_');
      _reconnectStatusController.add('Initiating call to $target...');

      // Enhanced call options for better compatibility
      final mediaConstraints = {'audio': true, 'video': false};

      final callOptions = {
        'mediaConstraints': mediaConstraints,
        'rtcOfferConstraints': {'offerToReceiveAudio': true, 'offerToReceiveVideo': false},
        'rtcAnswerConstraints': {'offerToReceiveAudio': true, 'offerToReceiveVideo': false},
        'rtcConfiguration': {
          'iceServers': [
            {'urls': 'stun:stun.l.google.com:19302'},
            {'urls': 'stun:stun1.l.google.com:19302'},
          ],
          'iceCandidatePoolSize': 10,
        },
      };

      final success = await helperNotifier.call(target, true, callOptions);

      if (success) {
        _reconnectStatusController.add('Call initiated to $target');
      } else {
        _reconnectStatusController.add('Failed to initiate call to $target');
      }

      return success;
    } catch (e) {
      _reconnectStatusController.add('Call error: $e');
      return false;
    }
  }

  void hangup(Call call) {
    // Stop notification alerts when call is hung up
    _notificationService.stopIncomingCallAlert();
    call.hangup();
  }

  void answer(Call call) {
    try {
      debugPrint('🔥 DEBUG: Attempting to answer call - Call ID: ${call.id}');

      // Stop notification alerts when call is answered
      _notificationService.stopIncomingCallAlert();

      // Simple answer call with minimal options
      final answerOptions = {
        'mediaConstraints': {'audio': true, 'video': false},
      };

      call.answer(answerOptions);
      _reconnectStatusController.add('Call answered');
      debugPrint('🔥 DEBUG: Call.answer() method called successfully');
    } catch (e) {
      debugPrint('🔥 DEBUG: Error in answer() method: $e');
      _reconnectStatusController.add('Error answering call: $e');
    }
  }

  void hold(Call call) {
    call.hold();
  }

  void unhold(Call call) {
    call.unhold();
  }

  void sendDTMF(Call call, String tone) {
    call.sendDTMF(tone);
  }

  Future<Map<String, String?>> getSavedCredentials() async {
    final settings = StorageService.getSipSettings();
    return {
      'username': settings?.username,
      'password': settings?.password,
      'server': settings?.server,
      'wsUrl': settings?.wsUrl,
      'displayName': settings?.displayName,
    };
  }

  // Get saved settings model
  SipSettingsModel? getSavedSettings() {
    return StorageService.getSipSettings();
  }

  Future<void> _trackCallHistory(Call call, CallType type, {int duration = 0}) async {
    final phoneNumber = call.remote_identity?.toString() ?? '';
    if (phoneNumber.isEmpty) return;

    final sanitized = PhoneUtils.sanitizePhoneNumber(phoneNumber);
    final callHistory = CallHistoryModel(
      id: '${DateTime.now().millisecondsSinceEpoch}_${call.id}',
      phoneNumber: sanitized,
      contactName: null, // Will be populated by UI layer if contact exists
      type: type,
      timestamp: DateTime.now(),
      duration: duration,
    );

    await StorageService.addCallHistory(callHistory);
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    debugPrint('🔥 DEBUG: registrationStateChanged called - State: ${state.state}');
    _registrationState = state;
    //! _connected = state.state == RegistrationStateEnum.REGISTERED;
    _registrationStateController.add(state);

    //! if (_connected) {
    //   _reconnectStatusController.add('Successfully registered to SIP server');
    //   debugPrint('✅ SIP Registration successful');
    // } else {
    //   debugPrint('❌ SIP Registration lost - State: ${state.state}');
    // }

    if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      log('❌ REGISTRATION FAILED: ${state.cause ?? 'Unknown reason'}');
      _reconnectStatusController.add('Registration failed');
    }

    if (state.state == RegistrationStateEnum.UNREGISTERED) {
      log('❌ CONNECTION LOST: SIP connection unregistered');
      _reconnectStatusController.add('Connection lost');
    }
  }

  @override
  void transportStateChanged(TransportState state) {
    debugPrint('🔥 DEBUG: transportStateChanged called - State: ${state.state}');

    if (state.state == TransportStateEnum.DISCONNECTED) {
      log('❌ TRANSPORT DISCONNECTED: WebSocket transport disconnected');
      _reconnectStatusController.add('Transport disconnected');
    } else if (state.state == TransportStateEnum.CONNECTED) {
      log('✅ TRANSPORT CONNECTED: WebSocket transport connected');
      _reconnectStatusController.add('Transport connected successfully');
    }
  }

  @override
  void callStateChanged(Call call, CallState callState) async {
    debugPrint('🔥 DEBUG: callStateChanged called - State: ${callState.state}, Direction: ${call.direction}');
    _callStateController.add(call);

    String statusMessage = '';
    switch (callState.state) {
      case CallStateEnum.CALL_INITIATION:
        statusMessage = 'Call initiating to ${call.remote_identity}';
        // Handle both incoming and outgoing calls
        if (call.direction.toLowerCase() == 'outgoing') {
          // Track outgoing call
          _trackCallHistory(call, CallType.outgoing);
          Future.delayed(Duration(milliseconds: 100), () {
            // Direct navigation using Navigator instead of NavigationService
            final context = NavigationService.navigatorKey.currentContext;
            if (context != null && context.mounted) {
              Navigator.pushNamed(context, '/active_call', arguments: call);
              debugPrint('🔥 DEBUG: Direct navigation to /active_call successful');
            } else {
              debugPrint('🔥 DEBUG: No context available for navigation');
            }
          });
        } else if (call.direction.toLowerCase() == 'incoming' && !_handlingIncomingCall) {
          tempCall = call;
          _handlingIncomingCall = true; // Prevent multiple simultaneous calls

          // Track incoming call
          _trackCallHistory(call, CallType.incoming);
          debugPrint('🔥 DEBUG: Incoming call from ${call.remote_identity}');

          try {
            // Show CallKit with proper error handling
            await showIncomming(
              call.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
              call.remote_identity ?? 'Unknown',
            );
            debugPrint('🔥 DEBUG: CallKit shown successfully');
          } catch (callKitError) {
            debugPrint('🔥 DEBUG: CallKit error (non-fatal): $callKitError');
            // Continue with in-app handling even if CallKit fails
          }

          // Always show in-app screen as backup
          _handleIncomingCall(call);
        } else if (call.direction.toLowerCase() == 'incoming' && _handlingIncomingCall) {
          debugPrint('🔥 DEBUG: Already handling incoming call, ignoring duplicate');
        }
        break;
      case CallStateEnum.CONNECTING:
        statusMessage = 'Connecting call to ${call.remote_identity}';
        // Don't trigger additional navigation for incoming calls in CONNECTING state
        // The initial CALL_INITIATION should have already handled this
        break;
      case CallStateEnum.PROGRESS:
        statusMessage = 'Call in progress to ${call.remote_identity}';
        break;
      case CallStateEnum.ACCEPTED:
        statusMessage = 'Call accepted by ${call.remote_identity}';
        break;
      case CallStateEnum.CONFIRMED:
        statusMessage = 'Call connected to ${call.remote_identity}';
        // Navigate to active call screen for confirmed calls if not already there
        Future.delayed(Duration(milliseconds: 100), () {
          final context = NavigationService.navigatorKey.currentContext;
          if (context != null && context.mounted) {
            // For incoming calls, replace the incoming call screen with active call screen
            // For outgoing calls, navigate normally (might already be on active call screen)
            if (call.direction.toLowerCase() == 'incoming') {
              Navigator.pushReplacementNamed(context, '/active_call', arguments: call);
              debugPrint('🔥 DEBUG: CONFIRMED incoming call - replaced with active call screen');
            } else {
              Navigator.pushNamed(context, '/active_call', arguments: call);
              debugPrint('🔥 DEBUG: CONFIRMED outgoing call - navigated to active call screen');
            }
          } else {
            debugPrint('🔥 DEBUG: CONFIRMED - No context available for navigation');
          }
        });
        break;
      case CallStateEnum.ENDED:
        statusMessage = 'Call ended with ${call.remote_identity}';
        _handlingIncomingCall = false; // Reset flag when call ends
        // Navigate back to home when call ends
        Future.delayed(Duration(milliseconds: 500), () {
          _navigationService.navigateToAndClearStack('/home');
        });
        break;
      case CallStateEnum.FAILED:
        statusMessage = 'Call failed to ${call.remote_identity}';
        _handlingIncomingCall = false; // Reset flag when call fails
        // Track as missed call if it was incoming and failed
        if (call.direction.toLowerCase() == 'incoming') {
          _trackCallHistory(call, CallType.missed);
        }
        // Navigate back to home when call fails
        Future.delayed(Duration(milliseconds: 500), () {
          _navigationService.navigateToAndClearStack('/home');
        });
        break;
      case CallStateEnum.MUTED:
        statusMessage = 'Call muted';
        break;
      case CallStateEnum.UNMUTED:
        statusMessage = 'Call unmuted';
        break;
      case CallStateEnum.HOLD:
        statusMessage = 'Call on hold';
        break;
      case CallStateEnum.UNHOLD:
        statusMessage = 'Call resumed';
        break;
      case CallStateEnum.REFER:
        statusMessage = 'Call transfer initiated';
        break;
      case CallStateEnum.STREAM:
        statusMessage = 'Media stream established';
        break;
      default:
        statusMessage = 'Call state: ${callState.state}';
    }

    _reconnectStatusController.add(statusMessage);
    debugPrint('SIP: $statusMessage - Direction: ${call.direction}');
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    // Handle new SIP messages
  }

  // Handle incoming calls when they arrive
  void _handleIncomingCall(Call call) {
    _callStateController.add(call);
    _reconnectStatusController.add('Incoming call from ${call.remote_identity}');
    debugPrint('SIP: Incoming call from ${call.remote_identity}');

    // Start vibration and ringtone
    _notificationService.startIncomingCallAlert();

    // Delay navigation to avoid conflicts with CallKit
    Future.delayed(Duration(milliseconds: 500), () {
      try {
        final context = NavigationService.navigatorKey.currentContext;
        if (context != null && context.mounted) {
          Navigator.pushNamed(context, '/incoming_call', arguments: call);
          debugPrint('🔥 DEBUG: Incoming call navigation successful');
        } else {
          debugPrint('🔥 DEBUG: Incoming call - No context available for navigation');
        }
      } catch (navError) {
        debugPrint('🔥 DEBUG: Navigation error: $navError');
        // Don't crash the app if navigation fails
      }
    });
  }

  @override
  void onNewNotify(Notify notify) {
    // Handle notifications
  }

  @override
  void onNewReinvite(ReInvite event) {
    // Handle re-invite requests
  }

  void dispose() {
    _registrationStateController.close();
    _callStateController.close();
    _reconnectStatusController.close();
  }
}

Future<void> saveCredentials(String username, String password, String server, String wsUrl, String? displayName) async {
  final settings = SipSettingsModel(
    username: username,
    password: password,
    server: server,
    wsUrl: wsUrl,
    displayName: displayName,
    autoConnect: true,
  );
  await StorageService.saveSipSettings(settings);
}
