import '../../core/id.dart';
import 'enums.dart';
import 'json_helpers.dart';

/// 一次更新记录。
///
/// 关键约定：**配置变更与真实推进必须区分**；始终保留原始量
/// （增量 / 读数 / 自评值），百分比只是派生展示。
class UpdateRecord {
  UpdateRecord({
    required this.id,
    required this.goalId,
    required this.timestamp,
    required this.type,
    this.delta,
    this.reading,
    this.selfRating,
    this.done,
    this.note = '',
    List<String>? attachments,
    this.changeReason,
    Map<String, String>? configChanges,
    this.fromLifecycle,
    this.toLifecycle,
  })  : attachments = attachments ?? <String>[],
        configChanges = configChanges ?? <String, String>{};

  factory UpdateRecord.progress({
    required String goalId,
    required DateTime at,
    double? delta,
    double? reading,
    double? selfRating,
    bool? done,
    String note = '',
    List<String>? attachments,
  }) =>
      UpdateRecord(
        id: newId('rec'),
        goalId: goalId,
        timestamp: at,
        type: RecordType.progress,
        delta: delta,
        reading: reading,
        selfRating: selfRating,
        done: done,
        note: note,
        attachments: attachments,
      );

  factory UpdateRecord.configChange({
    required String goalId,
    required DateTime at,
    required Map<String, String> changes,
    String reason = '',
  }) =>
      UpdateRecord(
        id: newId('rec'),
        goalId: goalId,
        timestamp: at,
        type: RecordType.configChange,
        configChanges: changes,
        changeReason: reason,
      );

  factory UpdateRecord.lifecycleChange({
    required String goalId,
    required DateTime at,
    required Lifecycle from,
    required Lifecycle to,
    String reason = '',
  }) =>
      UpdateRecord(
        id: newId('rec'),
        goalId: goalId,
        timestamp: at,
        type: RecordType.lifecycleChange,
        fromLifecycle: from,
        toLifecycle: to,
        changeReason: reason,
      );

  factory UpdateRecord.reopen({
    required String goalId,
    required DateTime at,
    String reason = '',
  }) =>
      UpdateRecord(
        id: newId('rec'),
        goalId: goalId,
        timestamp: at,
        type: RecordType.reopen,
        changeReason: reason,
      );

  factory UpdateRecord.fromJson(Map<String, Object?> json) => UpdateRecord(
        id: readStringOr(json['id'], newId('rec')),
        goalId: readStringOr(json['goalId'], ''),
        timestamp: readDate(json['timestamp']) ?? DateTime.now(),
        type: enumFromName(RecordType.values, readStringOrNull(json['type']), RecordType.progress),
        delta: readDouble(json['delta']),
        reading: readDouble(json['reading']),
        selfRating: readDouble(json['selfRating']),
        done: json['done'] is bool ? json['done']! as bool : null,
        note: readStringOr(json['note'], ''),
        attachments: readStringList(json['attachments']),
        changeReason: readStringOrNull(json['changeReason']),
        configChanges: readStringMap(json['configChanges']),
        fromLifecycle: enumFromName(
          Lifecycle.values,
          readStringOrNull(json['fromLifecycle']),
          Lifecycle.active,
        ),
        toLifecycle: enumFromName(
          Lifecycle.values,
          readStringOrNull(json['toLifecycle']),
          Lifecycle.active,
        ),
      );

  final String id;
  final String goalId;
  final DateTime timestamp;
  final RecordType type;

  /// 累积型：增量（可为负）。
  final double? delta;

  /// 指标型：读数（覆盖式更新，历史读数不删除）。
  final double? reading;

  /// 主观型：自评百分比。
  final double? selfRating;

  /// 完成型：一次完成 / 撤销。
  final bool? done;

  final String note;
  final List<String> attachments;

  /// 配置变更 / 状态变更的原因。
  final String? changeReason;

  /// 配置变更的具体字段：字段名 → "旧值 → 新值"。
  final Map<String, String> configChanges;

  Lifecycle? fromLifecycle;
  Lifecycle? toLifecycle;

  /// 这条记录是否真的推进了原始量（用于停滞检测）。
  bool get isValueChange =>
      (delta != null && delta != 0) || reading != null || selfRating != null || done == true;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'goalId': goalId,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'delta': delta,
        'reading': reading,
        'selfRating': selfRating,
        'done': done,
        'note': note,
        'attachments': attachments,
        'changeReason': changeReason,
        'configChanges': configChanges,
        'fromLifecycle': fromLifecycle?.name,
        'toLifecycle': toLifecycle?.name,
      };
}
