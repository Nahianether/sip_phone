import 'package:hive/hive.dart';

part 'call_history_model.g.dart';

@HiveType(typeId: 0)
class CallHistoryModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String phoneNumber;

  @HiveField(2)
  final String? contactName;

  @HiveField(3)
  final CallType type;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final int duration; // in seconds

  CallHistoryModel({
    required this.id,
    required this.phoneNumber,
    this.contactName,
    required this.type,
    required this.timestamp,
    this.duration = 0,
  });

  String get formattedDuration {
    if (duration == 0) return '0:00';
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get displayName => contactName ?? phoneNumber;
}

@HiveType(typeId: 1)
enum CallType {
  @HiveField(0)
  incoming,
  
  @HiveField(1)
  outgoing,
  
  @HiveField(2)
  missed,
}