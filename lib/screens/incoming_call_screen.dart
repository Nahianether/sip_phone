import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import '../services/sip_service.dart';

class IncomingCallScreen extends StatefulWidget {
  final Call call;

  const IncomingCallScreen({super.key, required this.call});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  final SipService _sipService = SipService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _callAnswered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _acceptCall() {
    if (_callAnswered) {
      print('🔥 DEBUG: Call already answered, ignoring tap');
      return;
    }
    
    setState(() {
      _callAnswered = true;
    });
    
    print('🔥 DEBUG: User tapped accept button');
    
    try {
      print('🔥 DEBUG: Attempting to answer call - Call ID: ${widget.call.id}');
      _sipService.answer(widget.call);
      print('🔥 DEBUG: Call.answer() method called successfully');
      print('🔥 DEBUG: Called _sipService.answer(), waiting for call state changes...');
      // Don't navigate immediately - let the SIP service handle navigation
      // when the call reaches CONFIRMED state
    } catch (e) {
      print('🔥 DEBUG: Error answering call: $e');
      setState(() {
        _callAnswered = false; // Reset if error
      });
    }
  }

  void _declineCall() {
    _sipService.hangup(widget.call);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final remoteIdentity = widget.call.remote_identity?.toString() ?? 'Unknown Caller';
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Text(
                'Incoming Call',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 40),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: const CircleAvatar(
                      radius: 80,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, size: 80, color: Colors.white),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              Text(
                remoteIdentity,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Mobile',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline Button
                  GestureDetector(
                    onTap: _declineCall,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 35,
                      ),
                    ),
                  ),
                  // Accept Button
                  GestureDetector(
                    onTap: _callAnswered ? null : _acceptCall,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: _callAnswered ? Colors.grey : Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: _callAnswered 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.call,
                            color: Colors.white,
                            size: 35,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.message,
                    label: 'Message',
                    onPressed: () {
                      // TODO: Send quick message
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.person_add,
                    label: 'Add Contact',
                    onPressed: () {
                      // TODO: Add to contacts
                    },
                  ),
                ],
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 25,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}