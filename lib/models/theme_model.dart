import 'package:hive/hive.dart';

part 'theme_model.g.dart';

@HiveType(typeId: 3)
enum ThemeMode {
  @HiveField(0)
  light,
  @HiveField(1)
  dark,
  @HiveField(2)
  system,
}

@HiveType(typeId: 4)
class ThemeSettings extends HiveObject {
  @HiveField(0)
  final ThemeMode themeMode;

  ThemeSettings({
    this.themeMode = ThemeMode.system,
  });

  ThemeSettings copyWith({
    ThemeMode? themeMode,
  }) {
    return ThemeSettings(
      themeMode: themeMode ?? this.themeMode,
    );
  }
}