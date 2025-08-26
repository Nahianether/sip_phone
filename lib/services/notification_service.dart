import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRinging = false;

  // Start vibration and ringtone for incoming call
  Future<void> startIncomingCallAlert() async {
    if (_isRinging) return;
    
    _isRinging = true;
    
    // Start vibration pattern
    _startVibration();
    _vibrateWithLoop();
    
    // Start ringtone
    await _startRingtone();
  }

  // Stop all alerts
  Future<void> stopIncomingCallAlert() async {
    if (!_isRinging) return;
    
    _isRinging = false;
    
    // Stop vibration
    await _stopVibration();
    
    // Stop ringtone
    await _stopRingtone();
  }

  Future<void> _startVibration() async {
    try {
      // Use system services for vibration feedback (limited but compatible)
      await HapticFeedback.vibrate();
      debugPrint('Started haptic feedback for incoming call');
    } catch (e) {
      debugPrint('Error starting vibration: $e');
    }
  }

  void _vibrateWithLoop() async {
    while (_isRinging) {
      try {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 1500));
      } catch (e) {
        debugPrint('Error in vibration loop: $e');
        break;
      }
    }
  }

  Future<void> _stopVibration() async {
    try {
      // Stop vibration by setting _isRinging to false (handled in stopIncomingCallAlert)
      debugPrint('Vibration stopped');
    } catch (e) {
      debugPrint('Error stopping vibration: $e');
    }
  }

  Future<void> _startRingtone() async {
    try {
      // You can add custom ringtone assets to assets/audio/
      // For now, we'll use system notification sound or a simple tone
      
      // Try to play system notification sound first
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      
      // Create a simple ringtone using frequency or use asset
      // Since we don't have custom assets, we'll create a simple beep pattern
      await _playRingtonePattern();
    } catch (e) {
      debugPrint('Error starting ringtone: $e');
    }
  }

  Future<void> _playRingtonePattern() async {
    try {
      // Use system alert sound for ringtone
      debugPrint('🔊 Playing ringtone using system sounds');
      
      // For now, we'll create a simple pattern with system sounds
      _ringtonLoop();
    } catch (e) {
      debugPrint('Error in ringtone pattern: $e');
    }
  }

  void _ringtonLoop() async {
    while (_isRinging) {
      try {
        // Play system alert sound for ringtone
        await SystemSound.play(SystemSoundType.alert);
        debugPrint('🔊 Ring... Ring...');
        await Future.delayed(const Duration(milliseconds: 2000));
      } catch (e) {
        debugPrint('Error in ringtone loop: $e');
        break;
      }
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping ringtone: $e');
    }
  }

  // Play notification sound for call events
  Future<void> playNotificationSound() async {
    try {
      // Play a short notification beep
      debugPrint('🔔 Notification sound');
      // You can add a short notification sound here
    } catch (e) {
      debugPrint('Error playing notification sound: $e');
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}