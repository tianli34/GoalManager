import '../core/date_utils.dart';
import '../data/models/app_data.dart';
import '../data/models/enums.dart';
import '../data/models/goal.dart';
import '../data/models/update_record.dart';
import 'progress.dart';

/// 一条关注信号：必须附带「为什么」和一个具体操作入口。
class SignalItem {
  const SignalItem({
    required this.goalId,
    required this.goalTitle,
    required this.kind,
    required this.reason,
    required this.actionHint,
  });

  final String goalId;
  final String goalTitle;
  final AttentionSignal kind;
  final String reason;
  final String actionHint;
}

/// 停滞检测 / 关注信号。
///
/// 三条排除规则：
/// - 完成型长期 0% 不触发「疑似停滞」；
/// - 指标型样本不足时输出「尚无法判断」；
/// - 主观型只邀请自评；PAUSED 不产生任何提醒。
class SignalEngine {
  SignalEngine({required this.data, required this.progress, DateTime? now})
      : now = now ?? DateTime.now();

  final AppData data;
  final ProgressEngine progress;
  final DateTime now;

  List<SignalItem> forGoal(String goalId) {
    final Goal? goal = data.goalById(goalId);
    if (goal == null) return <SignalItem>[];
    // PAUSED（以及待开始 / 已关闭 / 已归档）不产生任何提醒。
    if (goal.lifecycle != Lifecycle.active) return <SignalItem>[];
    if (goal.isArchived) return <SignalItem>[];

    final List<SignalItem> out = <SignalItem>[];
    final List<UpdateRecord> progressRecords = data
        .recordsOf(goalId)
        .where((UpdateRecord r) => r.type == RecordType.progress)
        .toList();

    _checkNoRecentUpdate(goal, progressRecords, out);
    _checkStall(goal, progressRecords, out);
    _checkDateRisk(goal, out);
    return out;
  }

  /// 全部需要关注的目标（按紧急度排序）。
  List<SignalItem> all() {
    final List<SignalItem> out = <SignalItem>[];
    for (final Goal goal in data.goals) {
      out.addAll(forGoal(goal.id));
    }
    out.sort((SignalItem a, SignalItem b) {
      final int c = a.kind.severity.compareTo(b.kind.severity);
      return c != 0 ? c : a.goalTitle.compareTo(b.goalTitle);
    });
    return out;
  }

  // ------------------------------------------------------------------- 信号

  void _checkNoRecentUpdate(
    Goal goal,
    List<UpdateRecord> progressRecords,
    List<SignalItem> out,
  ) {
    // 里程碑的进度来自子项，自身没有记录是常态，不提示「久未更新」。
    if (goal.mechanism == Mechanism.milestone) return;
    final DateTime last = progressRecords.isEmpty
        ? goal.createdAt
        : progressRecords.last.timestamp;
    final int days = daysBetween(last, now);
    final int threshold = goal.noUpdateThresholdDays ?? data.settings.noUpdateDays;
    if (days > threshold) {
      out.add(SignalItem(
        goalId: goal.id,
        goalTitle: goal.title,
        kind: AttentionSignal.noRecentUpdate,
        reason: '距上次记录已 $days 天（阈值 $threshold 天）',
        actionHint: goal.mechanism == Mechanism.subjective
            ? '邀请你自评一次'
            : '更新一次进度，或确认无变化',
      ));
    }
  }

  void _checkStall(
    Goal goal,
    List<UpdateRecord> progressRecords,
    List<SignalItem> out,
  ) {
    // 完成型长期 0% 不算停滞；主观型只邀请自评；里程碑看子项（此处不判断）。
    if (goal.mechanism != Mechanism.cumulative &&
        goal.mechanism != Mechanism.metric) {
      return;
    }
    final DateTime? lastChange = _lastValueChangeAt(goal, progressRecords);
    if (lastChange == null) return;
    final int days = daysBetween(lastChange, now);
    if (days <= data.settings.stallDays) return;

    final int samples = progressRecords
        .where((UpdateRecord r) => r.reading != null)
        .length;
    if (goal.mechanism == Mechanism.metric &&
        samples < data.settings.metricMinSamples) {
      out.add(SignalItem(
        goalId: goal.id,
        goalTitle: goal.title,
        kind: AttentionSignal.insufficientData,
        reason: '读数 $samples 条 < ${data.settings.metricMinSamples} 条：尚无法判断是否停滞',
        actionHint: '继续记录读数，样本够了再看趋势',
      ));
      return;
    }
    out.add(SignalItem(
      goalId: goal.id,
      goalTitle: goal.title,
      kind: AttentionSignal.possibleStall,
      reason: '有记录，但最近 $days 天原始量没有变化（阈值 ${data.settings.stallDays} 天）',
      actionHint: '写一句说明，或检查计划是否需要调整',
    ));
  }

  void _checkDateRisk(Goal goal, List<SignalItem> out) {
    final DateTime? due = goal.dueDate;
    if (due == null || goal.isCompleted) return;
    final int daysLeft = daysBetween(now, due);
    if (daysLeft < 0) {
      out.add(SignalItem(
        goalId: goal.id,
        goalTitle: goal.title,
        kind: AttentionSignal.dateRisk,
        reason: '已过截止日 ${-daysLeft} 天，尚未完成',
        actionHint: '调整范围 / 日期 / 承诺，或结束这个目标',
      ));
      return;
    }
    if (daysLeft > data.settings.dateRiskDays) return;
    // 完成型只显示剩余时间，不做「落后」判断。
    if (goal.mechanism == Mechanism.completion) return;
    // 主观型不输出「落后 X%」。
    if (goal.mechanism == Mechanism.subjective) return;

    final ProgressSnapshot ps = progress.of(goal.id);
    final double? planned = ps.plannedPercent;
    if (planned == null) return;
    final double gap = planned - ps.percent;
    final double tolerance = data.settings.dateRiskTolerance * 100;
    if (gap <= tolerance) return;

    out.add(SignalItem(
      goalId: goal.id,
      goalTitle: goal.title,
      kind: AttentionSignal.dateRisk,
      reason: '还剩 $daysLeft 天：计划 ${fmtPercent(planned)} / 实际 ${fmtPercent(ps.percent)}，落后 ${fmtNum(gap)} 个百分点',
      actionHint: '调整范围 / 日期 / 承诺',
    ));
  }

  // ----------------------------------------------------------------- 小工具

  /// 最后一次「原始量真的变了」的时间。
  DateTime? _lastValueChangeAt(Goal goal, List<UpdateRecord> records) {
    DateTime? found;
    switch (goal.mechanism) {
      case Mechanism.cumulative:
        for (final UpdateRecord r in records) {
          if (r.delta != null && r.delta != 0) found = r.timestamp;
        }
        break;
      case Mechanism.metric:
        double? prevReading;
        for (final UpdateRecord r in records) {
          if (r.reading == null) continue;
          if (prevReading == null || r.reading != prevReading) {
            found = r.timestamp;
          }
          prevReading = r.reading;
        }
        break;
      case Mechanism.subjective:
        double? prevRating;
        for (final UpdateRecord r in records) {
          if (r.selfRating == null) continue;
          if (prevRating == null || r.selfRating != prevRating) {
            found = r.timestamp;
          }
          prevRating = r.selfRating;
        }
        break;
      case Mechanism.completion:
        for (final UpdateRecord r in records) {
          if (r.done == true) found = r.timestamp;
        }
        break;
      case Mechanism.milestone:
        break;
    }
    return found;
  }
}
