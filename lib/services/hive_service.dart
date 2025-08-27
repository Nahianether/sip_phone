import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/auth_response_model.dart';

class HiveService {
  static bool _isInitialized = false;

  /// Initialize Hive with all required adapters
  static Future<void> initHive() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive
      await Hive.initFlutter();
      
      // Register adapters
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(AuthResponseModelAdapter());
      }

      _isInitialized = true;
      debugPrint('HiveService: Initialized successfully');
    } catch (e) {
      debugPrint('HiveService: Initialization error: $e');
      rethrow;
    }
  }

  /// Close all Hive boxes
  static Future<void> closeAll() async {
    try {
      await Hive.close();
      _isInitialized = false;
      debugPrint('HiveService: All boxes closed');
    } catch (e) {
      debugPrint('HiveService: Error closing boxes: $e');
    }
  }

  /// Clear all Hive data (for debugging/testing)
  static Future<void> clearAllData() async {
    try {
      await Hive.deleteFromDisk();
      _isInitialized = false;
      debugPrint('HiveService: All data cleared from disk');
    } catch (e) {
      debugPrint('HiveService: Error clearing data: $e');
    }
  }

  /// Check if Hive is initialized
  static bool get isInitialized => _isInitialized;
}