import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/sip_service.dart';

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  final SipService _sipService = SipService();
  String _phoneNumber = '';

  void _addDigit(String digit) {
    setState(() {
      _phoneNumber += digit;
    });
  }

  void _removeDigit() {
    setState(() {
      if (_phoneNumber.isNotEmpty) {
        _phoneNumber = _phoneNumber.substring(0, _phoneNumber.length - 1);
      }
    });
  }

  void _clearNumber() {
    setState(() {
      _phoneNumber = '';
    });
  }

  Future<void> _makeCall() async {
    // Request microphone permission
    if (await Permission.microphone.isDenied) {
      final status = await Permission.microphone.request();
      if (status.isDenied) {
        if (mounted) {
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
    
    if (_phoneNumber.isNotEmpty && _sipService.connected) {
      final success = await _sipService.makeCall(_phoneNumber);
      if (success) {
        _clearNumber();
        // Navigation is now handled by SIP service
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to make call. Please check your connection.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else if (!_sipService.connected) {
      if (mounted) {
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
  Widget build(BuildContext context) {
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
                _phoneNumber.isEmpty ? 'Enter phone number' : _phoneNumber,
                style: TextStyle(
                  fontSize: 20,
                  color: _phoneNumber.isEmpty ? Colors.grey : Colors.black,
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
                      onPressed: () => _addDigit('1'),
                    ),
                    _buildDialButton(
                      number: '2',
                      letters: 'ABC',
                      onPressed: () => _addDigit('2'),
                    ),
                    _buildDialButton(
                      number: '3',
                      letters: 'DEF',
                      onPressed: () => _addDigit('3'),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDialButton(
                      number: '4',
                      letters: 'GHI',
                      onPressed: () => _addDigit('4'),
                    ),
                    _buildDialButton(
                      number: '5',
                      letters: 'JKL',
                      onPressed: () => _addDigit('5'),
                    ),
                    _buildDialButton(
                      number: '6',
                      letters: 'MNO',
                      onPressed: () => _addDigit('6'),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDialButton(
                      number: '7',
                      letters: 'PQRS',
                      onPressed: () => _addDigit('7'),
                    ),
                    _buildDialButton(
                      number: '8',
                      letters: 'TUV',
                      onPressed: () => _addDigit('8'),
                    ),
                    _buildDialButton(
                      number: '9',
                      letters: 'WXYZ',
                      onPressed: () => _addDigit('9'),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDialButton(
                      number: '*',
                      letters: '',
                      onPressed: () => _addDigit('*'),
                    ),
                    _buildDialButton(
                      number: '0',
                      letters: '+',
                      onPressed: () => _addDigit('0'),
                    ),
                    _buildDialButton(
                      number: '#',
                      letters: '',
                      onPressed: () => _addDigit('#'),
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
                  onPressed: _phoneNumber.isNotEmpty ? _removeDigit : null,
                  backgroundColor: Colors.grey.shade300,
                  child: const Icon(Icons.backspace, color: Colors.black),
                ),
                FloatingActionButton(
                  onPressed: _phoneNumber.isNotEmpty && _sipService.connected ? _makeCall : null,
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.call, color: Colors.white),
                ),
                FloatingActionButton(
                  onPressed: _phoneNumber.isNotEmpty ? _clearNumber : null,
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