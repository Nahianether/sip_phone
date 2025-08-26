import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/sip_providers.dart';

final phoneNumberProvider = StateProvider<String>((ref) => '');

class DialerScreen extends ConsumerWidget {
  const DialerScreen({super.key});

  void _addDigit(WidgetRef ref, String digit) {
    final currentNumber = ref.read(phoneNumberProvider);
    ref.read(phoneNumberProvider.notifier).state = currentNumber + digit;
  }

  void _removeDigit(WidgetRef ref) {
    final currentNumber = ref.read(phoneNumberProvider);
    if (currentNumber.isNotEmpty) {
      ref.read(phoneNumberProvider.notifier).state = 
          currentNumber.substring(0, currentNumber.length - 1);
    }
  }

  void _clearNumber(WidgetRef ref) {
    ref.read(phoneNumberProvider.notifier).state = '';
  }

  Future<void> _makeCall(WidgetRef ref, BuildContext context) async {
    final phoneNumber = ref.read(phoneNumberProvider);
    final sipService = ref.read(sipServiceProvider);
    
    if (await Permission.microphone.isDenied) {
      final status = await Permission.microphone.request();
      if (status.isDenied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required for calls'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }
    
    if (phoneNumber.isNotEmpty && sipService.connected) {
      final success = await sipService.makeCall(phoneNumber);
      if (success) {
        _clearNumber(ref);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to make call. Please check your connection.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else if (!sipService.connected) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not connected to SIP server. Please check settings.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Widget _buildDialButton({
    required String number,
    required String letters,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.all(4),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(24),
          elevation: 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              number,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (letters.isNotEmpty)
              Text(
                letters,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phoneNumber = ref.watch(phoneNumberProvider);
    final sipService = ref.watch(sipServiceProvider);
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                phoneNumber.isEmpty ? 'Enter phone number' : phoneNumber,
                style: TextStyle(
                  fontSize: 20,
                  color: phoneNumber.isEmpty ? Colors.grey : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildDialButton(
                                number: '1',
                                letters: '',
                                onPressed: () => _addDigit(ref, '1'),
                              ),
                              _buildDialButton(
                                number: '2',
                                letters: 'ABC',
                                onPressed: () => _addDigit(ref, '2'),
                              ),
                              _buildDialButton(
                                number: '3',
                                letters: 'DEF',
                                onPressed: () => _addDigit(ref, '3'),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildDialButton(
                                number: '4',
                                letters: 'GHI',
                                onPressed: () => _addDigit(ref, '4'),
                              ),
                              _buildDialButton(
                                number: '5',
                                letters: 'JKL',
                                onPressed: () => _addDigit(ref, '5'),
                              ),
                              _buildDialButton(
                                number: '6',
                                letters: 'MNO',
                                onPressed: () => _addDigit(ref, '6'),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildDialButton(
                                number: '7',
                                letters: 'PQRS',
                                onPressed: () => _addDigit(ref, '7'),
                              ),
                              _buildDialButton(
                                number: '8',
                                letters: 'TUV',
                                onPressed: () => _addDigit(ref, '8'),
                              ),
                              _buildDialButton(
                                number: '9',
                                letters: 'WXYZ',
                                onPressed: () => _addDigit(ref, '9'),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildDialButton(
                                number: '*',
                                letters: '',
                                onPressed: () => _addDigit(ref, '*'),
                              ),
                              _buildDialButton(
                                number: '0',
                                letters: '+',
                                onPressed: () => _addDigit(ref, '0'),
                              ),
                              _buildDialButton(
                                number: '#',
                                letters: '',
                                onPressed: () => _addDigit(ref, '#'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: "backspace_btn",
                  onPressed: phoneNumber.isNotEmpty ? () => _removeDigit(ref) : null,
                  backgroundColor: Colors.grey.shade300,
                  child: const Icon(Icons.backspace, color: Colors.black),
                ),
                FloatingActionButton(
                  heroTag: "call_btn",
                  onPressed: phoneNumber.isNotEmpty && sipService.connected 
                      ? () => _makeCall(ref, context) 
                      : null,
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.call, color: Colors.white),
                ),
                FloatingActionButton(
                  heroTag: "clear_btn",
                  onPressed: phoneNumber.isNotEmpty ? () => _clearNumber(ref) : null,
                  backgroundColor: Colors.red.shade300,
                  child: const Icon(Icons.clear, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}