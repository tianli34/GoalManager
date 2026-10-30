import 'package:shared_preferences/shared_preferences.dart';

/// 本地存储的极简抽象：首版只存/取一份 JSON 快照。
///
/// 抽出来是为了让测试可以注入内存实现，不需要插件通道。
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// 基于 shared_preferences 的实现（移动端 / 桌面 / Web 都可用）。
class SharedPrefsStore implements KeyValueStore {
  @override
  Future<String?> read(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}

/// 内存实现：用于单元测试和 widget 测试。
class InMemoryStore implements KeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
