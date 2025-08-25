enum CallDirection { incoming, outgoing }

class CallInfo {
  final String id;
  final String remoteNumber;
  final String remoteName;
  final CallDirection direction;
  final DateTime startTime;
  final Duration? duration;
  final bool isActive;
  final bool isHeld;
  final bool isMuted;

  CallInfo({
    required this.id,
    required this.remoteNumber,
    required this.remoteName,
    required this.direction,
    required this.startTime,
    this.duration,
    this.isActive = false,
    this.isHeld = false,
    this.isMuted = false,
  });

  CallInfo copyWith({
    String? id,
    String? remoteNumber,
    String? remoteName,
    CallDirection? direction,
    DateTime? startTime,
    Duration? duration,
    bool? isActive,
    bool? isHeld,
    bool? isMuted,
  }) {
    return CallInfo(
      id: id ?? this.id,
      remoteNumber: remoteNumber ?? this.remoteNumber,
      remoteName: remoteName ?? this.remoteName,
      direction: direction ?? this.direction,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      isActive: isActive ?? this.isActive,
      isHeld: isHeld ?? this.isHeld,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}