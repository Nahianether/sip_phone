import 'package:hive/hive.dart';

part 'sip_settings_model.g.dart';

@HiveType(typeId: 2)
class SipSettingsModel extends HiveObject {
  @HiveField(0)
  final String? username;

  @HiveField(1)
  final String? password;

  @HiveField(2)
  final String? server;

  @HiveField(3)
  final String? wsUrl;

  @HiveField(4)
  final String? displayName;

  @HiveField(5)
  final bool autoConnect;

  SipSettingsModel({
    this.username,
    this.password,
    this.server,
    this.wsUrl,
    this.displayName,
    this.autoConnect = false,
  });

  SipSettingsModel copyWith({
    String? username,
    String? password,
    String? server,
    String? wsUrl,
    String? displayName,
    bool? autoConnect,
  }) {
    return SipSettingsModel(
      username: username ?? this.username,
      password: password ?? this.password,
      server: server ?? this.server,
      wsUrl: wsUrl ?? this.wsUrl,
      displayName: displayName ?? this.displayName,
      autoConnect: autoConnect ?? this.autoConnect,
    );
  }
}