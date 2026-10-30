/// JSON 反序列化时的容错读取：旧备份 / 手工编辑都可能带来类型漂移。
double? readDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

double readDoubleOr(Object? v, double fallback) => readDouble(v) ?? fallback;

int? readInt(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

int readIntOr(Object? v, int fallback) => readInt(v) ?? fallback;

bool readBoolOr(Object? v, bool fallback) {
  if (v is bool) return v;
  if (v is String) return v == 'true';
  return fallback;
}

DateTime? readDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

String readStringOr(Object? v, String fallback) => v == null ? fallback : v.toString();

String? readStringOrNull(Object? v) => v?.toString();

List<String> readStringList(Object? v) {
  if (v is List) return v.map((Object? e) => e.toString()).toList();
  return <String>[];
}

Map<String, String> readStringMap(Object? v) {
  if (v is Map) {
    return v.map((Object? k, Object? e) => MapEntry(k.toString(), e.toString()));
  }
  return <String, String>{};
}

List<T> readList<T>(Object? v, T Function(Object? raw) parse) {
  if (v is List) return v.map(parse).toList();
  return <T>[];
}
