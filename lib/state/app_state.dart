import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/date_utils.dart';
import '../core/id.dart';
import '../data/export/export_service.dart';
import '../data/models/app_data.dart';
import '../data/models/commitment.dart';
import '../data/models/enums.dart';
import '../data/models/goal.dart';
import '../data/models/inbox_item.dart';
import '../data/models/review.dart';
import '../data/models/update_record.dart';
import '../data/storage/app_repository.dart';
import '../domain/commitments.dart';
import '../domain/milestone.dart';
import '../domain/progress.dart';
import 'seed_data.dart';

/// 应用状态：持有整份数据，所有写操作都经过这里，
/// 保证「记录 → 信号 → 复盘 → 决定」的闭环留下可解释的历史。
class AppState extends ChangeNotifier {
  AppState({required AppRepository repository}) : _repository = repository;

  final AppRepository _repository;

  AppData _data = AppData();
  bool _loaded = false;
  String? _error;

  bool get isLoaded => _loaded;
  String? get error => _error;
  AppData get data => _data;
  AppSettings get settings => _data.settings;

  // --------------------------------------------------------------- 引擎工厂

  ProgressEngine progressEngine([DateTime? now]) =>
      ProgressEngine(data: _data, now: now);

  MilestoneEngine milestoneEngine([DateTime? now]) =>
      MilestoneEngine(data: _data, progress: progressEngine(now), now: now);

  SignalEngine signalEngine([DateTime? now]) =>
      SignalEngine(data: _data, progress: progressEngine(now), now: now);

  CommitmentEngine commitmentEngine([DateTime? now]) =>
      CommitmentEngine(data: _data, progress: progressEngine(now), now: now);

  // ------------------------------------------------------------------ 生命周期

  Future<void> init() async {
    if (_loaded) return;
    final AppData? loaded = await _repository.load();
    _data = loaded ?? buildSeedData();
    _error = _repository.lastError;
    _loaded = true;
    if (loaded == null) await _persistNow();
    refreshCommitmentStatuses(silent: true);
    notifyListeners();
  }

  void _persist() {
    unawaited(_persistNow());
  }

  Future<void> _persistNow() async {
    try {
      await _repository.save(_data);
    } catch (e) {
      _error = '保存失败：$e';
    }
  }

  // -------------------------------------------------------------------- 目标

  List<Goal> get rootGoals => _data.goals
      .where((Goal g) => g.parentGoalId == null)
      .toList()
    ..sort((Goal a, Goal b) => a.createdAt.compareTo(b.createdAt));

  List<Goal> childrenOf(String id) => _data.childrenOf(id);

  Goal? goalById(String id) => _data.goalById(id);

  List<String> get allTags {
    final Set<String> tags = <String>{};
    for (final Goal g in _data.goals) {
      tags.addAll(g.tags);
    }
    final List<String> list = tags.toList()..sort();
    return list;
  }

  Goal createGoal({
    required String title,
    required Mechanism mechanism,
    String why = '',
    String successCriteria = '',
    Lifecycle lifecycle = Lifecycle.active,
    DateTime? startDate,
    DateTime? dueDate,
    List<String> tags = const <String>[],
    String? parentGoalId,
    double? startValue,
    double? currentValue,
    double? targetValue,
    String unit = '',
    ExecutionMode executionMode = ExecutionMode.parallel,
    int stableWindow = 3,
    bool isFocus = false,
  }) {
    int sortOrder = 0;
    if (parentGoalId != null) {
      final List<Goal> siblings = _data.childrenOf(parentGoalId);
      for (final Goal s in siblings) {
        if (s.sortOrder >= sortOrder) sortOrder = s.sortOrder + 100;
      }
      final Goal? parent = _data.goalById(parentGoalId);
      if (parent != null && parent.executionMode == ExecutionMode.sequential) {
        // 串行：第一项激活，其余待解锁。
        lifecycle = siblings.isEmpty ? Lifecycle.active : Lifecycle.pending;
      }
    }

    final Goal goal = Goal.create(
      title: title,
      mechanism: mechanism,
      why: why,
      successCriteria: successCriteria,
      lifecycle: lifecycle,
      startDate: startDate,
      dueDate: dueDate,
      tags: tags.toList(),
      parentGoalId: parentGoalId,
      sortOrder: sortOrder,
      startValue: startValue,
      currentValue: currentValue,
      targetValue: targetValue,
      unit: unit,
      executionMode: executionMode,
      stableWindow: stableWindow,
      isFocus: isFocus,
    );
    _data.goals.add(goal);
    _data.records.add(UpdateRecord.progress(
      goalId: goal.id,
      at: goal.createdAt,
      note: '创建目标（${mechanism.label}）',
    ));
    _persist();
    notifyListeners();
    return goal;
  }

