import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sip_phone/providers/incoming.p.dart';
import 'package:sip_ua/sip_ua.dart';
import '../providers/sip_providers.dart';
import '../services/call_kit.dart' show stopNotification;

class IncomingCallScreen extends ConsumerStatefulWidget {
  final Call call;

  const IncomingCallScreen({super.key, required this.call});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    stopNotification(widget.call.id ?? '');
    _pulseController = AnimationController(duration: const Duration(seconds: 1), vsync: this);
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    stopNotification(widget.call.id ?? '');
    super.dispose();
  }

  Future<void> _acceptCall() async {
    await answer();
    await stopNotification(widget.call.id ?? '');
    // debugPrint('🔥 DEBUG: User tapped accept button');
    // final sipService = ref.read(sipServiceProvider);
    // sipService.answer(widget.call);
    // debugPrint('🔥 DEBUG: Called sipService.answer(), waiting for call state changes...');
  }

  Future<void> _declineCall() async {
    final sipService = ref.read(sipServiceProvider);
    sipService.hangup(widget.call);
    await stopNotification(widget.call.id ?? '');
    if (context.mounted) Navigator.pop(context);
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
              const Text('Incoming Call', style: TextStyle(color: Colors.white70, fontSize: 18)),
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
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text('Mobile', style: TextStyle(color: Colors.white70, fontSize: 16)),
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
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 35),
                    ),
                  ),
                  // Accept Button
                  GestureDetector(
                    onTap: _acceptCall,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      child: const Icon(Icons.call, color: Colors.white, size: 35),
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
                      //
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

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: Colors.grey.shade800, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 25),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
