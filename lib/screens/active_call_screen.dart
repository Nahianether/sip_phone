import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sip_ua/sip_ua.dart';
import '../providers/sip_providers.dart';
import '../providers/call_providers.dart';

final callStartTimeProvider = StateProvider<DateTime?>((ref) => null);

class ActiveCallScreen extends ConsumerStatefulWidget {
  final Call call;

  const ActiveCallScreen({super.key, required this.call});

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen> {
  Timer? _callTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToCallStates();
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  void _listenToCallStates() {
    ref.listen<AsyncValue<Call>>(callStateProvider, (previous, next) {
      next.whenData((call) {
        if (call.id == widget.call.id) {
          switch (call.state) {
            case CallStateEnum.CONNECTING:
              ref.read(callStatusProvider.notifier).state = 'Connecting...';
              break;
            case CallStateEnum.PROGRESS:
              ref.read(callStatusProvider.notifier).state = 'Ringing...';
              break;
            case CallStateEnum.ACCEPTED:
              ref.read(callStatusProvider.notifier).state = 'Call accepted';
              break;
            case CallStateEnum.CONFIRMED:
              ref.read(callStatusProvider.notifier).state = 'Connected';
              final startTime = ref.read(callStartTimeProvider);
              if (startTime == null) {
                ref.read(callStartTimeProvider.notifier).state = DateTime.now();
                _startCallTimer();
              }
              break;
            default:
              break;
          }
        }
      });
    });
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final startTime = ref.read(callStartTimeProvider);
      if (startTime != null) {
        final duration = DateTime.now().difference(startTime);
        ref.read(callDurationProvider.notifier).state = _formatDuration(duration);
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _hangup() {
    final sipService = ref.read(sipServiceProvider);
    sipService.hangup(widget.call);
    Navigator.pop(context);
  }

  void _toggleMute() {
    final currentMuted = ref.read(isMutedProvider);
    ref.read(isMutedProvider.notifier).state = !currentMuted;
  }

  void _toggleSpeaker() {
    final currentSpeaker = ref.read(isSpeakerOnProvider);
    ref.read(isSpeakerOnProvider.notifier).state = !currentSpeaker;
  }

  void _toggleHold() {
    final sipService = ref.read(sipServiceProvider);
    final currentHeld = ref.read(isHeldProvider);
    
    if (currentHeld) {
      sipService.unhold(widget.call);
    } else {
      sipService.hold(widget.call);
    }
    ref.read(isHeldProvider.notifier).state = !currentHeld;
  }

  void _showDTMFPad() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DTMF Keypad'),
        content: SizedBox(
          width: 250,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDTMFButton('1'),
                  _buildDTMFButton('2'),
                  _buildDTMFButton('3'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDTMFButton('4'),
                  _buildDTMFButton('5'),
                  _buildDTMFButton('6'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDTMFButton('7'),
                  _buildDTMFButton('8'),
                  _buildDTMFButton('9'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDTMFButton('*'),
                  _buildDTMFButton('0'),
                  _buildDTMFButton('#'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDTMFButton(String digit) {
    return ElevatedButton(
      onPressed: () {
        final sipService = ref.read(sipServiceProvider);
        sipService.sendDTMF(widget.call, digit);
      },
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(16),
      ),
      child: Text(digit, style: const TextStyle(fontSize: 20)),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
    Color? activeColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: isActive ? (activeColor ?? Colors.blue) : Colors.grey.shade300,
          child: Icon(
            icon,
            color: isActive ? Colors.white : Colors.black,
            size: 30,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final remoteIdentity = widget.call.remote_identity?.toString() ?? 'Unknown';
    final isMuted = ref.watch(isMutedProvider);
    final isSpeakerOn = ref.watch(isSpeakerOnProvider);
    final isHeld = ref.watch(isHeldProvider);
    final callDuration = ref.watch(callDurationProvider);
    final callStatus = ref.watch(callStatusProvider);
    final callStartTime = ref.watch(callStartTimeProvider);
    
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const CircleAvatar(
                radius: 80,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 80, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                remoteIdentity,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                isHeld ? 'Call On Hold' : (callStartTime != null ? callDuration : callStatus),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: _toggleMute,
                    child: _buildCallButton(
                      icon: isMuted ? Icons.mic_off : Icons.mic,
                      label: isMuted ? 'Unmute' : 'Mute',
                      onPressed: _toggleMute,
                      isActive: isMuted,
                      activeColor: Colors.orange,
                    ),
                  ),
                  GestureDetector(
                    onTap: _showDTMFPad,
                    child: _buildCallButton(
                      icon: Icons.dialpad,
                      label: 'Keypad',
                      onPressed: _showDTMFPad,
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleSpeaker,
                    child: _buildCallButton(
                      icon: isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                      label: 'Speaker',
                      onPressed: _toggleSpeaker,
                      isActive: isSpeakerOn,
                      activeColor: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: _toggleHold,
                    child: _buildCallButton(
                      icon: isHeld ? Icons.play_arrow : Icons.pause,
                      label: isHeld ? 'Resume' : 'Hold',
                      onPressed: _toggleHold,
                      isActive: isHeld,
                      activeColor: Colors.purple,
                    ),
                  ),
                  GestureDetector(
                    onTap: _hangup,
                    child: _buildCallButton(
                      icon: Icons.call_end,
                      label: 'End Call',
                      onPressed: _hangup,
                      isActive: true,
                      activeColor: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}