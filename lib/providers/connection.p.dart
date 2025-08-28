import 'dart:developer';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sip_phone/services/sip_service.dart' show SipService, saveCredentials;
import 'package:sip_ua/sip_ua.dart' show SIPUAHelper, UaSettings, DtmfMode, TransportType;

import '../services/storage_service.dart' show StorageService;

part 'connection.p.g.dart';

@Riverpod(keepAlive: true)
class SipHelpers extends _$SipHelpers {
  @override
  SIPUAHelper? build() => null;

  void set(SIPUAHelper? s) => state = s;

  Future<void> start(UaSettings s) async {
    if (state == null) return;
    await state!.start(s);
  }

  void stop() {
    if (state == null) return;
    state!.stop();
  }

  void addService(SipService s) {
    if (state == null) return;
    state!.addSipUaHelperListener(s);
  }

  Future<bool> call(String target, bool isVoice, Map<String, Map<String, Object>> options) async {
    if (state == null) return false;
    try {
      return await state!.call(target, voiceOnly: isVoice, customOptions: options);
    } catch (e) {
      log(e.toString());
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
class ServerConnection extends _$ServerConnection {
  @override
  Future<bool> build() async {
    log('--build--');
    return await connect_();
  }

  void set(bool b) => state = AsyncData(b);

  Future<bool> connect_() async {
    if (state.value == true) return true;
    await Future.delayed(const Duration(seconds: 3));
    final storedSettings = StorageService.getSipSettings();
    if (storedSettings != null &&
        storedSettings.autoConnect == true &&
        storedSettings.username?.isNotEmpty == true &&
        storedSettings.password?.isNotEmpty == true &&
        storedSettings.server?.isNotEmpty == true &&
        storedSettings.wsUrl?.isNotEmpty == true) {
      debugPrint('Auto-connecting with stored credentials...');

      log('_requestPermissions --------------------------${storedSettings.username!}');
      return await _connect(
        username: storedSettings.username!,
        password: storedSettings.password!,
        server: storedSettings.server!,
        wsUrl: storedSettings.wsUrl!,
        displayName: storedSettings.displayName,
        isSave: false, // Don't save again
      );
    } else {
      debugPrint('Auto-connect skipped: missing credentials');
    }
    return false;
  }

  Future<bool> _connect({
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
        log('Invalid--- connection parameters');
        return false;
      }

      // Validate WebSocket URL format
      if (!wsUrl.startsWith('ws://') && !wsUrl.startsWith('wss://')) {
        log('Invalid WebSocket URL format');
        return false;
      }

      // Graceful disconnect of existing connection
      if (helper_ != null) {
        try {
          helperNotifier.stop();
          log('Disconnecting previous session...');
        } catch (e) {
          debugPrint('Error during cleanup: $e');
        }
        helperNotifier.set(null);
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
        log('Invalid SIP settings configuration');
        return false;
      }
      final sipService = SipService();
      helperNotifier.addService(sipService);

      try {
        await helperNotifier.start(settings);
        log('Initializing SIP connection...');
      } catch (startError) {
        log('Failed to start SIP connection: $startError');
        print('------ Server connection failed to start: $startError ------');
        helperNotifier.set(null);
        return false;
      }

      if (isSave) {
        await saveCredentials(username, password, server, wsUrl, displayName);
      }

      return true;
    } catch (e) {
      log('Connection error: ${e.toString()}');
      print('------ Server connection error: ${e.toString()} ------');
      helperNotifier.set(null);
      return false;
    }
  }
}
