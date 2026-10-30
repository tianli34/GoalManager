import '../core/date_utils.dart';
import '../data/models/app_data.dart';
import '../data/models/enums.dart';
import '../data/models/goal.dart';
import '../data/models/update_record.dart';

/// 一个目标的进度快照：百分比只是派生展示，
/// 真正的「原始量」与「解释」都要一起交给界面。
class ProgressSnapshot {
  const ProgressSnapshot({
    required this.percent,
    required this.rawText,
    required this.isComplete,
    this.plannedPercent,
    this.timeElapsedRatio,
    this.paceText,
    this.projectedDate,
    this.dailyNeed,
    this.notes = const <String>[],
  });

  /// 进度百分比。**不截断** 负值与 >100 的值。
  final double percent;

  /// 计划（配速）进度：null 表示这个机制/这个目标无法给出计划值。
  final double? plannedPercent;

  /// 时间消耗比例（0~1，可大于 1）。
  final double? timeElapsedRatio;

  /// 原始量展示，例如 "350 / 500 页"。
  final String rawText;

  /// 配速说明（按机制给出：落后多少 / 每日还需 / 预计达成日 / 仅剩余时间）。
  final String? paceText;

  /// 指标型按趋势外推的预计达成日。
  final DateTime? projectedDate;

  /// 累积型「每日还需」的量（带方向）。
  final double? dailyNeed;

  /// 完成判定：与进度、生命周期三者互相独立。
  final bool isComplete;

  /// 给界面的解释文本（为什么是这个值）。
  final List<String> notes;

  /// 与计划的差距（正 = 超前，负 = 落后）；无法比较时为 null。
  double? get gapToPlan =>
      plannedPercent == null ? null : percent - plannedPercent!;
}

/// 进度计算引擎。
///
/// 三条底层不变量：
/// 1. 进度 ≠ 完成判定 ≠ 生命周期，三者分别存储 / 计算。
/// 2. COMPLETED 目标不自动重开；读数回退不改变已完成。
/// 3. 始终保留并展示原始量，不截断负值与 >100%。
class ProgressEngine {
  ProgressEngine({required this.data, DateTime? now})
      : now = now ?? DateTime.now();

  final AppData data;
  final DateTime now;

  final Map<String, ProgressSnapshot> _cache = <String, ProgressSnapshot>{};

  ProgressSnapshot of(String goalId) => _of(goalId, <String>{});

  ProgressSnapshot _of(String goalId, Set<String> visiting) {
    final ProgressSnapshot? cached = _cache[goalId];
    if (cached != null) return cached;
    final Goal? goal = data.goalById(goalId);
    if (goal == null) {
      return const ProgressSnapshot(
        percent: 0,
        rawText: '—',
        isComplete: false,
        notes: <String>['目标不存在'],
      );
    }
    if (visiting.contains(goalId)) {
      return const ProgressSnapshot(
        percent: 0,
        rawText: '—',
        isComplete: false,
        notes: <String>['检测到循环的父子关系，已停止上卷'],
      );
    }
    final ProgressSnapshot snapshot = _compute(goal, visiting);
    _cache[goalId] = snapshot;
    return snapshot;
  }

  /// 某个时间点上的原始量（回放记录得到，用于「本周期变化」）。
  double? rawValueAt(Goal goal, DateTime t) {
    final List<UpdateRecord> records = data.recordsOf(goal.id);
    switch (goal.mechanism) {
      case Mechanism.cumulative:
        {
          double v = goal.startValue ?? 0;
          for (final UpdateRecord r in records) {
            if (r.type == RecordType.progress &&
                r.delta != null &&
                !r.timestamp.isAfter(t)) {
              v += r.delta!;
            }
          }
          return v;
        }
      case Mechanism.metric:
        {
          double v = goal.startValue ?? 0;
          for (final UpdateRecord r in records) {
            if (r.type == RecordType.progress &&
                r.reading != null &&
                !r.timestamp.isAfter(t)) {
              v = r.reading!;
            }
          }
          return v;
        }
      case Mechanism.subjective:
        {
          double v = 0;
          for (final UpdateRecord r in records) {
            if (r.type == RecordType.progress &&
                r.selfRating != null &&
                !r.timestamp.isAfter(t)) {
              v = r.selfRating!;
            }
          }
          return v;
        }
      case Mechanism.completion:
        {
          double v = 0;
          for (final UpdateRecord r in records) {
            if (r.type == RecordType.progress &&
                r.done != null &&
                !r.timestamp.isAfter(t)) {
              v = r.done! ? 1 : 0;
            }
          }
          return v;
        }
      case Mechanism.milestone:
        return null;
    }
  }

