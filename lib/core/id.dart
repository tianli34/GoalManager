import 'dart:math';

int _seq = 0;

/// 生成一个本地唯一 id。
///
/// 不引入 uuid 依赖：时间戳 + 随机数 + 进程内自增序号，
/// 对单机应用（首版定位）已经足够。
String newId([String prefix = 'id']) {
  final int micros = DateTime.now().microsecondsSinceEpoch;
  final int rand = Random().nextInt(1 << 24);
  _seq = (_seq + 1) & 0xFFFF;
  return '${prefix}_${micros.toRadixString(36)}_${rand.toRadixString(36)}_${_seq.toRadixString(36)}';
}