  /// 更新目标定义。任何字段变化都会留下一条「配置变更」记录。
  void updateGoal(Goal updated, {String reason = ''}) {
    final int index = _data.goals.indexWhere((Goal g) => g.id == updated.id);
    if (index < 0) return;
    final Goal before = _data.goals[index];
    final Map<String, String> changes = Goal.diff(before, updated);
    updated.touch();
    _data.goals[index] = updated;
    if (changes.isNotEmpty) {
      _data.records.add(UpdateRecord.configChange(
        goalId: updated.id,
        at: DateTime.now(),
        changes: changes,
        reason: reason,
      ));
    }
    _persist();
    notifyListeners();
  }

  void deleteGoal(String id) {
    final List<String> ids = <String>[id];
    bool grew = true;
    // 级联删除所有子孙。
    while (grew) {
      grew = false;
      for (final Goal g in _data.goals) {
        if (g.parentGoalId != null &&
            ids.contains(g.parentGoalId) &&
            !ids.contains(g.id)) {
          ids.add(g.id);
          grew = true;
        }
      }
    }
    _data.goals.removeWhere((Goal g) => ids.contains(g.id));
    _data.records.removeWhere((UpdateRecord r) => ids.contains(r.goalId));
    _data.commitments
        .removeWhere((Commitment c) => ids.contains(c.goalId));
    for (final Review r in _data.reviews) {
      r.goalIds.removeWhere((String gid) => ids.contains(gid));
    }
    _persist();
    notifyListeners();
  }

  void setLifecycle(String id, Lifecycle next, {String reason = ''}) {
    final Goal? goal = _data.goalById(id);
    if (goal == null || goal.lifecycle == next) return;
    _setLifecycleInternal(goal, next, reason);
    _persist();
    notifyListeners();
  }

  void _setLifecycleInternal(Goal goal, Lifecycle next, String reason) {
    final Lifecycle from = goal.lifecycle;
    goal.lifecycle = next;
    goal.touch();
    _data.records.add(UpdateRecord.lifecycleChange(
      goalId: goal.id,
      at: DateTime.now(),
      from: from,
      to: next,
      reason: reason,
    ));
    if (next == Lifecycle.completed) {
      _freezeMetricIfNeeded(goal);
      _activateNextSibling(goal);
    }
  }

  /// 已完成的目标不会自动重开：必须显式重新打开，并留下原因。
  void reopenGoal(String id, {String reason = ''}) {
    final Goal? goal = _data.goalById(id);
    if (goal == null) return;
    final Lifecycle from = goal.lifecycle;
    goal.lifecycle = Lifecycle.active;
    goal.statusOverride = ChildStatusOverride.none;
    goal.touch();
    _data.records.add(UpdateRecord.reopen(
      goalId: id,
      at: DateTime.now(),
      reason: reason,
    ));
    if (from != Lifecycle.active) {
      _data.records.add(UpdateRecord.lifecycleChange(
        goalId: id,
        at: DateTime.now(),
        from: from,
        to: Lifecycle.active,
        reason: reason,
      ));
    }
    _persist();
    notifyListeners();
  }

  void toggleFocus(String id) {
    final Goal? goal = _data.goalById(id);
    if (goal == null) return;
    goal.isFocus = !goal.isFocus;
    goal.touch();
    _persist();
    notifyListeners();
  }

  void toggleArchive(String id) {
    final Goal? goal = _data.goalById(id);
    if (goal == null) return;
    goal.isArchived = !goal.isArchived;
    goal.touch();
    _persist();
    notifyListeners();
  }