  /// 某个时间点上的进度百分比（里程碑型无法回放，返回 null）。
  double? percentAt(Goal goal, DateTime t) {
    final double? raw = rawValueAt(goal, t);
    if (raw == null) return null;
    switch (goal.mechanism) {
      case Mechanism.cumulative:
      case Mechanism.metric:
        final double start = goal.startValue ?? 0;
        final double target = goal.targetValue ?? 0;
        final double span = target - start;
        if (span == 0) return null;
        return (raw - start) / span * 100;
      case Mechanism.subjective:
        return raw;
      case Mechanism.completion:
        return raw >= 1 ? 100 : 0;
      case Mechanism.milestone:
        return null;
    }
  }

  ProgressSnapshot _compute(Goal goal, Set<String> visiting) {
    switch (goal.mechanism) {
      case Mechanism.completion:
        return _completion(goal);
      case Mechanism.cumulative:
        return _cumulative(goal);
      case Mechanism.metric:
        return _metric(goal);
      case Mechanism.subjective:
        return _subjective(goal);
      case Mechanism.milestone:
        visiting.add(goal.id);
        try {
          return _milestone(goal, visiting);
        } finally {
          visiting.remove(goal.id);
        }
    }
  }

  // ---------------------------------------------------------------- 时间参照

  double? _elapsedRatio(Goal goal) {
    final DateTime? start = goal.startDate;
    final DateTime? due = goal.dueDate;
    if (start == null || due == null) return null;
    final double total =
        due.difference(start).inMicroseconds.toDouble();
    if (total <= 0) return null;
    final double passed = now.difference(start).inMicroseconds.toDouble();
    return passed / total;
  }

  static String _leftDaysText(DateTime now, DateTime due) {
    final int days = daysBetween(now, due);
    if (days < 0) return '已过截止日 ${-days} 天';
    if (days == 0) return '今天截止';
    return '还剩 $days 天';
  }

  // ----------------------------------------------------------------- 完成型

  ProgressSnapshot _completion(Goal goal) {
    final double percent = goal.isCompleted ? 100 : 0;
    final double? elapsed = _elapsedRatio(goal);
    final String pace = goal.dueDate == null
        ? '未设截止日'
        : (goal.isCompleted ? '已完成' : _leftDaysText(now, goal.dueDate!));
    return ProgressSnapshot(
      percent: percent,
      plannedPercent: null,
      timeElapsedRatio: elapsed,
      rawText: goal.isCompleted ? '已完成' : '未完成',
      paceText: pace,
      isComplete: goal.isCompleted,
      notes: <String>[
        '完成型只有 0% / 100%，不做「落后」判断',
        if (elapsed != null) '时间消耗 ${fmtPercent(elapsed * 100)}（只作剩余时间参照）',
      ],
    );
  }

  // ----------------------------------------------------------------- 累积型

  ProgressSnapshot _cumulative(Goal goal) {
    final double start = goal.startValue ?? 0;
    final double target = goal.targetValue ?? 0;
    final double current = goal.currentValue ?? start;
    final double span = target - start;
    final double percent =
        span == 0 ? 0 : (current - start) / span * 100;
    final double? elapsed = _elapsedRatio(goal);
    final double? planned = elapsed == null ? null : elapsed * 100;

    final bool reached = span >= 0 ? current >= target : current <= target;
    String pace;
    double? dailyNeed;
    if (goal.isCompleted) {
      pace = '已完成';
    } else if (goal.dueDate == null) {
      pace = '未设截止日，无法计算配速';
    } else if (reached) {
      pace = '已达到目标值';
    } else {
      final int daysLeft = daysBetween(now, goal.dueDate!);
      if (daysLeft < 0) {
        pace = '${_leftDaysText(now, goal.dueDate!)}，还差 ${fmtQuantity((target - current).abs(), goal.unit)}';
      } else {
        final int denom = daysLeft + 1; // 含今天
        dailyNeed = (target - current) / denom;
        final double? gap = planned == null ? null : percent - planned!;
        final List<String> parts = <String>[];
        if (gap != null) {
          parts.add(gap >= 0
              ? '超前 ${fmtNum(gap.abs())} 个百分点'
              : '落后 ${fmtNum(gap.abs())} 个百分点');
        }
        parts.add('每日还需 ${fmtQuantity(dailyNeed.abs(), goal.unit)}');
        pace = parts.join(' · ');
      }
    }

    final List<String> notes = <String>[
      '进度 =（当前 ${fmtNum(current)} − 起始 ${fmtNum(start)}）÷（目标 ${fmtNum(target)} − 起始 ${fmtNum(start)}）',
      '允许出现负值或超过 100%，不做截断',
      if (planned != null) '线性配速是「计划假设」，实际节奏由你判断',
      if (span == 0) '目标值与起始值相同，无法计算进度',
    ];

    return ProgressSnapshot(
      percent: percent,
      plannedPercent: planned,
      timeElapsedRatio: elapsed,
      rawText: '${fmtQuantity(current, goal.unit)} / ${fmtQuantity(target, goal.unit)}',
      paceText: pace,
      dailyNeed: dailyNeed,
      isComplete: reached,
      notes: notes,
    );
  }

