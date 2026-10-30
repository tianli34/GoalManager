import 'dart:convert';

import '../models/app_data.dart';
import 'key_value_store.dart';

/// 负责整份数据的读写与损坏保护。
class AppRepository {
  AppRepository(this._store);

  final KeyValueStore _store;

  static const String mainKey = 'goal_manager.data.v1';
  static const String brokenPrefix = 'goal_manager.data.broken.';

  /// 上一次读取的错误（供设置页提示）。
  String? lastError;

  Future<AppData?> load() async {
    final String? raw = await _store.read(mainKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('顶层不是 JSON 对象');
      return AppData.fromJson(decoded.cast<String, Object?>());
    } catch (e) {
      // 不静默丢数据：把无法解析的内容另存一份。
      lastError = '读取数据失败：$e';
      await _store.write(
          '$brokenPrefix${DateTime.now().millisecondsSinceEpoch}', raw);
      return null;
    }
  }

  Future<void> save(AppData data) async {
    lastError = null;
    await _store.write(mainKey, jsonEncode(data.toJson()));
  }

  Future<void> clear() async {
    await _store.write(mainKey, '');
  }
}
