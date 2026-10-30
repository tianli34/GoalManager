import '../../core/id.dart';
import 'enums.dart';
import 'json_helpers.dart';

/// 目标。子目标同样是 Goal，共用一套机制；父子关系只用于进度上卷。
class Goal {
  Goal({
    required this.id,
    required this.title,
    this.why = '',
    this.successCriteria = '',
    this.mechanism = Mechanism.completion,
    this.lifecycle = Lifecycle.active,
    this.startDate,
    this.dueDate,
    List<String>? tags,
    this.parentGoalId,
    this.weight = 1,
    this.isRequired = true,
    this.sortOrder = 0,
    this.statusOverride = ChildStatusOverride.none,
    this.startValue,
    this.currentValue,
    this.targetValue,
    this.unit = '',
    this.executionMode = ExecutionMode.parallel,
    this.stableWindow = 3,
    this.isArchived = false,
    this.isFocus = false,
    this.noUpdateThresholdDays,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : tags = tags ?? <String>[],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Goal.create({
    String? id,
    required String title,
    required Mechanism mechanism,
    String why = '',
    String successCriteria = '',
    Lifecycle lifecycle = Lifecycle.active,
    DateTime? startDate,
    DateTime? dueDate,
    List<String>? tags,
    String? parentGoalId,
    double weight = 1,
    bool isRequired = true,
    int sortOrder = 0,
    double? startValue,
    double? currentValue,
    double? targetValue,
    String unit = '',
    ExecutionMode executionMode = ExecutionMode.parallel,
    int stableWindow = 3,
    bool isFocus = false,
  }) {
    final DateTime now = DateTime.now();
    return Goal(
      id: id ?? newId('goal'),
      title: title,
      why: why,
      successCriteria: successCriteria,
      mechanism: mechanism,
      lifecycle: lifecycle,
      startDate: startDate,
      dueDate: dueDate,
      tags: tags,
      parentGoalId: parentGoalId,
      weight: weight,
      isRequired: isRequired,
      sortOrder: sortOrder,
      startValue: startValue,
      currentValue: currentValue,
      targetValue: targetValue,
      unit: unit,
      executionMode: executionMode,
      stableWindow: stableWindow,
      isFocus: isFocus,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Goal.fromJson(Map<String, Object?> json) => Goal(
        id: readStringOr(json['id'], newId('goal')),
        title: readStringOr(json['title'], '未命名目标'),
        why: readStringOr(json['why'], ''),
        successCriteria: readStringOr(json['successCriteria'], ''),
        mechanism: enumFromName(Mechanism.values, readStringOrNull(json['mechanism']), Mechanism.completion),
        lifecycle: enumFromName(Lifecycle.values, readStringOrNull(json['lifecycle']), Lifecycle.active),
        startDate: readDate(json['startDate']),
        dueDate: readDate(json['dueDate']),
        tags: readStringList(json['tags']),
        parentGoalId: readStringOrNull(json['parentGoalId']),
        weight: readDoubleOr(json['weight'], 1),
        isRequired: readBoolOr(json['isRequired'], true),
        sortOrder: readIntOr(json['sortOrder'], 0),
        statusOverride: enumFromName(
          ChildStatusOverride.values,
          readStringOrNull(json['statusOverride']),
          ChildStatusOverride.none,
        ),
        startValue: readDouble(json['startValue']),
        currentValue: readDouble(json['currentValue']),
        targetValue: readDouble(json['targetValue']),
        unit: readStringOr(json['unit'], ''),
        executionMode: enumFromName(
          ExecutionMode.values,
          readStringOrNull(json['executionMode']),
          ExecutionMode.parallel,
        ),
        stableWindow: readIntOr(json['stableWindow'], 3),
        isArchived: readBoolOr(json['isArchived'], false),
        isFocus: readBoolOr(json['isFocus'], false),
        noUpdateThresholdDays: readInt(json['noUpdateThresholdDays']),
        createdAt: readDate(json['createdAt']) ?? DateTime.now(),
        updatedAt: readDate(json['updatedAt']) ?? DateTime.now(),
      );

  final String id;
  String title;
  String why;
  String successCriteria;
  Mechanism mechanism;
  Lifecycle lifecycle;

  DateTime? startDate;
  DateTime? dueDate;

  /// 领域 / 标签：与机制、生命周期、时间范围正交，只用于筛选。
  List<String> tags;

  /// 最多一个父目标（防重复计算进度）。
  String? parentGoalId;

  /// 作为子项时的权重（只在同一个父目标下有效）。
  double weight;

  /// 作为子项时是否必需（决定里程碑的完成判定）。
  bool isRequired;

  int sortOrder;
  ChildStatusOverride statusOverride;

  /// 原始量：起始值 / 当前值 / 目标值。百分比只是派生展示。
  double? startValue;
  double? currentValue;
  double? targetValue;
  String unit;

  /// 里程碑的执行模式（并列 / 串行）。
  ExecutionMode executionMode;

  /// 指标型「稳定达标」所需的连续达标读数次数。
  int stableWindow;

  bool isArchived;

  /// 首页聚焦（软性引导，不做硬性上限校验）。
  bool isFocus;

  int? noUpdateThresholdDays;

  DateTime createdAt;
  DateTime updatedAt;

  bool get isCompleted => lifecycle == Lifecycle.completed;
  bool get isClosed => lifecycle.isClosed;

  /// 逾期是派生计算，不写入生命周期。
  bool isOverdue(DateTime now) =>
      dueDate != null && !isCompleted && now.isAfter(dueDate!);

  void touch() => updatedAt = DateTime.now();

  Goal clone() => Goal.fromJson(toJson());

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'title': title,
        'why': why,
        'successCriteria': successCriteria,
        'mechanism': mechanism.name,
        'lifecycle': lifecycle.name,
        'startDate': startDate?.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'tags': tags,
        'parentGoalId': parentGoalId,
        'weight': weight,
        'isRequired': isRequired,
        'sortOrder': sortOrder,
        'statusOverride': statusOverride.name,
        'startValue': startValue,
        'currentValue': currentValue,
        'targetValue': targetValue,
        'unit': unit,
        'executionMode': executionMode.name,
        'stableWindow': stableWindow,
        'isArchived': isArchived,
        'isFocus': isFocus,
        'noUpdateThresholdDays': noUpdateThresholdDays,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// 配置变更时用于生成可读的 diff。
  static Map<String, String> diff(Goal before, Goal after) {
    final Map<String, String> out = <String, String>{};
    void put(String key, Object? a, Object? b, String Function(Object?) fmt) {
      if (a != b) out[key] = '${fmt(a)} → ${fmt(b)}';
    }

    put('标题', before.title, after.title, (Object? v) => '$v');
    put('为什么', before.why, after.why, (Object? v) => '$v');
    put('达成条件', before.successCriteria, after.successCriteria, (Object? v) => '$v');
    put('机制', before.mechanism, after.mechanism, (Object? v) => (v as Mechanism).label);
    put('起始日', before.startDate, after.startDate, (Object? v) => v == null ? '无' : '$v'.substring(0, 10));
    put('截止日', before.dueDate, after.dueDate, (Object? v) => v == null ? '无' : '$v'.substring(0, 10));
    put('标签', before.tags.join('/'), after.tags.join('/'), (Object? v) => '$v');
    put('单位', before.unit, after.unit, (Object? v) => '$v');
    put('起始值', before.startValue, after.startValue, (Object? v) => v == null ? '无' : '$v');
    put('当前值', before.currentValue, after.currentValue, (Object? v) => v == null ? '无' : '$v');
    put('目标值', before.targetValue, after.targetValue, (Object? v) => v == null ? '无' : '$v');
    put('执行模式', before.executionMode, after.executionMode, (Object? v) => (v as ExecutionMode).label);
    put('稳定达标次数', before.stableWindow, after.stableWindow, (Object? v) => '$v');
    put('必需子项', before.isRequired, after.isRequired, (Object? v) => (v as bool) ? '是' : '否');
    put('权重', before.weight, after.weight, (Object? v) => '$v');
    return out;
  }
}
