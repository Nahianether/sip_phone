import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'navigation_service.dart';

class SipService extends SipUaHelperListener {
  static final SipService _instance = SipService._internal();
  factory SipService() => _instance;
  SipService._internal();

  SIPUAHelper? _helper;
  RegistrationState _registrationState = RegistrationState(state: RegistrationStateEnum.NONE);
  bool _connected = false;
  bool _autoReconnectEnabled = true;
  bool _isReconnecting = false;

  // Connection credentials for reconnection
  String? _lastUsername;
  String? _lastPassword;
  String? _lastServer;
  String? _lastWsUrl;
  String? _lastDisplayName;

  // Reconnection parameters
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  final List<int> _reconnectDelays = [2, 5, 10, 20, 30]; // seconds
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  // Navigation service
  final NavigationService _navigationService = NavigationService();

  final StreamController<RegistrationState> _registrationStateController =
      StreamController<RegistrationState>.broadcast();
  final StreamController<Call> _callStateController = StreamController<Call>.broadcast();
  final StreamController<String> _reconnectStatusController = StreamController<String>.broadcast();

  Stream<RegistrationState> get registrationStream => _registrationStateController.stream;
  Stream<Call> get callStream => _callStateController.stream;
  Stream<String> get reconnectStatusStream => _reconnectStatusController.stream;

  RegistrationState get registrationState => _registrationState;
  bool get connected => _connected;
  bool get isReconnecting => _isReconnecting;

  Future<bool> connect({
    required String username,
    required String password,
    required String server,
    required String wsUrl,
    String? displayName,
    bool saveCredentials = true,
  }) async {
    try {
      // Validate input parameters
      if (username.isEmpty || password.isEmpty || server.isEmpty || wsUrl.isEmpty) {
        _reconnectStatusController.add('Invalid connection parameters');
        return false;
      }

      // Store credentials for reconnection
      _lastUsername = username;
      _lastPassword = password;
      _lastServer = server;
      _lastWsUrl = wsUrl;
      _lastDisplayName = displayName ?? username;

      // Disconnect existing connection if any
      if (_helper != null) {
        try {
          _helper!.stop();
        } catch (e) {
          // Ignore errors during cleanup
        }
        _helper = null;
        await Future.delayed(const Duration(milliseconds: 500)); // Allow cleanup
      }

      _helper = SIPUAHelper();

      final UaSettings settings = UaSettings();
      settings.webSocketUrl = wsUrl;
      settings.uri = 'sip:$username@$server';
      settings.authorizationUser = username;
      settings.password = password;
      settings.displayName = displayName?.isNotEmpty == true ? displayName : username;
      settings.userAgent = 'SIP Phone Flutter';
      settings.dtmfMode = DtmfMode.RFC2833;

      // Set the transport type - this was missing!
      settings.transportType = TransportType.WS;

      // Additional settings for stability
      settings.register = true;
      settings.sessionTimers = true;
      settings.iceGatheringTimeout = 30000;

      // WebRTC audio configuration
      settings.iceServers = [
        {'url': 'stun:stun.l.google.com:19302'},
        {'url': 'stun:stun1.l.google.com:19302'},
      ];

      // Validate critical settings before starting
      if (settings.webSocketUrl == null || settings.uri == null || settings.transportType == null) {
        _reconnectStatusController.add('Invalid SIP settings configuration');
        return false;
      }

      _helper!.addSipUaHelperListener(this);

      // Add null check and error handling for start
      try {
        _helper!.start(settings);
        _reconnectStatusController.add('Connecting to SIP server...');
      } catch (startError) {
        _reconnectStatusController.add('Failed to start SIP connection: $startError');
        _helper = null;
        return false;
      }

      if (saveCredentials) {
        await _saveCredentials(username, password, server, wsUrl, displayName);
      }

      // Reset reconnection attempts on successful connection
      _reconnectAttempts = 0;
      _cancelReconnectTimer();
      _isReconnecting = false;

      return true;
    } catch (e) {
      _reconnectStatusController.add('Connection error: $e');
      _helper = null;

      if (_autoReconnectEnabled && !_isReconnecting) {
        _scheduleReconnect();
      }
      return false;
    }
  }

