import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sip_phone/services/call_kit.dart' show showIncomming;
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
  final int _maxReconnectAttempts = 10;
  final List<int> _reconnectDelays = [1, 2, 5, 10, 15, 20, 30, 45, 60, 90]; // seconds

  // Connection health monitoring
  DateTime? _lastSuccessfulConnection;
  int _connectionFailures = 0;

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
      // Enhanced parameter validation
      if (username.isEmpty || password.isEmpty || server.isEmpty || wsUrl.isEmpty) {
        _reconnectStatusController.add('Invalid connection parameters');
        return false;
      }

      // Validate WebSocket URL format
      if (!wsUrl.startsWith('ws://') && !wsUrl.startsWith('wss://')) {
        _reconnectStatusController.add('Invalid WebSocket URL format');
        return false;
      }

      // Store credentials for reconnection
      _lastUsername = username;
      _lastPassword = password;
      _lastServer = server;
      _lastWsUrl = wsUrl;
      _lastDisplayName = displayName ?? username;

      // Graceful disconnect of existing connection
      if (_helper != null) {
        try {
          _helper!.stop();
          _reconnectStatusController.add('Disconnecting previous session...');
        } catch (e) {
          debugPrint('Error during cleanup: $e');
        }
        _helper = null;
        // Longer delay to ensure proper cleanup
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      _helper = SIPUAHelper();

      final UaSettings settings = UaSettings();
      settings.webSocketUrl = wsUrl;
      settings.uri = 'sip:$username@$server';
      settings.authorizationUser = username;
      settings.password = password;
      settings.displayName = displayName?.isNotEmpty == true ? displayName : username;
      settings.userAgent = 'SIP Phone Flutter v1.0';
      settings.dtmfMode = DtmfMode.RFC2833;
      settings.transportType = TransportType.WS;

      // Enhanced stability settings
      settings.register = true;
      settings.sessionTimers = true;
      settings.iceGatheringTimeout = 30000;

      // Enhanced WebRTC configuration for better connectivity
      settings.iceServers = [
        {'url': 'stun:stun.l.google.com:19302'},
        {'url': 'stun:stun1.l.google.com:19302'},
        {'url': 'stun:stun2.l.google.com:19302'},
        {'url': 'stun:stun3.l.google.com:19302'},
        {'url': 'stun:stun4.l.google.com:19302'},
      ];

      // Final validation
      if (settings.webSocketUrl == null || settings.uri == null || settings.transportType == null) {
        _reconnectStatusController.add('Invalid SIP settings configuration');
        return false;
      }

      _helper!.addSipUaHelperListener(this);

      // Enhanced error handling for connection start
      try {
        _helper!.start(settings);
        _reconnectStatusController.add('Initializing SIP connection...');

        // Add connection timeout mechanism
        bool connectionEstablished = false;
        Timer(const Duration(seconds: 15), () {
          if (!connectionEstablished && !_connected) {
            _reconnectStatusController.add('Connection timeout - retrying...');
            if (_autoReconnectEnabled && !_isReconnecting) {
              Future.microtask(() => _attemptReconnectImmediate());
            }
          }
        });

        connectionEstablished = true;
      } catch (startError) {
        _reconnectStatusController.add('Failed to start SIP connection: $startError');
        _helper = null;
        return false;
      }

      if (saveCredentials) {
        await _saveCredentials(username, password, server, wsUrl, displayName);
      }

      // Reset reconnection attempts on successful connection initiation
      _reconnectAttempts = 0;
      _isReconnecting = false;

      return true;
    } catch (e) {
      _reconnectStatusController.add('Connection error: ${e.toString()}');
      _helper = null;

      // Trigger reconnection if enabled
      if (_autoReconnectEnabled && !_isReconnecting) {
        Future.microtask(() => _attemptReconnectImmediate());
      }
      return false;
    }
  }

  Future<void> _attemptReconnectImmediate() async {
    if (!_autoReconnectEnabled || _isReconnecting) return;
    if (_lastUsername == null || _lastPassword == null || _lastServer == null || _lastWsUrl == null) {
      return;
    }

    _isReconnecting = true;
    _reconnectAttempts++;
    _reconnectStatusController.add('Attempting reconnection... ($_reconnectAttempts/$_maxReconnectAttempts)');

    // Wait for a delay before attempting reconnection
    final delayIndex = (_reconnectAttempts - 1 < _reconnectDelays.length)
        ? _reconnectAttempts - 1
        : _reconnectDelays.length - 1;
    final delay = _reconnectDelays[delayIndex];

    _reconnectStatusController.add('Reconnecting in $delay seconds...');
    await Future.delayed(Duration(seconds: delay));

    if (_reconnectAttempts > _maxReconnectAttempts) {
      _isReconnecting = false;
      _reconnectStatusController.add('Max reconnection attempts reached');
      return;
    }

    try {
      final success = await connect(
        username: _lastUsername!,
        password: _lastPassword!,
        server: _lastServer!,
        wsUrl: _lastWsUrl!,
        displayName: _lastDisplayName,
        saveCredentials: false,
      );

      if (success) {
        _reconnectStatusController.add('Reconnected successfully');
        _reconnectAttempts = 0; // Reset attempts on successful connection
        _isReconnecting = false;
      } else if (_reconnectAttempts < _maxReconnectAttempts) {
        // Schedule another attempt
        _reconnectStatusController.add('Reconnection attempt failed, retrying...');
        Future.microtask(() => _attemptReconnectImmediate());
      } else {
        _isReconnecting = false;
        _reconnectStatusController.add('Failed to reconnect after $_maxReconnectAttempts attempts');
      }
    } catch (e) {
      if (_reconnectAttempts < _maxReconnectAttempts) {
        _reconnectStatusController.add('Reconnection error: $e, retrying...');
        Future.microtask(() => _attemptReconnectImmediate());
      } else {
        _isReconnecting = false;
        _reconnectStatusController.add('Failed to reconnect: $e');
      }
    }
  }

  void enableAutoReconnect(bool enabled) {
    _autoReconnectEnabled = enabled;
    if (!enabled) {
      _isReconnecting = false;
    }
  }

  // Get connection health information
  Map<String, dynamic> getConnectionHealth() {
    return {
      'connected': _connected,
      'isReconnecting': _isReconnecting,
      'reconnectAttempts': _reconnectAttempts,
      'maxReconnectAttempts': _maxReconnectAttempts,
      'connectionFailures': _connectionFailures,
      'lastSuccessfulConnection': _lastSuccessfulConnection?.toIso8601String(),
      'autoReconnectEnabled': _autoReconnectEnabled,
    };
  }

  Future<void> disconnect() async {
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
      debugPrint('🔥 DEBUG: makeCall called - target: $target, connected: $_connected');
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
      debugPrint('🔥 DEBUG: Attempting to answer call - Call ID: ${call.id}');

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
    debugPrint('🔥 DEBUG: registrationStateChanged called - State: ${state.state}');
    _registrationState = state;
    final wasConnected = _connected;
    _connected = state.state == RegistrationStateEnum.REGISTERED;
    _registrationStateController.add(state);

    // Update connection health
    if (_connected) {
      _lastSuccessfulConnection = DateTime.now();
      _connectionFailures = 0;
      _reconnectAttempts = 0;
      _reconnectStatusController.add('Successfully registered to SIP server');
    } else if (wasConnected) {
      _connectionFailures++;
    }

    // Trigger reconnection on registration failure or unregistered state
    if (wasConnected && !_connected && _autoReconnectEnabled && !_isReconnecting) {
      _reconnectStatusController.add('Connection lost, attempting to reconnect...');
      Future.microtask(() => _attemptReconnectImmediate());
    }
  }

  @override
  void transportStateChanged(TransportState state) {
    debugPrint('🔥 DEBUG: transportStateChanged called - State: ${state.state}');

    // Handle transport disconnection
    if (state.state == TransportStateEnum.DISCONNECTED) {
      _connectionFailures++;
      _reconnectStatusController.add('Transport disconnected');

      if (_connected && _autoReconnectEnabled && !_isReconnecting) {
        _reconnectStatusController.add('Transport lost, attempting to reconnect...');
        Future.microtask(() => _attemptReconnectImmediate());
      }
    } else if (state.state == TransportStateEnum.CONNECTED) {
      _reconnectStatusController.add('Transport connected successfully');
    }
  }

  @override
  void callStateChanged(Call call, CallState callState) {
    debugPrint('🔥 DEBUG: callStateChanged called - State: ${callState.state}, Direction: ${call.direction}');
    _callStateController.add(call);

    String statusMessage = '';
    switch (callState.state) {
      case CallStateEnum.CALL_INITIATION:
        statusMessage = 'Call initiating to ${call.remote_identity}';
        // Handle both incoming and outgoing calls
        if (call.direction.toLowerCase() == 'outgoing') {
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
        } else if (call.direction.toLowerCase() == 'incoming') {
          // Handle incoming call - navigate to incoming call screen
          _handleIncomingCall(call);
          showIncomming();
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

    Future.delayed(Duration(milliseconds: 100), () {
      final context = NavigationService.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Navigator.pushNamed(context, '/incoming_call', arguments: call);
        debugPrint('🔥 DEBUG: Incoming call navigation successful');
      } else {
        debugPrint('🔥 DEBUG: Incoming call - No context available for navigation');
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