  void setExecutionMode(String id, ExecutionMode mode) {
    final Goal? goal = _data.goalById(id);
    if (goal == null || goal.executionMode == mode) return;
    goal.executionMode = mode;
    goal.touch();
    _data.records.add(UpdateRecord.configChange(
      goalId: id,
      at: DateTime.now(),
      changes: <String, String>{'执行模式': '${mode == ExecutionMode.sequential ? '并列 → 串行' : '串行 → 并列'}'},
    ));
    _persist();
    notifyListeners();
  }

  // ------------------------------------------------------------- 里程碑子项

  void moveChild(String id, int direction) {
    final Goal? goal = _data.goalById(id);
    if (goal == null || goal.parentGoalId == null) return;
    final List<Goal> siblings = _data.childrenOf(goal.parentGoalId!);
    final int index = siblings.indexWhere((Goal g) => g.id == id);
    final int target = index + direction;
    if (index < 0 || target < 0 || target >= siblings.length) return;
    final int a = siblings[index].sortOrder;
    final int b = siblings[target].sortOrder;
    siblings[index].sortOrder = b;
    siblings[target].sortOrder = a;
    for (final Goal s in siblings) {
      s.touch();
    }
    _persist();
    notifyListeners();
  }

  void updateChildLink(
    String id, {
    double? weight,
    bool? isRequired,
    ChildStatusOverride? override,
  }) {
    final Goal? goal = _data.goalById(id);
    if (goal == null) return;
    final Map<String, String> changes = <String, String>{};
    if (weight != null && weight != goal.weight) {
      changes['权重'] = '${fmtNum(goal.weight)} → ${fmtNum(weight)}';
      goal.weight = weight;
    }
    if (isRequired != null && isRequired != goal.isRequired) {
      changes['必需子项'] = '${goal.isRequired ? '是' : '否'} → ${isRequired ? '是' : '否'}';
      goal.isRequired = isRequired;
    }
    if (override != null && override != goal.statusOverride) {
      changes['子项状态'] = '${goal.statusOverride.label} → ${override.label}';
      goal.statusOverride = override;
    }
    if (changes.isEmpty) return;
    goal.touch();
    _data.records.add(UpdateRecord.configChange(
      goalId: id,
      at: DateTime.now(),
      changes: changes,
    ));
    _persist();
    notifyListeners();
  }

  /// 软锁定：允许用户手动「提前开始」，系统允许同时存在多个进行中。
  void forceStartChild(String id) {
    final Goal? goal = _data.goalById(id);
    if (goal == null) return;
    updateChildLink(id, override: ChildStatusOverride.forceActive);
    if (goal.lifecycle == Lifecycle.pending) {
      setLifecycle(id, Lifecycle.active, reason: '串行子项手动提前开始');
    } else {
      notifyListeners();
    }
  }

  /// 指标型固化：达标后锁定，避免串行链反复横跳。
  void freezeChild(String id) {
    final Goal? goal = _data.goalById(id);
    if (goal == null) return;
    updateChildLink(id, override: ChildStatusOverride.frozen);
    if (!goal.isCompleted) {
      setLifecycle(id, Lifecycle.completed, reason: '手动固化（停止接收新读数）');
    } else {
      notifyListeners();
    }
  }

  void unfreezeChild(String id) =>
      updateChildLink(id, override: ChildStatusOverride.none);

  /// 串行：前一项完成后自动激活下一项。
  void _activateNextSibling(Goal completed) {
    if (completed.parentGoalId == null) return;
    final Goal? parent = _data.goalById(completed.parentGoalId!);
    if (parent == null || parent.executionMode != ExecutionMode.sequential) {
      return;
    }
    final List<Goal> siblings = _data.childrenOf(parent.id);
    final int index = siblings.indexWhere((Goal g) => g.id == completed.id);
    if (index < 0 || index + 1 >= siblings.length) return;
    final Goal next = siblings[index + 1];
    if (next.lifecycle == Lifecycle.pending) {
      // 直接改生命周期，不再额外触发上卷逻辑。
      next.lifecycle = Lifecycle.active;
      next.touch();
      _data.records.add(UpdateRecord.lifecycleChange(
        goalId: next.id,
        at: DateTime.now(),
        from: Lifecycle.pending,
        to: Lifecycle.active,
        reason: '前一项「${completed.title}」已完成，自动激活',
      ));
    }
  }

