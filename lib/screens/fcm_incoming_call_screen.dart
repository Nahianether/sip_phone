import 'package:flutter/material.dart';
import '../services/sip_service.dart';

class FcmIncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String callerId;
  final String callUuid;
  final bool isVideo;

  const FcmIncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerId,
    required this.callUuid,
    required this.isVideo,
  });

  @override
  State<FcmIncomingCallScreen> createState() => _FcmIncomingCallScreenState();
}

class _FcmIncomingCallScreenState extends State<FcmIncomingCallScreen>
    with TickerProviderStateMixin {
  final SipService _sipService = SipService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
    debugPrint('🔥 FCM: User accepted call from ${widget.callerName}');
    
    // Check if there's a real pending SIP call for this caller ID
    debugPrint('🔥 FCM: Looking for pending call for caller ID: ${widget.callerId}');
    final pendingCall = _sipService.getPendingCall(widget.callerId);
    
    if (pendingCall != null) {
      debugPrint('🔥 FCM: Found real SIP call for ${widget.callerId}, answering now!');
      
      // Answer the real SIP call
      _sipService.answerPendingCall(widget.callerId);
      
      // Navigate to active call screen immediately
      Navigator.of(context).pushReplacementNamed('/active_call', arguments: pendingCall);
      
      debugPrint('🔥 FCM: Successfully connected to real SIP call!');
    } else {
      debugPrint('🔥 FCM: No real SIP call found for ${widget.callerId}');
      debugPrint('🔥 FCM: Will wait 5 seconds for real call to arrive...');
      
      // Wait a bit for the real call to arrive, then check again
      Future.delayed(const Duration(seconds: 5), () {
        final delayedCall = _sipService.getPendingCall(widget.callerId);
        if (delayedCall != null) {
          debugPrint('🔥 FCM: Found delayed real SIP call for ${widget.callerId}!');
          _sipService.answerPendingCall(widget.callerId);
          Navigator.of(context).pushReplacementNamed('/active_call', arguments: delayedCall);
        } else {
          debugPrint('🔥 FCM: Still no real SIP call found after delay');
        }
      });
      
      // Navigate to home and show connecting message
      Navigator.of(context).pushReplacementNamed('/home');
      
      // Show connecting message - the real SIP call should arrive shortly
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Waiting for call from ${widget.callerName}...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  void _declineCall() {
    debugPrint('🔥 FCM: User declined call from ${widget.callerName}');
    
    // Check if there's a real pending SIP call and decline it
    final pendingCall = _sipService.getPendingCall(widget.callerId);
    
    if (pendingCall != null) {
      debugPrint('🔥 FCM: Found real SIP call for ${widget.callerId}, declining now!');
      _sipService.hangup(pendingCall);
      // Remove from pending calls since it's declined
      _sipService.removePendingCall(widget.callerId);
    }
    
    // Navigate back to home
    Navigator.of(context).pushReplacementNamed('/home');
    
    // Show declined message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Call declined from ${widget.callerName}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isVideo ? Icons.videocam : Icons.phone,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isVideo ? 'Incoming Video Call' : 'Incoming Call',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Caller Info
            Column(
              children: [
                // Avatar with pulsing animation
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.green,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                // Caller Name
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // Caller Number
                Text(
                  widget.callerId,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // FCM Test Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text(
                    'FCM Test Call',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Row(
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
                        size: 30,
                      ),
                    ),
                  ),

                  // Accept Button
                  GestureDetector(
                    onTap: _acceptCall,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.call,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}