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

  // Pending calls system for FCM integration
  final Map<String, Call> _pendingCalls = {};
  Call? _activeCall;

  StreamController<RegistrationState> _registrationStateController =
      StreamController<RegistrationState>.broadcast();
  StreamController<Call> _callStateController = StreamController<Call>.broadcast();
  StreamController<String> _reconnectStatusController = StreamController<String>.broadcast();

  Stream<RegistrationState> get registrationStream => _registrationStateController.stream;
  Stream<Call> get callStream => _callStateController.stream;
  Stream<String> get reconnectStatusStream => _reconnectStatusController.stream;

  RegistrationState get registrationState => _registrationState;
  bool get connected => _connected;
  bool get isReconnecting => _isReconnecting;

  // Safe helper stop method to avoid concurrent modification errors
  Future<void> _safeStopHelper() async {
    if (_helper == null) return;
    
    try {
      // Give some time for any ongoing operations to complete
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Stop the helper with error handling
      _helper!.stop();
      debugPrint('🔥 DEBUG: Helper stopped successfully');
    } catch (e) {
      debugPrint('🔥 DEBUG: Error stopping helper: $e');
      // Force null the helper even if stop fails
      _helper = null;
    }
  }

  // Safe stream event methods that recreate controllers if closed
  void _safeAddToRegistrationStream(RegistrationState state) {
    try {
      if (_registrationStateController.isClosed) {
        debugPrint('🔥 DEBUG: Registration controller closed, recreating');
        _registrationStateController = StreamController<RegistrationState>.broadcast();
      }
      _registrationStateController.add(state);
    } catch (e) {
      debugPrint('🔥 DEBUG: Error adding to registration stream: $e');
    }
  }

  void _safeAddToCallStream(Call call) {
    try {
      if (_callStateController.isClosed) {
        debugPrint('🔥 DEBUG: Call controller closed, recreating');
        _callStateController = StreamController<Call>.broadcast();
      }
      _callStateController.add(call);
    } catch (e) {
      debugPrint('🔥 DEBUG: Error adding to call stream: $e');
    }
  }

  void _safeAddToReconnectStream(String message) {
    try {
      if (_reconnectStatusController.isClosed) {
        debugPrint('🔥 DEBUG: Reconnect controller closed, recreating');
        _reconnectStatusController = StreamController<String>.broadcast();
      }
      _reconnectStatusController.add(message);
    } catch (e) {
      debugPrint('🔥 DEBUG: Error adding to reconnect stream: $e');
    }
  }

  // Methods for managing pending calls
  void _storePendingCall(String callerId, Call call) {
    _pendingCalls[callerId] = call;
    debugPrint('🔥 DEBUG: Stored pending call from $callerId');
    debugPrint('🔥 DEBUG: Total pending calls: ${_pendingCalls.length}');
    debugPrint('🔥 DEBUG: All pending call IDs: ${_pendingCalls.keys.toList()}');
  }

  Call? getPendingCall(String callerId) {
    debugPrint('🔥 DEBUG: Looking for pending call with ID: $callerId');
    debugPrint('🔥 DEBUG: Available pending call IDs: ${_pendingCalls.keys.toList()}');
    
    final call = _pendingCalls[callerId];
    if (call != null) {
      debugPrint('🔥 DEBUG: Found pending call from $callerId');
      return call;
    }
    debugPrint('🔥 DEBUG: No pending call found for $callerId');
    return null;
  }

  void removePendingCall(String callerId) {
    _pendingCalls.remove(callerId);
    debugPrint('🔥 DEBUG: Removed pending call from $callerId');
  }

  void _removePendingCall(String callerId) {
    removePendingCall(callerId);
  }

  // Answer a pending call by caller ID
  void answerPendingCall(String callerId) {
    final call = getPendingCall(callerId);
    if (call != null) {
      debugPrint('🔥 DEBUG: Answering pending call from $callerId');
      answer(call);
      _activeCall = call;
      _removePendingCall(callerId);
    } else {
      debugPrint('🔥 DEBUG: Cannot answer - no pending call from $callerId');
    }
  }

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
        _safeAddToReconnectStream('Invalid connection parameters');
        return false;
      }

      // Store credentials for reconnection
      _lastUsername = username;
      _lastPassword = password;
      _lastServer = server;
      _lastWsUrl = wsUrl;
      _lastDisplayName = displayName ?? username;

      // CRITICAL FIX: Don't disconnect if we're already connected with same credentials
      // and have pending calls - this prevents FCM auto-reconnect from killing active calls
      if (_helper != null && _connected) {
        // Check if credentials are the same
        bool sameCredentials = _lastUsername == username &&
                              _lastPassword == password &&
                              _lastServer == server &&
                              _lastWsUrl == wsUrl;
        
        if (sameCredentials) {
          // Check if we have pending or active calls
          if (_pendingCalls.isNotEmpty || _activeCall != null) {
            debugPrint('🔥 DEBUG: Skipping reconnect - have active/pending calls with same credentials');
            _safeAddToReconnectStream('Already connected - preserving active calls');
            return true;
          }
        }
        
        // Only disconnect if credentials changed or no active calls
        debugPrint('🔥 DEBUG: Disconnecting - credentials changed or no active calls');
        try {
          await _safeStopHelper();
        } catch (e) {
          debugPrint('🔥 DEBUG: Error stopping helper safely: $e');
        }
        _helper = null;
        await Future.delayed(const Duration(milliseconds: 500)); // Allow cleanup
      } else if (_helper != null) {
        // Not connected but helper exists - clean it up
        try {
          await _safeStopHelper();
        } catch (e) {
          debugPrint('🔥 DEBUG: Error stopping helper safely: $e');
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
        _safeAddToReconnectStream('Invalid SIP settings configuration');
        return false;
      }

      _helper!.addSipUaHelperListener(this);

      // Add null check and error handling for start
      try {
        _helper!.start(settings);
        _safeAddToReconnectStream('Connecting to SIP server...');
      } catch (startError) {
        _safeAddToReconnectStream('Failed to start SIP connection: $startError');
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
      _safeAddToReconnectStream('Connection error: $e');
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
    _safeAddToReconnectStream('Reconnecting... ($_reconnectAttempts/$_maxReconnectAttempts)');

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
      _safeAddToReconnectStream('Reconnected successfully');
    } else if (_reconnectAttempts >= _maxReconnectAttempts) {
      _isReconnecting = false;
      _safeAddToReconnectStream('Failed to reconnect after $_maxReconnectAttempts attempts');
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

    _safeAddToReconnectStream('Reconnecting in $delay seconds...');

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
        await _safeStopHelper();
      } catch (e) {
        debugPrint('🔥 DEBUG: Error during disconnect: $e');
      }
      _helper = null;
    }
    _connected = false;
    _registrationState = RegistrationState(state: RegistrationStateEnum.NONE);
    _safeAddToRegistrationStream(_registrationState);
    _safeAddToReconnectStream('Disconnected');
  }

  Future<bool> makeCall(String target) async {
    if (_helper == null) {
      _safeAddToReconnectStream('SIP service not initialized');
      return false;
    }

    if (!_connected) {
      _safeAddToReconnectStream('Not connected to SIP server');
      return false;
    }

    try {
      debugPrint('🔥 DEBUG: makeCall called - target: $target, connected: $_connected');
      _safeAddToReconnectStream('Initiating call to $target...');

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
        _safeAddToReconnectStream('Call initiated to $target');
      } else {
        _safeAddToReconnectStream('Failed to initiate call to $target');
      }

      return success;
    } catch (e) {
      _safeAddToReconnectStream('Call error: $e');
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
        'mediaConstraints': {
          'audio': true,
          'video': false,
        },
      };
      
      call.answer(answerOptions);
      _safeAddToReconnectStream('Call answered');
      debugPrint('🔥 DEBUG: Call.answer() method called successfully');
    } catch (e) {
      debugPrint('🔥 DEBUG: Error in answer() method: $e');
      _safeAddToReconnectStream('Error answering call: $e');
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
    _safeAddToRegistrationStream(state);

    // Trigger reconnection on registration failure or unregistered state
    if (wasConnected && !_connected && _autoReconnectEnabled && !_isReconnecting) {
      // Don't reconnect if we have active or pending calls
      if (_pendingCalls.isNotEmpty || _activeCall != null) {
        debugPrint('🔥 DEBUG: Registration lost but preserving calls - not reconnecting');
        _safeAddToReconnectStream('Registration lost during call - preserving call state');
      } else {
        _scheduleReconnect();
      }
    }
  }

  @override
  void transportStateChanged(TransportState state) {
    // Handle transport disconnection
    if (state.state == TransportStateEnum.DISCONNECTED && _connected && _autoReconnectEnabled && !_isReconnecting) {
      // Don't reconnect if we have active or pending calls - this prevents call drops
      if (_pendingCalls.isNotEmpty || _activeCall != null) {
        debugPrint('🔥 DEBUG: Transport disconnected but preserving calls - not reconnecting');
        _safeAddToReconnectStream('Connection lost during call - preserving call state');
      } else {
        _scheduleReconnect();
      }
    }
  }

  @override
  void callStateChanged(Call call, CallState callState) {
    debugPrint('🔥 DEBUG: callStateChanged called - State: ${callState.state}, Direction: ${call.direction}');
    _safeAddToCallStream(call);

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
              debugPrint('🔥 DEBUG: Direct navigation to /active_call successful');
            } else {
              debugPrint('🔥 DEBUG: No context available for navigation');
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

    _safeAddToReconnectStream(statusMessage);
    debugPrint('SIP: $statusMessage - Direction: ${call.direction}');
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    // Handle new SIP messages
  }

  // Handle incoming calls when they arrive
  void _handleIncomingCall(Call call) {
    _safeAddToCallStream(call);
    _safeAddToReconnectStream('Incoming call from ${call.remote_identity}');
    debugPrint('SIP: Incoming call from ${call.remote_identity}');

    // Extract caller ID and store the call for FCM integration
    final callerId = _extractCallerIdFromCall(call);
    _storePendingCall(callerId, call);
    debugPrint('🔥 DEBUG: Stored incoming call from $callerId for FCM integration');

    Future.delayed(Duration(milliseconds: 100), () {
      final context = NavigationService.navigatorKey.currentContext;
      if (context != null) {
        Navigator.pushNamed(context, '/incoming_call', arguments: call);
        debugPrint('🔥 DEBUG: Incoming call navigation successful');
      } else {
        debugPrint('🔥 DEBUG: Incoming call - No context available for navigation');
      }
    });
  }

  String _extractCallerIdFromCall(Call call) {
    // Extract caller ID from the SIP call
    final remoteIdentity = call.remote_identity ?? 'Unknown';
    debugPrint('🔥 DEBUG: Raw remote_identity: $remoteIdentity');
    
    // Also check display_name and remote_identity separately
    debugPrint('🔥 DEBUG: Call display_name: ${call.remote_display_name}');
    debugPrint('🔥 DEBUG: Call direction: ${call.direction}');
    debugPrint('🔥 DEBUG: Call state: ${call.state}');
    
    // Try multiple extraction patterns
    // Pattern 1: "Display Name" <sip:123456@domain.com>
    final pattern1 = RegExp(r'"([^"]+)"\s*<sip:([^@]+)@');
    final match1 = pattern1.firstMatch(remoteIdentity);
    
    if (match1 != null) {
      final extractedId = match1.group(2) ?? 'Unknown';
      debugPrint('🔥 DEBUG: Extracted caller ID (pattern 1): $extractedId');
      return extractedId;
    }
    
    // Pattern 2: sip:123456@domain.com
    final pattern2 = RegExp(r'sip:([^@]+)@');
    final match2 = pattern2.firstMatch(remoteIdentity);
    
    if (match2 != null) {
      final extractedId = match2.group(1) ?? 'Unknown';
      debugPrint('🔥 DEBUG: Extracted caller ID (pattern 2): $extractedId');
      return extractedId;
    }
    
    // Pattern 3: Just the display name if available
    if (call.remote_display_name != null && call.remote_display_name!.isNotEmpty) {
      debugPrint('🔥 DEBUG: Using display name as caller ID: ${call.remote_display_name}');
      return call.remote_display_name!;
    }
    
    debugPrint('🔥 DEBUG: Could not extract caller ID, using raw identity');
    return remoteIdentity;
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
    
    // Don't close stream controllers if we have active or pending calls
    // This prevents "Bad state: Cannot add new events after calling close" errors
    if (_pendingCalls.isEmpty && _activeCall == null) {
      debugPrint('🔥 DEBUG: Closing stream controllers - no active calls');
      _registrationStateController.close();
      _callStateController.close();
      _reconnectStatusController.close();
    } else {
      debugPrint('🔥 DEBUG: Keeping stream controllers open - have ${_pendingCalls.length} pending calls and active call: ${_activeCall != null}');
    }
  }
  
  // Force dispose for complete shutdown
  void forceDispose() {
    _cancelReconnectTimer();
    _heartbeatTimer?.cancel();
    _pendingCalls.clear();
    _activeCall = null;
    
    try {
      _registrationStateController.close();
    } catch (e) {
      debugPrint('🔥 DEBUG: Error closing registration controller: $e');
    }
    try {
      _callStateController.close();
    } catch (e) {
      debugPrint('🔥 DEBUG: Error closing call controller: $e');
    }
    try {
      _reconnectStatusController.close();
    } catch (e) {
      debugPrint('🔥 DEBUG: Error closing reconnect controller: $e');
    }
  }
}