  // ----------------------------------------------------------------- 指标型

  ProgressSnapshot _metric(Goal goal) {
    final List<UpdateRecord> readings = data
        .recordsOf(goal.id)
        .where((UpdateRecord r) =>
            r.type == RecordType.progress && r.reading != null)
        .toList();

    final double start = goal.startValue ?? (readings.isEmpty ? 0 : readings.first.reading!);
    final double target = goal.targetValue ?? 0;
    final double current = goal.currentValue ?? start;
    final double span = target - start;
    final double percent = span == 0 ? 0 : (current - start) / span * 100;
    final double? elapsed = _elapsedRatio(goal);
    final double? planned = elapsed == null ? null : elapsed * 100;

    final bool increasing = target >= start;
    final int window = goal.stableWindow < 1 ? 1 : goal.stableWindow;
    final bool stable = readings.length >= window &&
        readings
            .sublist(readings.length - window)
            .every((UpdateRecord r) =>
                increasing ? r.reading! >= target : r.reading! <= target);

    // 近期斜率（最近 5 条读数，最小二乘）
    double slope = 0;
    final List<UpdateRecord> pts = readings.length > 5
        ? readings.sublist(readings.length - 5)
        : readings;
    if (pts.length >= 2) {
      final DateTime x0 = pts.first.timestamp;
      double sx = 0, sy = 0, sxx = 0, sxy = 0;
      for (final UpdateRecord r in pts) {
        final double x =
            r.timestamp.difference(x0).inMicroseconds / Duration.microsecondsPerDay;
        final double y = r.reading!;
        sx += x;
        sy += y;
        sxx += x * x;
        sxy += x * y;
      }
      final double den = pts.length * sxx - sx * sx;
      if (den.abs() > 1e-9) {
        slope = (pts.length * sxy - sx * sy) / den;
      }
    }

    DateTime? projected;
    if (!stable && slope.abs() > 1e-9) {
      final double daysNeeded = (target - current) / slope;
      if (daysNeeded > 0 && daysNeeded < 3650) {
        projected = now.add(Duration(days: daysNeeded.round()));
      }
    }

    final int minSamples = data.settings.metricMinSamples;
    final List<String> parts = <String>[];
    if (goal.isCompleted) {
      parts.add('已达成');
    } else if (stable) {
      parts.add('已连续 $window 次读数达标（稳定达标）');
    } else if (projected != null) {
      parts.add('按近期趋势预计 ${fmtDateCn(projected)} 达标（约 ${daysBetween(now, projected)} 天）');
    } else if (readings.length < 2) {
      parts.add('读数不足，暂无趋势');
    } else {
      parts.add('近期无明显趋势');
    }
    if (planned != null) {
      parts.add('线性参考 ${fmtPercent(planned)}');
    }

    final List<String> notes = <String>[
      '进度 =（当前 ${fmtNum(current)} − 起始 ${fmtNum(start)}）÷（目标 ${fmtNum(target)} − 起始 ${fmtNum(start)}）',
      '读数会回退，这是滞后指标；一次读数到 100% 不算达成',
      '完成判定要求连续 $window 次读数达标',
      if (readings.length < minSamples)
        '读数样本 ${readings.length} 条 < $minSamples 条：趋势与稳定达标尚无法判断',
      '历史读数全部保留，覆盖式更新只改当前值',
    ];

    return ProgressSnapshot(
      percent: percent,
      plannedPercent: planned,
      timeElapsedRatio: elapsed,
      rawText: '${fmtQuantity(current, goal.unit)} → ${fmtQuantity(target, goal.unit)}',
      paceText: parts.join(' · '),
      projectedDate: projected,
      isComplete: stable || goal.isCompleted,
      notes: notes,
    );
  }

