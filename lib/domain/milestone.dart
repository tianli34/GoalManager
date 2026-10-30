import '../core/date_utils.dart';
import '../data/models/app_data.dart';
import '../data/models/enums.dart';
import '../data/models/goal.dart';
import 'progress.dart';

/// 串行模式下子项的生命周期：待解锁 → 进行中 → 已完成。
enum MilestoneChildState {
  /// 已达成。
  completed,

  /// 当前聚焦（串行）或已激活（并列）。
  active,

  /// 待解锁：默认隐藏录入入口（软锁定，可强制提前开始）。
  locked,

  /// 已完成但原始量回退，出现异常（不回退锁定）。
  regression,

  /// 指标型固化：达标后锁定，新读数不再影响完成状态。
  frozen,
}

extension MilestoneChildStateX on MilestoneChildState {
  String get label => switch (this) {
        MilestoneChildState.completed => '已完成',
        MilestoneChildState.active => '进行中',
        MilestoneChildState.locked => '待解锁',
        MilestoneChildState.regression => '已完成后回退',
        MilestoneChildState.frozen => '已固化',
      };

  bool get acceptsInput =>
      this == MilestoneChildState.active ||
      this == MilestoneChildState.regression;
}

/// 子项在界面上的视图（含进度、状态、配速）。
class MilestoneChildView {
  const MilestoneChildView({
    required this.goal,
    required this.progress,
    required this.state,
    required this.index,
    this.isFocus = false,
    this.expectedPercent,
    this.paceText,
  });

  final Goal goal;
  final ProgressSnapshot progress;

  /// 串行下的序号（从 1 开始）。
  final int index;
  final MilestoneChildState state;

  /// 串行模式下的「当前聚焦」项。
  final bool isFocus;

  /// 串行挤压后的预期进度。
  final double? expectedPercent;

  final String? paceText;

  String get displayTitle => goal.title;
}

/// 里程碑（复合模型）的排序、软锁定与配速。
class MilestoneEngine {
  MilestoneEngine({required this.data, required this.progress, DateTime? now})
      : now = now ?? DateTime.now();

  final AppData data;
  final ProgressEngine progress;
  final DateTime now;

  List<MilestoneChildView> childrenOf(String parentId) {
    final Goal? parent = data.goalById(parentId);
    final List<Goal> children = data.childrenOf(parentId);
    if (children.isEmpty) return <MilestoneChildView>[];

    final bool sequential = parent?.executionMode == ExecutionMode.sequential;
    final List<MilestoneChildView> out = <MilestoneChildView>[];

    // 串行：前一项达成后，后一项才激活。
    bool locked = false;
    for (int i = 0; i < children.length; i++) {
      final Goal child = children[i];
      final ProgressSnapshot ps = progress.of(child.id);
      late final MilestoneChildState state;
      bool isFocus = false;

      if (child.statusOverride == ChildStatusOverride.frozen) {
        state = MilestoneChildState.frozen;
      } else if (child.isCompleted) {
        // 已解锁不回退锁定：只在当前项显示异常警告。
        state = ps.percent >= 99.999
            ? MilestoneChildState.completed
            : MilestoneChildState.regression;
      } else if (!sequential) {
        state = MilestoneChildState.active;
      } else if (!locked) {
        state = MilestoneChildState.active;
        if (out.every((MilestoneChildView v) => !v.isFocus)) isFocus = true;
        locked = true;
      } else if (child.statusOverride == ChildStatusOverride.forceActive) {
        state = MilestoneChildState.active;
      } else {
        state = MilestoneChildState.locked;
      }

      out.add(MilestoneChildView(
        goal: child,
        progress: ps,
        state: state,
        index: i + 1,
        isFocus: isFocus,
        expectedPercent: isFocus ? _sequentialExpected(children, i, parent) : null,
        paceText: isFocus ? _sequentialPace(children, i, parent) : ps.paceText,
      ));
    }
    return out;
  }

  /// 串行下的「当前聚焦」子项。
  MilestoneChildView? focusOf(String parentId) {
    for (final MilestoneChildView v in childrenOf(parentId)) {
      if (v.isFocus) return v;
    }
    return null;
  }

  // ------------------------------------------------------- 串行的时间线切分

  /// 串行：按权重隐式切分时间线；前项延期会把剩余时间挤压给后面的子项，
  /// 于是当前项激活时日配速自动上调。
  DateTime? _parentDue(Goal? parent) => parent?.dueDate;

  double _sequentialSliceDays(List<Goal> children, int index, Goal? parent) {
    final DateTime? due = _parentDue(parent);
    if (due == null) return 0;
    final int remainingDays = daysBetween(now, due);
    if (remainingDays <= 0) return 0;

    double remainingWeight = 0;
    for (int i = index; i < children.length; i++) {
      if (!children[i].isCompleted) {
        remainingWeight += children[i].weight < 0 ? 0 : children[i].weight;
      }
    }
    if (remainingWeight <= 0) return 0;
    final double self = children[index].weight < 0 ? 0 : children[index].weight;
    return remainingDays * (self / remainingWeight);
  }

  DateTime _sliceStart(List<Goal> children, int index, Goal? parent) {
    if (index == 0) return parent?.startDate ?? children[index].createdAt;
    final DateTime? prevDone = data.completionTimeOf(children[index - 1].id);
    if (prevDone != null) return prevDone;
    return parent?.startDate ?? children[index].createdAt;
  }

  double? _sequentialExpected(List<Goal> children, int index, Goal? parent) {
    if (_parentDue(parent) == null) return null;
    final double sliceDays = _sequentialSliceDays(children, index, parent);
    if (sliceDays <= 0) return 100;
    final DateTime start = _sliceStart(children, index, parent);
    final DateTime end = start.add(Duration(days: sliceDays.round()));
    final double total = end.difference(start).inMicroseconds.toDouble();
    if (total <= 0) return 100;
    final double passed = now.difference(start).inMicroseconds.toDouble();
    return clamp(passed / total * 100, -1000, 1000);
  }

  String? _sequentialPace(List<Goal> children, int index, Goal? parent) {
    final double? expected = _sequentialExpected(children, index, parent);
    if (expected == null) return null;
    final double sliceDays = _sequentialSliceDays(children, index, parent);
    final double gap = progress.of(children[index].id).percent - expected;
    final List<String> parts = <String>[];
    if (sliceDays <= 0) {
      parts.add('时间已用完');
    } else {
      parts.add('本段约 ${fmtNum(sliceDays)} 天，预期 ${fmtPercent(expected)}');
    }
    parts.add(gap >= 0
        ? '超前 ${fmtNum(gap.abs())} 个百分点'
        : '落后 ${fmtNum(gap.abs())} 个百分点');
    return parts.join(' · ');
  }
}
