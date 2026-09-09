import 'package:flutter/services.dart';
class ObsidianLink {
  static const channel = MethodChannel('baker_reader/obsidian');
  static Future<Map<String, dynamic>> settings() async => Map<String, dynamic>.from(await channel.invokeMapMethod<String, dynamic>('settings') ?? {});
  static Future<void> chooseFolder() => channel.invokeMethod('chooseFolder');
  static Future<void> unlink() => channel.invokeMethod('unlink');
  static Future<void> configure(String folder, String vault) => channel.invokeMethod('configure', {'folder': folder, 'vault': vault});
  static Future<void> export(List<Map<String, Object>> files) => channel.invokeMethod('export', {'files': files});
  static Future<void> open() => channel.invokeMethod('open');
}