  void _freezeMetricIfNeeded(Goal goal) {
    if (goal.mechanism != Mechanism.metric) return;
    if (goal.parentGoalId == null) return;
    final Goal? parent = _data.goalById(goal.parentGoalId!);
    if (parent == null || parent.executionMode != ExecutionMode.sequential) {
      return;
    }
    goal.statusOverride = ChildStatusOverride.frozen;
  }

  // ------------------------------------------------------------- 进度记录

  void recordCompletion(String id, bool done, {String note = ''}) {
    final Goal? goal = _data.goalById(id);
    if (goal == null) return;
    _addRecord(UpdateRecord.progress(
      goalId: id,
      at: DateTime.now(),
      done: done,
      note: note,
    ));
    if (done) {
      _setLifecycleInternal(goal, Lifecycle.completed, note.isEmpty ? '标记完成' : note);
    } else if (goal.isCompleted) {
      // 撤销完成：回到进行中，并留下 REOPEN 语义的记录。
      goal.lifecycle = Lifecycle.active;
      goal.statusOverride = ChildStatusOverride.none;
      goal.touch();
      _data.records.add(UpdateRecord.reopen(goalId: id, at: DateTime.now(), reason: note));
    }
    _afterChange(goal);
    _persist();
    notifyListeners();
  }

  void recordDelta(String id, double delta, {String note = '', DateTime? at}) {
    final Goal? goal = _data.goalById(id);
    if (goal == null) return;
    final double base = goal.currentValue ?? goal.startValue ?? 0;
    goal.currentValue = base + delta;
    goal.touch();
    _addRecord(UpdateRecord.progress(
      goalId: id,
      at: at ?? DateTime.now(),
      delta: delta,
      note: note,
    ));
    _afterChange(goal);
  }

  void recordReading(String id, double reading,
      {String note = '', DateTime? at}) {
    final Goal? goal = _data.goalById(id);
    if (goal == null) return;
    if (goal.startValue == null) goal.startValue = reading;
    // 覆盖式更新只改当前值，历史读数全部保留。
    goal.currentValue = reading;
    goal.touch();
    _addRecord(UpdateRecord.progress(
      goalId: id,
      at: at ?? DateTime.now(),
      reading: reading,
      note: note,
    ));
    _afterChange(goal);
  }

  void recordRating(String id, double rating,
      {String note = '', DateTime? at}) {
    final Goal? goal = _data.goalById(id);
    if (goal == null) return;
    goal.currentValue = rating;
    goal.touch();
    _addRecord(UpdateRecord.progress(
      goalId: id,
      at: at ?? DateTime.now(),
      selfRating: rating,
      note: note,
    ));
    _afterChange(goal);
  }

  /// 写一句说明（对应「疑似停滞 → 写说明」）。
  void addNote(String id, String note) {
    if (note.trim().isEmpty) return;
    _addRecord(UpdateRecord.progress(
      goalId: id,
      at: DateTime.now(),
      note: note,
    ));
    _persist();
    notifyListeners();
  }

  /// 确认无变化（对应「久未更新 → 确认无变化」）：重置计时，不改原始量。
  void confirmNoChange(String id) {
    _addRecord(UpdateRecord.progress(
      goalId: id,
      at: DateTime.now(),
      note: '确认无变化',
    ));
    _persist();
    notifyListeners();
  }

  void _addRecord(UpdateRecord record) {
    _data.records.add(record);
  }

  /// 每次真实推进之后：判断是否达到完成条件，并刷新承诺兑现状态。
  void _afterChange(Goal goal) {
    _autoCompleteIfSatisfied(goal);
    refreshCommitmentStatuses(silent: true);
    _persist();
    notifyListeners();
  }

