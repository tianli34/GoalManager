/// 五种目标机制（mechanism）。
///
/// 机制决定：输入什么、进度怎么算、什么算完成。
enum Mechanism {
  /// 完成型：做完即达成，无中间进度。
  completion,

  /// 累积型：往一个总量上加，加到目标值。
  cumulative,

  /// 指标达成型：状态量从 A 到 B，读数会回退。
  metric,

  /// 主观/动态型：以时间线记录为主，进度由人主观判断。
  subjective,

  /// 里程碑/项目型：由子项组成，进度来自子项。
  milestone,
}

extension MechanismX on Mechanism {
  String get label => switch (this) {
        Mechanism.completion => '完成型',
        Mechanism.cumulative => '累积型',
        Mechanism.metric => '指标型',
        Mechanism.subjective => '主观型',
        Mechanism.milestone => '里程碑型',
      };

  /// 一句话说明这个机制的输入方式。
  String get inputHint => switch (this) {
        Mechanism.completion => '记录一次「完成」，可撤销',
        Mechanism.cumulative => '记录每次增量（可为负）',
        Mechanism.metric => '记录当前读数（覆盖式，保留历史）',
        Mechanism.subjective => '记录一条动态 + 手动自评百分比',
        Mechanism.milestone => '进度由子目标加权上卷，只读',
      };

  /// 完成判定说明。
  String get completionRule => switch (this) {
        Mechanism.completion => '你标记完成',
        Mechanism.cumulative => '累计量达到目标值',
        Mechanism.metric => '连续 N 次读数达标（稳定达标）',
        Mechanism.subjective => '你判断达成',
        Mechanism.milestone => '所有「必需」子项完成',
      };
}

/// 生命周期（lifecycle）。与进度、完成判定三者互相独立。
enum Lifecycle {
  pending,
  active,
  paused,
  completed,
  terminated,
}

extension LifecycleX on Lifecycle {
  String get label => switch (this) {
        Lifecycle.pending => '待开始',
        Lifecycle.active => '进行中',
        Lifecycle.paused => '暂停',
        Lifecycle.completed => '已完成',
        Lifecycle.terminated => '已终止',
      };

  bool get isClosed => this == Lifecycle.completed || this == Lifecycle.terminated;
}

/// 关注信号（attention signal）：派生出来的提示，不是状态。
enum AttentionSignal {
  /// 距上次记录超过阈值。
  noRecentUpdate,

  /// 有记录，但预期变化没有发生。
  possibleStall,

  /// 截止临近且计划进展明显落后。
  dateRisk,

  /// 样本不足，尚无法判断。
  insufficientData,
}

extension AttentionSignalX on AttentionSignal {
  String get label => switch (this) {
        AttentionSignal.noRecentUpdate => '久未更新',
        AttentionSignal.possibleStall => '疑似停滞',
        AttentionSignal.dateRisk => '日期风险',
        AttentionSignal.insufficientData => '尚无法判断',
      };

  /// 排序权重：越紧急越靠前。
  int get severity => switch (this) {
        AttentionSignal.dateRisk => 0,
        AttentionSignal.possibleStall => 1,
        AttentionSignal.noRecentUpdate => 2,
        AttentionSignal.insufficientData => 3,
      };
}

/// 复盘决定。
enum ReviewDecision {
  cont,
  adjust,
  pause,
  end,
}

extension ReviewDecisionX on ReviewDecision {
  String get label => switch (this) {
        ReviewDecision.cont => '继续',
        ReviewDecision.adjust => '调整',
        ReviewDecision.pause => '暂停',
        ReviewDecision.end => '结束',
      };
}

/// 更新记录类型：配置变更与真实推进必须区分。
enum RecordType {
  progress,
  configChange,
  reopen,
  lifecycleChange,
}

extension RecordTypeX on RecordType {
  String get label => switch (this) {
        RecordType.progress => '进度推进',
        RecordType.configChange => '配置变更',
        RecordType.reopen => '重新打开',
        RecordType.lifecycleChange => '状态变更',
      };
}

/// 里程碑子项执行模式。
enum ExecutionMode {
  /// 并列：所有子项同时激活，无先后。
  parallel,

  /// 串行：按顺序，前项达成后项才激活。
  sequential,
}

extension ExecutionModeX on ExecutionMode {
  String get label => switch (this) {
        ExecutionMode.parallel => '并列',
        ExecutionMode.sequential => '串行',
      };

  String get hint => switch (this) {
        ExecutionMode.parallel => '子项同时推进，无先后顺序',
        ExecutionMode.sequential => '按顺序推进，前一项达成后下一项才激活（软锁定，可提前开始）',
      };
}

/// 子项状态覆盖（串行提前激活 / 指标型固化）。
enum ChildStatusOverride {
  none,
  forceActive,
  frozen,
}

extension ChildStatusOverrideX on ChildStatusOverride {
  String get label => switch (this) {
        ChildStatusOverride.none => '默认',
        ChildStatusOverride.forceActive => '提前开始',
        ChildStatusOverride.frozen => '已固化',
      };
}

/// 承诺状态。
enum CommitmentStatus {
  active,
  fulfilled,
  adjusted,
  cancelled,
}

extension CommitmentStatusX on CommitmentStatus {
  String get label => switch (this) {
        CommitmentStatus.active => '进行中',
        CommitmentStatus.fulfilled => '已兑现',
        CommitmentStatus.adjusted => '已调整',
        CommitmentStatus.cancelled => '已取消',
      };
}

/// 收集箱处理结果。
enum InboxStatus { pending, converted, merged, discarded }

extension InboxStatusX on InboxStatus {
  String get label => switch (this) {
        InboxStatus.pending => '待处理',
        InboxStatus.converted => '已转为目标',
        InboxStatus.merged => '已并入目标',
        InboxStatus.discarded => '已舍弃',
      };
}

T enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final T v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
