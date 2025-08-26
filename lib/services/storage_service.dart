import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/call_history_model.dart';
import '../models/sip_settings_model.dart';

class StorageService {
  static const String _sipSettingsBoxName = 'sip_settings';
  static const String _callHistoryBoxName = 'call_history';
  static const String _settingsKey = 'current_settings';

  static late Box<SipSettingsModel> _sipSettingsBox;
  static late Box<CallHistoryModel> _callHistoryBox;

  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    Hive.registerAdapter(SipSettingsModelAdapter());
    Hive.registerAdapter(CallHistoryModelAdapter());
    Hive.registerAdapter(CallTypeAdapter());

    _sipSettingsBox = await Hive.openBox<SipSettingsModel>(_sipSettingsBoxName);
    _callHistoryBox = await Hive.openBox<CallHistoryModel>(_callHistoryBoxName);
    
    debugPrint('Hive storage initialized');
  }

  // SIP Settings methods
  static Future<void> saveSipSettings(SipSettingsModel settings) async {
    await _sipSettingsBox.put(_settingsKey, settings);
    debugPrint('SIP settings saved');
  }

  static SipSettingsModel? getSipSettings() {
    return _sipSettingsBox.get(_settingsKey);
  }

  static Future<void> clearSipSettings() async {
    await _sipSettingsBox.delete(_settingsKey);
    debugPrint('SIP settings cleared');
  }

  // Call History methods
  static Future<void> addCallHistory(CallHistoryModel call) async {
    await _callHistoryBox.add(call);
    debugPrint('Call history added: ${call.phoneNumber} - ${call.type}');
  }

  static List<CallHistoryModel> getCallHistory() {
    final calls = _callHistoryBox.values.toList();
    calls.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Most recent first
    return calls;
  }

  static List<CallHistoryModel> getCallHistoryByType(CallType type) {
    return getCallHistory().where((call) => call.type == type).toList();
  }

  static Future<void> clearCallHistory() async {
    await _callHistoryBox.clear();
    debugPrint('Call history cleared');
  }

  static Future<void> deleteCallHistory(String id) async {
    final calls = _callHistoryBox.values.where((call) => call.id == id).toList();
    for (final call in calls) {
      await call.delete();
    }
    debugPrint('Call history deleted: $id');
  }

  // Utility methods
  static Future<void> clearAllData() async {
    await _sipSettingsBox.clear();
    await _callHistoryBox.clear();
    debugPrint('All storage data cleared');
  }

  static Future<void> close() async {
    await _sipSettingsBox.close();
    await _callHistoryBox.close();
  }
}