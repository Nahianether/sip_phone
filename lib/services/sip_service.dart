import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sip_phone/services/call_kit.dart' show showIncomming;
import 'package:sip_ua/sip_ua.dart';
import '../models/sip_settings_model.dart';
import '../models/call_history_model.dart';
import '../utils/phone_utils.dart';
import 'storage_service.dart';
import 'navigation_service.dart';
import 'notification_service.dart';

class SipService extends SipUaHelperListener {
  static final SipService _instance = SipService._internal();
  factory SipService() => _instance;
  SipService._internal();

  SIPUAHelper? _helper;
  RegistrationState _registrationState = RegistrationState(state: RegistrationStateEnum.NONE);
  bool _connected = false;
  bool _autoReconnectEnabled = true;
  bool _isReconnecting = false;
  bool _handlingIncomingCall = false; // Prevent multiple simultaneous calls

  // Connection credentials for reconnection
  String? _lastUsername;
  String? _lastPassword;
  String? _lastServer;
  String? _lastWsUrl;
  String? _lastDisplayName;

  // Reconnection parameters - more conservative for stability
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5; // Reduced from 10 to 5
  final List<int> _reconnectDelays = [3, 10, 30, 60, 120]; // More spaced out: 3s, 10s, 30s, 1m, 2m

  // Connection health monitoring
  DateTime? _lastSuccessfulConnection;
  int _connectionFailures = 0;
  bool _networkAvailable = true;
  Timer? _keepAliveTimer;

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
  Stream<String> get reconnectStatusStream {
    // Emit initial status for new subscribers
    Future.microtask(() {
      if (!_reconnectStatusController.isClosed) {
        _reconnectStatusController.add(_connected ? 'Connected' : 'Disconnected');
      }
    });
    return _reconnectStatusController.stream;
  }

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

      // Enhanced stability settings for robust connection
      settings.register = true;
      settings.sessionTimers = true;
      settings.iceGatheringTimeout = 60000; // Increased from 500ms to 60s for better gathering

      // Connection recovery settings for stability
      settings.connectionRecoveryMaxInterval = 60; // Increased from 30s to 60s
      settings.connectionRecoveryMinInterval = 5; // Increased from 2s to 5s for more stable recovery

      // Registration settings
      settings.register_expires = 300; // 5 minutes registration refresh

      // Enhanced WebRTC configuration with more STUN servers for better connectivity
      settings.iceServers = [
        {'url': 'stun:stun.l.google.com:19302'},
        {'url': 'stun:stun1.l.google.com:19302'},
        {'url': 'stun:stun2.l.google.com:19302'},
        {'url': 'stun:stun3.l.google.com:19302'},
        {'url': 'stun:stun4.l.google.com:19302'},
        {'url': 'stun:stun.ekiga.net:3478'},
        {'url': 'stun:stun.ideasip.com:3478'},
        {'url': 'stun:stun.stunprotocol.org:3478'},
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

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(Duration(seconds: 60), (timer) {
      if (_connected && _helper != null) {
        // Send keep-alive by checking registration status
        debugPrint('💓 Keep-alive: Connection health check');
        // The SIP library handles keep-alive automatically, but we monitor health
        if (_lastSuccessfulConnection != null) {
          final timeSinceLastSuccess = DateTime.now().difference(_lastSuccessfulConnection!).inMinutes;
          if (timeSinceLastSuccess > 10) {
            debugPrint('⚠️ No activity for $timeSinceLastSuccess minutes - connection may be stale');
          }
        }
      }
    });
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  Future<void> disconnect() async {
    _isReconnecting = false;
    _stopKeepAlive();

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

  Future<void> _saveCredentials(
    String username,
    String password,
    String server,
    String wsUrl,
    String? displayName,
  ) async {
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
    final wasConnected = _connected;
    _connected = state.state == RegistrationStateEnum.REGISTERED;
    _registrationStateController.add(state);

    // Update connection health
    if (_connected) {
      _lastSuccessfulConnection = DateTime.now();
      _connectionFailures = 0;
      _reconnectAttempts = 0;
      _isReconnecting = false; // Clear reconnecting flag on successful registration
      _startKeepAlive(); // Start keep-alive monitoring
      _reconnectStatusController.add('Successfully registered to SIP server');
      debugPrint('✅ SIP Registration successful - Connection stable');
    } else if (wasConnected) {
      _connectionFailures++;
      _stopKeepAlive(); // Stop keep-alive when connection is lost
      debugPrint('❌ SIP Registration lost - Failure count: $_connectionFailures');
    }

    // Handle registration failure with backoff strategy
    if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      _reconnectStatusController.add('Registration failed - Will retry with backoff');
      if (_autoReconnectEnabled && !_isReconnecting && _reconnectAttempts < _maxReconnectAttempts) {
        // Use exponential backoff for registration failures
        final delay = _reconnectDelays[_reconnectAttempts.clamp(0, _reconnectDelays.length - 1)];
        Future.delayed(Duration(seconds: delay), () {
          if (!_connected && !_isReconnecting) {
            _attemptReconnectImmediate();
          }
        });
      }
    }

    // Only trigger immediate reconnection for unexpected disconnections (not failures)
    if (wasConnected && !_connected && state.state == RegistrationStateEnum.UNREGISTERED) {
      if (_autoReconnectEnabled && !_isReconnecting) {
        _reconnectStatusController.add('Unexpected disconnection, attempting to reconnect...');
        // Add delay to prevent reconnection loops
        Future.delayed(Duration(seconds: 5), () {
          if (!_connected && !_isReconnecting) {
            _attemptReconnectImmediate();
          }
        });
      }
    }
  }

  @override
  void transportStateChanged(TransportState state) {
    debugPrint('🔥 DEBUG: transportStateChanged called - State: ${state.state}');

    // Handle transport disconnection with more intelligent logic
    if (state.state == TransportStateEnum.DISCONNECTED) {
      _connectionFailures++;
      _reconnectStatusController.add('Transport disconnected');

      // Only attempt reconnection if we were previously connected and it's been stable
      final timeSinceLastConnection = _lastSuccessfulConnection != null
          ? DateTime.now().difference(_lastSuccessfulConnection!).inSeconds
          : 0;

      // Don't reconnect immediately if connection was very recent (< 30 seconds)
      // This prevents reconnection loops
      if (_connected && _autoReconnectEnabled && !_isReconnecting && timeSinceLastConnection > 30) {
        _reconnectStatusController.add('Transport lost, attempting to reconnect...');
        // Add a small delay before reconnection to avoid immediate retry loops
        Future.delayed(Duration(seconds: 2), () {
          if (!_isReconnecting) {
            _attemptReconnectImmediate();
          }
        });
      }
    } else if (state.state == TransportStateEnum.CONNECTED) {
      _reconnectStatusController.add('Transport connected successfully');
      // Reset failure count on successful connection
      _connectionFailures = 0;
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
          _handlingIncomingCall = true; // Prevent multiple simultaneous calls
          
          // Track incoming call
          _trackCallHistory(call, CallType.incoming);
          debugPrint('🔥 DEBUG: Incoming call from ${call.remote_identity}');
          
          try {
            // Show CallKit with proper error handling
            await showIncomming(call.id ?? DateTime.now().millisecondsSinceEpoch.toString(), 
                               call.remote_identity ?? 'Unknown');
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
    _stopKeepAlive();
    _registrationStateController.close();
    _callStateController.close();
    _reconnectStatusController.close();
  }
}
