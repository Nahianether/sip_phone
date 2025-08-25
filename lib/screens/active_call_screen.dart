import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import '../services/sip_service.dart';

class ActiveCallScreen extends StatefulWidget {
  final Call call;

  const ActiveCallScreen({super.key, required this.call});

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  final SipService _sipService = SipService();
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isHeld = false;
  String _callDuration = '00:00';
  DateTime? _callStartTime;
  String _callStatus = 'Connecting...';
  late Stream<Call> _callStateStream;

  @override
  void initState() {
    super.initState();
    _callStateStream = _sipService.callStream;
    _listenToCallStates();
  }

  void _listenToCallStates() {
    _callStateStream.listen((call) {
      if (call.id == widget.call.id) {
        setState(() {
          switch (call.state) {
            case CallStateEnum.CONNECTING:
              _callStatus = 'Connecting...';
              break;
            case CallStateEnum.PROGRESS:
              _callStatus = 'Ringing...';
              break;
            case CallStateEnum.ACCEPTED:
              _callStatus = 'Call accepted';
              break;
            case CallStateEnum.CONFIRMED:
              _callStatus = 'Connected';
              if (_callStartTime == null) {
                _callStartTime = DateTime.now();
                _startCallTimer();
              }
              break;
            default:
              break;
          }
        });
      }
    });
  }

  void _startCallTimer() {
    Stream.periodic(const Duration(seconds: 1), (i) => i).listen((_) {
      if (_callStartTime != null) {
        final duration = DateTime.now().difference(_callStartTime!);
        setState(() {
          _callDuration = _formatDuration(duration);
        });
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
    _sipService.hangup(widget.call);
    Navigator.pop(context);
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  void _toggleHold() {
    if (_isHeld) {
      _sipService.unhold(widget.call);
    } else {
      _sipService.hold(widget.call);
    }
    setState(() {
      _isHeld = !_isHeld;
    });
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
        _sipService.sendDTMF(widget.call, digit);
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
                _isHeld ? 'Call On Hold' : (_callStartTime != null ? _callDuration : _callStatus),
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
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      onPressed: _toggleMute,
                      isActive: _isMuted,
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
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                      label: 'Speaker',
                      onPressed: _toggleSpeaker,
                      isActive: _isSpeakerOn,
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
                      icon: _isHeld ? Icons.play_arrow : Icons.pause,
                      label: _isHeld ? 'Resume' : 'Hold',
                      onPressed: _toggleHold,
                      isActive: _isHeld,
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