  // ----------------------------------------------------------------- 主观型

  ProgressSnapshot _subjective(Goal goal) {
    final double percent = goal.currentValue ?? 0;
    final double? elapsed = _elapsedRatio(goal);
    return ProgressSnapshot(
      percent: percent,
      plannedPercent: null,
      timeElapsedRatio: elapsed,
      rawText: '自评 ${fmtNum(clamp(percent, 0, 100))}%',
      paceText: null,
      isComplete: goal.isCompleted,
      notes: <String>[
        '进度完全来自你的自评，系统永不自动修改',
        if (elapsed != null)
          '时间消耗 ${fmtPercent(elapsed * 100)}：并排展示，不输出「落后 X%」',
      ],
    );
  }

  // --------------------------------------------------------------- 里程碑型

  ProgressSnapshot _milestone(Goal goal, Set<String> visiting) {
    final List<Goal> children = data.childrenOf(goal.id);
    final double? elapsed = _elapsedRatio(goal);
    if (children.isEmpty) {
      return ProgressSnapshot(
        percent: 0,
        plannedPercent: elapsed == null ? null : elapsed * 100,
        timeElapsedRatio: elapsed,
        rawText: '尚无子项',
        paceText: null,
        isComplete: false,
        notes: <String>[
          '父级进度由子目标加权上卷，不能直接填写百分比',
          '完成判定看「必需」子项是否全部完成',
        ],
      );
    }

    double sumWeight = 0;
    double sumProgress = 0;
    double sumPlannedWeight = 0;
    double sumPlanned = 0;
    int requiredTotal = 0;
    int requiredDone = 0;
    int doneCount = 0;
    bool cycleDetected = false;

    for (final Goal child in children) {
      final bool childIsCycle = visiting.contains(child.id);
      final ProgressSnapshot cs = childIsCycle
          ? const ProgressSnapshot(
              percent: 0,
              rawText: '—',
              isComplete: false,
              notes: <String>['检测到循环的父子关系，已停止上卷'],
            )
          : _of(child.id, visiting);
      if (childIsCycle || cs.notes.any((String n) => n.contains('循环'))) {
        cycleDetected = true;
      }
      final double w = child.weight < 0 ? 0 : child.weight;
      sumWeight += w;
      sumProgress += cs.percent * w;
      if (cs.plannedPercent != null) {
        sumPlanned += cs.plannedPercent! * w;
        sumPlannedWeight += w;
      }
      if (child.isCompleted) doneCount++;
      if (child.isRequired) {
        requiredTotal++;
        if (child.isCompleted) requiredDone++;
      }
    }

    final double percent = sumWeight == 0 ? 0 : sumProgress / sumWeight;
    final double? planned =
        sumPlannedWeight == 0 ? null : sumPlanned / sumPlannedWeight;
    final bool allRequiredDone =
        requiredTotal == 0 ? doneCount == children.length : requiredDone == requiredTotal;

    return ProgressSnapshot(
      percent: percent,
      plannedPercent: planned,
      timeElapsedRatio: elapsed,
      rawText: '子项 $doneCount / ${children.length} 完成',
      paceText: goal.executionMode == ExecutionMode.sequential
          ? '串行执行：按顺序推进，前一项达成后下一项才激活'
          : null,
      isComplete: allRequiredDone,
      notes: <String>[
        if (cycleDetected) '检测到循环的父子关系，已停止上卷',
        '父级进度 = Σ（子项进度 × 权重）÷ Σ权重，只读',
        '完成判定 = 全部「必需」子项完成（不是加权百分比 ≥ 100%）',
        if (requiredTotal == 0) '未标记任何必需子项，暂按「全部子项完成」判定',
        if (planned == null && elapsed != null) '子项缺少计划日期，只显示时间消耗',
      ],
    );
  }
}
