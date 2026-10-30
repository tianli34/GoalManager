import '../core/date_utils.dart';
import '../data/models/app_data.dart';
import '../data/models/commitment.dart';
import '../data/models/enums.dart';
import '../data/models/goal.dart';
import 'progress.dart';

/// 一条承诺的兑现情况。
class CommitmentEvaluation {
  const CommitmentEvaluation({
    required this.commitment,
    required this.goalTitle,
    required this.targetText,
    required this.actualText,
    required this.ratio,
    required this.fulfilled,
    this.expectationOnly = false,
  });

  final Commitment commitment;
  final String goalTitle;

  /// 承诺量的自然语义文本（按机制不同）。
  final String targetText;

  /// 自承诺创建以来的真实推进量。
  final String actualText;

  /// actual / target（用于进度条，界面自己截断）。
  final double ratio;

  /// 是否满足兑现条件。
  final bool fulfilled;

  /// 指标型：只是结果期望，未达不解读为投入不足。
  final bool expectationOnly;

  CommitmentStatus get status => commitment.status;
}

/// 承诺引擎。
///
/// 边界规则：
/// 1. 承诺未兑现 → 不改变目标 lifecycle，不标记失败。
/// 2. 调整 / 取消 → 追加历史，不覆盖删除。
/// 3. 用「创建时的快照」计算真实推进量，所以事后改目标值也不会让旧承诺自动兑现。
class CommitmentEngine {
  CommitmentEngine({required this.data, required this.progress, DateTime? now})
      : now = now ?? DateTime.now();

  final AppData data;
  final ProgressEngine progress;
  final DateTime now;

  List<Commitment> inWindow(DateWindow window) => data.commitments
      .where((Commitment c) =>
          !c.start.isAfter(window.end) && !c.end.isBefore(window.start))
      .toList()
    ..sort((Commitment a, Commitment b) => a.createdAt.compareTo(b.createdAt));

  List<Commitment> activeIn(DateTime at) => data.commitments
      .where((Commitment c) =>
          c.status == CommitmentStatus.active &&
          !c.start.isAfter(at) &&
          !c.end.isBefore(at))
      .toList();

  CommitmentEvaluation evaluate(Commitment c) {
    final Goal? goal = data.goalById(c.goalId);
    final String title = goal?.title ?? '（目标已删除）';
    if (goal == null) {
      return CommitmentEvaluation(
        commitment: c,
        goalTitle: title,
        targetText: '—',
        actualText: '—',
        ratio: 0,
        fulfilled: false,
      );
    }

    switch (goal.mechanism) {
      case Mechanism.cumulative:
        {
          final double target = c.targetDelta ?? 0;
          final double current = goal.currentValue ?? goal.startValue ?? 0;
          final double actual = current - c.baselineValue;
          return CommitmentEvaluation(
            commitment: c,
            goalTitle: title,
            targetText: _signed(target, goal.unit),
            actualText: '实际 ${_signed(actual, goal.unit)}',
            ratio: target == 0 ? 0 : actual / target,
            fulfilled: target != 0 && (actual / target) >= 1,
          );
        }
      case Mechanism.completion:
        {
          final DateTime? doneAt = data.completionTimeOf(goal.id);
          final bool done = doneAt != null && !doneAt.isBefore(c.createdAt);
          return CommitmentEvaluation(
            commitment: c,
            goalTitle: title,
            targetText: '完成这个目标',
            actualText: done ? '已完成' : '尚未完成',
            ratio: done ? 1 : 0,
            fulfilled: done,
          );
        }
      case Mechanism.subjective:
        {
          final double target = c.targetRatingPoints ?? 0;
          final double current = goal.currentValue ?? 0;
          final double actual = current - c.baselineValue;
          return CommitmentEvaluation(
            commitment: c,
            goalTitle: title,
            targetText: '自评推进 ${fmtNum(target.abs())} 点',
            actualText: '实际 ${_signed(actual, '%')}',
            ratio: target == 0 ? 0 : actual / target,
            fulfilled: target != 0 && (actual / target) >= 1,
          );
        }
      case Mechanism.milestone:
        {
          final String? childId = c.targetChildGoalId;
          final Goal? child = childId == null ? null : data.goalById(childId);
          final DateTime? doneAt =
              child == null ? null : data.completionTimeOf(child.id);
          final bool done = doneAt != null && !doneAt.isBefore(c.createdAt);
          return CommitmentEvaluation(
            commitment: c,
            goalTitle: title,
            targetText: child == null ? '完成指定子项' : '完成子项《${child.title}》',
            actualText: done ? '已完成' : '尚未完成',
            ratio: done ? 1 : 0,
            fulfilled: done,
          );
        }
      case Mechanism.metric:
        return CommitmentEvaluation(
          commitment: c,
          goalTitle: title,
          targetText: c.expectation.isEmpty ? '（结果期望未填写）' : c.expectation,
          actualText: '指标型承诺只作结果期望，未达不解读为投入不足',
          ratio: 0,
          fulfilled: false,
          expectationOnly: true,
        );
    }
  }

  String _signed(double v, String unit) {
    final String sign = v >= 0 ? '+' : '−';
    final String body = fmtQuantity(v.abs(), unit);
    return unit == '%' ? '$sign${fmtNum(v.abs())}%' : '$sign$body';
  }
}