  void _autoCompleteIfSatisfied(Goal goal) {
    if (goal.lifecycle != Lifecycle.active) return;
    // 完成型与主观型由用户判断，不自动完成。
    if (goal.mechanism == Mechanism.completion ||
        goal.mechanism == Mechanism.subjective) {
      return;
    }
    final ProgressSnapshot ps = progressEngine().of(goal.id);
    if (!ps.isComplete) return;
    if (goal.mechanism == Mechanism.metric) {
      _setLifecycleInternal(goal, Lifecycle.completed, '连续 ${goal.stableWindow} 次读数达标（稳定达标）');
    } else if (goal.mechanism == Mechanism.cumulative) {
      _setLifecycleInternal(goal, Lifecycle.completed, '累计量达到目标值');
    } else if (goal.mechanism == Mechanism.milestone) {
      _setLifecycleInternal(goal, Lifecycle.completed, '必需子项全部完成');
    }
  }

  // -------------------------------------------------------------------- 承诺

  Commitment addCommitment({
    required String goalId,
    required DateTime start,
    required DateTime end,
    double? targetDelta,
    bool targetDone = false,
    double? targetRatingPoints,
    String? targetChildGoalId,
    String expectation = '',
    String note = '',
  }) {
    final Goal? goal = _data.goalById(goalId);
    final double baseline;
    if (goal == null) {
      baseline = 0;
    } else if (goal.mechanism == Mechanism.cumulative ||
        goal.mechanism == Mechanism.metric ||
        goal.mechanism == Mechanism.subjective) {
      baseline = goal.currentValue ?? goal.startValue ?? 0;
    } else {
      baseline = 0;
    }
    final Commitment commitment = Commitment(
      id: newId('cmt'),
      goalId: goalId,
      start: startOfDay(start),
      end: endOfDay(end),
      targetDelta: targetDelta,
      targetDone: targetDone,
      targetRatingPoints: targetRatingPoints,
      targetChildGoalId: targetChildGoalId,
      expectation: expectation,
      note: note,
      baselineValue: baseline,
      createdAt: DateTime.now(),
    );
    _data.commitments.add(commitment);
    _persist();
    notifyListeners();
    return commitment;
  }

  void markCommitmentFulfilled(String id) {
    final Commitment? c = _findCommitment(id);
    if (c == null || c.status == CommitmentStatus.fulfilled) return;
    c.addChange(c.status, CommitmentStatus.fulfilled, '手动标记兑现');
    c.status = CommitmentStatus.fulfilled;
    _persist();
    notifyListeners();
  }

  /// 调整：旧承诺保留为历史（状态 → 已调整），由界面再建一条新的。
  void adjustCommitment(String id, String reason) {
    final Commitment? c = _findCommitment(id);
    if (c == null || c.status != CommitmentStatus.active) return;
    c.addChange(c.status, CommitmentStatus.adjusted, reason);
    c.status = CommitmentStatus.adjusted;
    _persist();
    notifyListeners();
  }

  void cancelCommitment(String id, String reason) {
    final Commitment? c = _findCommitment(id);
    if (c == null || c.status != CommitmentStatus.active) return;
    c.addChange(c.status, CommitmentStatus.cancelled, reason);
    c.status = CommitmentStatus.cancelled;
    _persist();
    notifyListeners();
  }

