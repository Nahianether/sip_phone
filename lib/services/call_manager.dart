import 'dart:async';
import 'package:sip_ua/sip_ua.dart';
import '../models/call_state.dart';

class CallManager {
  static final CallManager _instance = CallManager._internal();
  factory CallManager() => _instance;
  CallManager._internal();

  final Map<String, CallInfo> _activeCalls = {};
  final StreamController<Map<String, CallInfo>> _callsController =
      StreamController<Map<String, CallInfo>>.broadcast();

  Stream<Map<String, CallInfo>> get callsStream => _callsController.stream;
  Map<String, CallInfo> get activeCalls => Map.from(_activeCalls);

  void addCall(Call call) {
    final callInfo = CallInfo(
      id: call.id!,
      remoteNumber: call.remote_identity?.toString() ?? 'Unknown',
      remoteName: call.remote_identity?.toString() ?? 'Unknown',
      direction: call.direction == 'incoming' ? CallDirection.incoming : CallDirection.outgoing,
      startTime: DateTime.now(),
      isActive: true,
    );

    _activeCalls[call.id!] = callInfo;
    _callsController.add(_activeCalls);
  }

  void updateCall(Call call, CallState state) {
    final callInfo = _activeCalls[call.id];
    if (callInfo != null) {
      CallInfo updatedCall;
      
      switch (state.state) {
        case CallStateEnum.CONNECTING:
        case CallStateEnum.PROGRESS:
          updatedCall = callInfo.copyWith(isActive: true);
          break;
        case CallStateEnum.CONFIRMED:
          updatedCall = callInfo.copyWith(
            isActive: true,
            startTime: DateTime.now(),
          );
          break;
        case CallStateEnum.ENDED:
        case CallStateEnum.FAILED:
          _activeCalls.remove(call.id);
          _callsController.add(_activeCalls);
          return;
        default:
          updatedCall = callInfo;
      }

      _activeCalls[call.id!] = updatedCall;
      _callsController.add(_activeCalls);
    }
  }

  void removeCall(String callId) {
    _activeCalls.remove(callId);
    _callsController.add(_activeCalls);
  }

  void holdCall(String callId, bool isHeld) {
    final callInfo = _activeCalls[callId];
    if (callInfo != null) {
      _activeCalls[callId] = callInfo.copyWith(isHeld: isHeld);
      _callsController.add(_activeCalls);
    }
  }

  void muteCall(String callId, bool isMuted) {
    final callInfo = _activeCalls[callId];
    if (callInfo != null) {
      _activeCalls[callId] = callInfo.copyWith(isMuted: isMuted);
      _callsController.add(_activeCalls);
    }
  }

  void clearAllCalls() {
    _activeCalls.clear();
    _callsController.add(_activeCalls);
  }

  void dispose() {
    _callsController.close();
  }
}