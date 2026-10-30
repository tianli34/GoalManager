import 'package:goal_manager/data/models/app_data.dart';
import 'package:goal_manager/data/models/enums.dart';
import 'package:goal_manager/data/models/goal.dart';
import 'package:goal_manager/data/models/update_record.dart';

/// 测试用的固定「现在」，避免依赖真实时间。
final DateTime now = DateTime(2026, 6, 1, 10);

AppData dataWith(
  List<Goal> goals, [
  List<UpdateRecord> records = const <UpdateRecord>[],
]) {
  final AppData data = AppData();
  data.goals.addAll(goals);
  data.records.addAll(records);
  return data;
}

/// 建一个目标，id 与 title 相同，方便断言。
Goal goal(
  String id, {
  Mechanism mechanism = Mechanism.completion,
  Lifecycle lifecycle = Lifecycle.active,
  double? startValue,
  double? currentValue,
  double? targetValue,
  DateTime? startDate,
  DateTime? dueDate,
  String? parentGoalId,
  double weight = 1,
  bool isRequired = true,
  int sortOrder = 0,
  int stableWindow = 3,
  String unit = '',
  ExecutionMode executionMode = ExecutionMode.parallel,
  ChildStatusOverride statusOverride = ChildStatusOverride.none,
}) =>
    Goal.create(
      id: id,
      title: id,
      mechanism: mechanism,
      lifecycle: lifecycle,
      startValue: startValue,
      currentValue: currentValue,
      targetValue: targetValue,
      startDate: startDate,
      dueDate: dueDate,
      parentGoalId: parentGoalId,
      weight: weight,
      isRequired: isRequired,
      sortOrder: sortOrder,
      stableWindow: stableWindow,
      unit: unit,
      executionMode: executionMode,
    )..statusOverride = statusOverride;

UpdateRecord rec(
  String goalId, {
  required DateTime at,
  double? delta,
  double? reading,
  double? rating,
  bool? done,
  String note = '',
}) =>
    UpdateRecord.progress(
      goalId: goalId,
      at: at,
      delta: delta,
      reading: reading,
      selfRating: rating,
      done: done,
      note: note,
    );