  Commitment? _findCommitment(String id) {
    for (final Commitment c in _data.commitments) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 真实推进量达到承诺量时自动兑现（基于创建时的快照，不会被后续改配置污染）。
  void refreshCommitmentStatuses({bool silent = false}) {
    final CommitmentEngine engine = commitmentEngine();
    bool changed = false;
    for (final Commitment c in _data.commitments) {
      if (c.status != CommitmentStatus.active) continue;
      final CommitmentEvaluation e = engine.evaluate(c);
      if (e.fulfilled) {
        c.addChange(c.status, CommitmentStatus.fulfilled, '推进量达到承诺量，自动兑现');
        c.status = CommitmentStatus.fulfilled;
        changed = true;
      }
    }
    if (changed && !silent) {
      _persist();
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------- 复盘

  Review addReview({
    required DateTime start,
    required DateTime end,
    required List<String> goalIds,
    required String whatHappened,
    required String stillWorth,
    required bool? stillWorthAnswer,
    required ReviewDecision decision,
    String? nextStep,
  }) {
    final Review review = Review(
      id: newId('rev'),
      start: startOfDay(start),
      end: endOfDay(end),
      goalIds: goalIds,
      whatHappened: whatHappened,
      stillWorth: stillWorth,
      stillWorthAnswer: stillWorthAnswer,
      decision: decision,
      nextStep: nextStep,
    );
    _data.reviews.add(review);
    _persist();
    notifyListeners();
    return review;
  }

  /// 把复盘决定落到目标生命周期上（显式执行，不自动生效）。
  void applyReviewDecision(String reviewId) {
    final Review? review = _findReview(reviewId);
    if (review == null) return;
    for (final String goalId in review.goalIds) {
      final Goal? goal = _data.goalById(goalId);
      if (goal == null || goal.isClosed) continue;
      switch (review.decision) {
        case ReviewDecision.pause:
          setLifecycle(goalId, Lifecycle.paused, reason: '复盘决定：暂停');
          break;
        case ReviewDecision.end:
          setLifecycle(goalId, Lifecycle.terminated, reason: '复盘决定：结束');
          break;
        case ReviewDecision.cont:
        case ReviewDecision.adjust:
          break;
      }
    }
    notifyListeners();
  }

  Review? _findReview(String id) {
    for (final Review r in _data.reviews) {
      if (r.id == id) return r;
    }
    return null;
  }

  // ------------------------------------------------------------------ 收集箱

  InboxItem capture(String text) {
    final InboxItem item = InboxItem.capture(text);
    _data.inbox.insert(0, item);
    _persist();
    notifyListeners();
    return item;
  }

  void discardInboxItem(String id) {
    final InboxItem? item = _findInbox(id);
    if (item == null) return;
    item.status = InboxStatus.discarded;
    item.resolvedAt = DateTime.now();
    _persist();
    notifyListeners();
  }

  /// 把收集箱条目并入已有目标：作为一条说明记录。
  void mergeInboxItem(String id, String goalId) {
    final InboxItem? item = _findInbox(id);
    if (item == null) return;
    item.status = InboxStatus.merged;
    item.resolvedGoalId = goalId;
    item.resolvedAt = DateTime.now();
    _addRecord(UpdateRecord.progress(
      goalId: goalId,
      at: DateTime.now(),
      note: '来自收集箱：${item.text}',
    ));
    _persist();
    notifyListeners();
  }

  /// 把收集箱条目转成一个新目标。
  Goal convertInboxItemToGoal(
    String id, {
    required Mechanism mechanism,
    Lifecycle lifecycle = Lifecycle.active,
    DateTime? dueDate,
    List<String> tags = const <String>[],
    double? targetValue,
    String unit = '',
  }) {
    final InboxItem? item = _findInbox(id);
    final String title = item?.text ?? '';
    final Goal goal = createGoal(
      title: title,
      mechanism: mechanism,
      lifecycle: lifecycle,
      dueDate: dueDate,
      tags: tags,
      targetValue: targetValue,
      unit: unit,
      startValue: mechanism == Mechanism.cumulative ? 0 : null,
      currentValue: mechanism == Mechanism.cumulative ? 0 : null,
    );
    if (item != null) {
      item.status = InboxStatus.converted;
      item.resolvedGoalId = goal.id;
      item.resolvedAt = DateTime.now();
      _persist();
      notifyListeners();
    }
    return goal;
  }

  InboxItem? _findInbox(String id) {
    for (final InboxItem i in _data.inbox) {
      if (i.id == id) return i;
    }
    return null;
  }

  // ------------------------------------------------------------ 设置与备份

  void updateSettings(AppSettings next) {
    _data.settings = next;
    _persist();
    notifyListeners();
  }

  String exportJson() => ExportService(data: _data).toJsonString();

  String exportMarkdown() =>
      ExportService(data: _data, progress: progressEngine()).toMarkdown();

  Future<String?> exportJsonToFile() =>
      ExportService(data: _data).saveJsonToFile();

  Future<String?> exportMarkdownToFile() =>
      ExportService(data: _data, progress: progressEngine()).saveMarkdownToFile();

  /// 导入备份：整份替换（导入前请先导出当前数据）。
  void importData(String raw) {
    final AppData parsed = ExportService.parse(raw);
    _data = parsed;
    _error = null;
    _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _data = AppData();
    await _persistNow();
    notifyListeners();
  }

  Future<void> loadSampleData() async {
    _data = buildSeedData();
    await _persistNow();
    notifyListeners();
  }
}
