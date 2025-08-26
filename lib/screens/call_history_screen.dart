import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/call_history_model.dart';
import '../services/storage_service.dart';
import '../services/contacts_service.dart';
import '../utils/phone_utils.dart';
import '../providers/sip_providers.dart';

final callHistoryProvider = FutureProvider<List<CallHistoryModel>>((ref) async {
  return StorageService.getCallHistory();
});

class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final AppContactsService _contactsService = AppContactsService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getContactName(String phoneNumber) {
    return _contactsService.getContactName(phoneNumber);
  }

  IconData _getCallIcon(CallType type) {
    switch (type) {
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.missed:
        return Icons.call_received;
    }
  }

  Color _getCallColor(CallType type) {
    switch (type) {
      case CallType.incoming:
        return Colors.green;
      case CallType.outgoing:
        return Colors.blue;
      case CallType.missed:
        return Colors.red;
    }
  }

  List<CallHistoryModel> _filterCallsByType(List<CallHistoryModel> calls, CallType? type) {
    if (type == null) return calls;
    return calls.where((call) => call.type == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    final callHistoryAsync = ref.watch(callHistoryProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All', icon: Icon(Icons.history)),
            Tab(text: 'Missed', icon: Icon(Icons.call_received, color: Colors.red)),
            Tab(text: 'Incoming', icon: Icon(Icons.call_received, color: Colors.green)),
            Tab(text: 'Outgoing', icon: Icon(Icons.call_made, color: Colors.blue)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'clear_all') {
                final confirmed = await _showClearHistoryDialog();
                if (confirmed) {
                  await StorageService.clearCallHistory();
                  ref.invalidate(callHistoryProvider);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear All'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: callHistoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading call history: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(callHistoryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (calls) {
          if (calls.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No call history yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your call history will appear here',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCallList(calls),
              _buildCallList(_filterCallsByType(calls, CallType.missed)),
              _buildCallList(_filterCallsByType(calls, CallType.incoming)),
              _buildCallList(_filterCallsByType(calls, CallType.outgoing)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCallList(List<CallHistoryModel> calls) {
    if (calls.isEmpty) {
      return const Center(
        child: Text(
          'No calls in this category',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: calls.length,
      itemBuilder: (context, index) {
        final call = calls[index];
        final contactName = _getContactName(call.phoneNumber);
        final isContact = contactName != call.phoneNumber;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getCallColor(call.type),
              child: Icon(
                _getCallIcon(call.type),
                color: Colors.white,
              ),
            ),
            title: Text(
              contactName,
              style: TextStyle(
                fontWeight: isContact ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isContact) 
                  Text(
                    PhoneUtils.formatPhoneNumber(call.phoneNumber),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                Text(
                  _formatTimestamp(call.timestamp),
                  style: TextStyle(color: Colors.grey[600]),
                ),
                if (call.duration > 0)
                  Text(
                    'Duration: ${call.formattedDuration}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.call),
                  onPressed: () => _makeCall(call.phoneNumber),
                  color: Colors.green,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'delete') {
                      await StorageService.deleteCallHistory(call.id);
                      ref.invalidate(callHistoryProvider);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    final sipService = ref.read(sipServiceProvider);
    await sipService.makeCall(phoneNumber);
  }

  Future<bool> _showClearHistoryDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Call History'),
        content: const Text('Are you sure you want to clear all call history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    ) ?? false;
  }
}