  Future<void> _attemptReconnect() async {
    if (_lastUsername == null || _lastPassword == null || _lastServer == null || _lastWsUrl == null) {
      return;
    }

    _reconnectAttempts++;
    _reconnectStatusController.add('Reconnecting... ($_reconnectAttempts/$_maxReconnectAttempts)');

    final success = await connect(
      username: _lastUsername!,
      password: _lastPassword!,
      server: _lastServer!,
      wsUrl: _lastWsUrl!,
      displayName: _lastDisplayName,
      saveCredentials: false,
    );

    if (success) {
      _isReconnecting = false;
      _reconnectStatusController.add('Reconnected successfully');
    } else if (_reconnectAttempts >= _maxReconnectAttempts) {
      _isReconnecting = false;
      _reconnectStatusController.add('Failed to reconnect after $_maxReconnectAttempts attempts');
    } else {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_autoReconnectEnabled || _isReconnecting) return;

    _isReconnecting = true;
    final delayIndex = (_reconnectAttempts < _reconnectDelays.length)
        ? _reconnectAttempts
        : _reconnectDelays.length - 1;
    final delay = _reconnectDelays[delayIndex];

    _reconnectStatusController.add('Reconnecting in $delay seconds...');

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      _attemptReconnect();
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void enableAutoReconnect(bool enabled) {
    _autoReconnectEnabled = enabled;
    if (!enabled) {
      _cancelReconnectTimer();
      _isReconnecting = false;
    }
  }

  Future<void> disconnect() async {
    _cancelReconnectTimer();
    _isReconnecting = false;

    if (_helper != null) {
      try {
        _helper!.stop();
      } catch (e) {
        // Ignore errors during disconnect
      }
      _helper = null;
    }
    _connected = false;
    _registrationState = RegistrationState(state: RegistrationStateEnum.NONE);
    _registrationStateController.add(_registrationState);
    _reconnectStatusController.add('Disconnected');
  }

  Future<bool> makeCall(String target) async {
    if (_helper == null) {
      _reconnectStatusController.add('SIP service not initialized');
      return false;
    }

    if (!_connected) {
      _reconnectStatusController.add('Not connected to SIP server');
      return false;
    }

    try {
      print('🔥 DEBUG: makeCall called - target: $target, connected: $_connected');
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

      final success = await _helper!.call(target, voiceOnly: true, customOptions: callOptions);

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
    call.hangup();
  }

  void answer(Call call) {
    try {
      print('🔥 DEBUG: Attempting to answer call - Call ID: ${call.id}');
      
      // Simple answer call with minimal options
      final answerOptions = {
        'mediaConstraints': {
          'audio': true,
          'video': false,
        },
      };
      
      call.answer(answerOptions);
      _reconnectStatusController.add('Call answered');
      print('🔥 DEBUG: Call.answer() method called successfully');
    } catch (e) {
      print('🔥 DEBUG: Error in answer() method: $e');
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

  Future<void> _saveCredentials(
    String username,
    String password,
    String server,
    String wsUrl,
    String? displayName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sip_username', username);
    await prefs.setString('sip_password', password);
    await prefs.setString('sip_server', server);
    await prefs.setString('sip_ws_url', wsUrl);
    if (displayName != null) {
      await prefs.setString('sip_display_name', displayName);
    }
  }

  Future<Map<String, String?>> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'username': prefs.getString('sip_username'),
      'password': prefs.getString('sip_password'),
      'server': prefs.getString('sip_server'),
      'wsUrl': prefs.getString('sip_ws_url'),
      'displayName': prefs.getString('sip_display_name'),
    };
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    print('🔥 DEBUG: registrationStateChanged called - State: ${state.state}');
    _registrationState = state;
    final wasConnected = _connected;
    _connected = state.state == RegistrationStateEnum.REGISTERED;
    _registrationStateController.add(state);

    // Trigger reconnection on registration failure or unregistered state
    if (wasConnected && !_connected && _autoReconnectEnabled && !_isReconnecting) {
      _scheduleReconnect();
    }
  }

  @override
  void transportStateChanged(TransportState state) {
    // Handle transport disconnection
    if (state.state == TransportStateEnum.DISCONNECTED && _connected && _autoReconnectEnabled && !_isReconnecting) {
      _scheduleReconnect();
    }
  }

  @override
  void callStateChanged(Call call, CallState callState) {
    print('🔥 DEBUG: callStateChanged called - State: ${callState.state}, Direction: ${call.direction}');
    _callStateController.add(call);

    // Add detailed call state logging
    String statusMessage = '';
    switch (callState.state) {
      case CallStateEnum.CALL_INITIATION:
        statusMessage = 'Call initiating to ${call.remote_identity}';
        // Handle both incoming and outgoing calls
        if (call.direction.toLowerCase() == 'outgoing') {
          Future.delayed(Duration(milliseconds: 100), () {
            // Direct navigation using Navigator instead of NavigationService
            final context = NavigationService.navigatorKey.currentContext;
            if (context != null) {
              Navigator.pushNamed(context, '/active_call', arguments: call);
              print('🔥 DEBUG: Direct navigation to /active_call successful');
            } else {
              print('🔥 DEBUG: No context available for navigation');
            }
          });
        } else if (call.direction.toLowerCase() == 'incoming') {
          // Handle incoming call - navigate to incoming call screen
          _handleIncomingCall(call);
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
          if (context != null) {
            // For incoming calls, replace the incoming call screen with active call screen
            // For outgoing calls, navigate normally (might already be on active call screen)
            if (call.direction?.toLowerCase() == 'incoming') {
              Navigator.pushReplacementNamed(context, '/active_call', arguments: call);
              print('🔥 DEBUG: CONFIRMED incoming call - replaced with active call screen');
            } else {
              Navigator.pushNamed(context, '/active_call', arguments: call);
              print('🔥 DEBUG: CONFIRMED outgoing call - navigated to active call screen');
            }
          } else {
            print('🔥 DEBUG: CONFIRMED - No context available for navigation');
          }
        });
        break;
      case CallStateEnum.ENDED:
        statusMessage = 'Call ended with ${call.remote_identity}';
        // Navigate back to home when call ends
        Future.delayed(Duration(milliseconds: 500), () {
          _navigationService.navigateToAndClearStack('/home');
        });
        break;
      case CallStateEnum.FAILED:
        statusMessage = 'Call failed to ${call.remote_identity}';
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
    print('SIP: $statusMessage - Direction: ${call.direction}'); // Debug print
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    // Handle new SIP messages
  }

  // Handle incoming calls when they arrive
  void _handleIncomingCall(Call call) {
    _callStateController.add(call);
    _reconnectStatusController.add('Incoming call from ${call.remote_identity}');
    print('SIP: Incoming call from ${call.remote_identity}'); // Debug print

    Future.delayed(Duration(milliseconds: 100), () {
      final context = NavigationService.navigatorKey.currentContext;
      if (context != null) {
        Navigator.pushNamed(context, '/incoming_call', arguments: call);
        print('🔥 DEBUG: Incoming call navigation successful');
      } else {
        print('🔥 DEBUG: Incoming call - No context available for navigation');
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
    _cancelReconnectTimer();
    _heartbeatTimer?.cancel();
    _registrationStateController.close();
    _callStateController.close();
    _reconnectStatusController.close();
  }
}
