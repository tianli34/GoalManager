import 'package:flutter_test/flutter_test.dart';
import 'package:goal_manager/core/date_utils.dart';
import 'package:goal_manager/data/models/app_data.dart';
import 'package:goal_manager/data/models/commitment.dart';
import 'package:goal_manager/data/models/enums.dart';
import 'package:goal_manager/data/models/goal.dart';
import 'package:goal_manager/data/models/update_record.dart';
import 'package:goal_manager/domain/commitments.dart';
import 'package:goal_manager/domain/progress.dart';

import '../helpers.dart';

CommitmentEngine engineFor(
  List<Goal> goals,
  List<Commitment> commitments, [
  List<UpdateRecord> records = const <UpdateRecord>[],
]) {
  final AppData data = dataWith(goals, records);
  data.commitments.addAll(commitments);
  return CommitmentEngine(
    data: data,
    progress: ProgressEngine(data: data, now: now),
    now: now,
  );
}

Commitment commitment(
  String goalId, {
  double? targetDelta,
  bool targetDone = false,
  double? targetRatingPoints,
  String? targetChildGoalId,
  String expectation = '',
  double baselineValue = 0,
  DateTime? createdAt,
}) =>
    Commitment(
      id: 'cmt_$goalId',
      goalId: goalId,
      start: currentWeek(now).start,
      end: currentWeek(now).end,
      targetDelta: targetDelta,
      targetDone: targetDone,
      targetRatingPoints: targetRatingPoints,
      targetChildGoalId: targetChildGoalId,
      expectation: expectation,
      baselineValue: baselineValue,
      createdAt: createdAt ?? now.subtract(const Duration(days: 3)),
    );

void main() {
  group('累积型', () {
    test('推进量达到承诺量才算兑现', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.cumulative,
        startValue: 0,
        currentValue: 30,
        targetValue: 100,
        unit: '页',
      );
      final CommitmentEvaluation notYet = engineFor(
        <Goal>[g],
        <Commitment>[commitment('a', targetDelta: 20, baselineValue: 20)],
      ).evaluate(commitment('a', targetDelta: 20, baselineValue: 20));

      // 30 - 20 = 10，只完成了一半。
      expect(notYet.ratio, closeTo(0.5, 0.001));
      expect(notYet.fulfilled, isFalse);

      final CommitmentEvaluation done = engineFor(
        <Goal>[g],
        <Commitment>[commitment('a', targetDelta: 10, baselineValue: 20)],
      ).evaluate(commitment('a', targetDelta: 10, baselineValue: 20));
      expect(done.fulfilled, isTrue);
    });

    test('事后把目标值改小，也不会让旧承诺自动变成已兑现', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.cumulative,
        startValue: 0,
        currentValue: 25,
        targetValue: 100,
      );
      // 承诺时是 20，实际推进到 25，只推进了 5；
      // 即使目标值后来被改成 25，承诺量仍然是 10。
      final Commitment c = commitment('a', targetDelta: 10, baselineValue: 20);
      final CommitmentEvaluation e =
          engineFor(<Goal>[g], <Commitment>[c]).evaluate(c);
      expect(e.ratio, closeTo(0.5, 0.001));
      expect(e.fulfilled, isFalse);
    });
  });

  group('完成型', () {
    test('承诺之后才完成才算兑现', () {
      final Goal g = goal('a', mechanism: Mechanism.completion, lifecycle: Lifecycle.completed);
      final List<UpdateRecord> records = <UpdateRecord>[
        rec('a', at: now.subtract(const Duration(days: 1)), done: true),
      ];
      final Commitment after = commitment('a', createdAt: now.subtract(const Duration(days: 2)));
      expect(engineFor(<Goal>[g], <Commitment>[after], records).evaluate(after).fulfilled, isTrue);

      final Commitment before = commitment('a', createdAt: now);
      expect(engineFor(<Goal>[g], <Commitment>[before], records).evaluate(before).fulfilled, isFalse);
    });
  });

  group('主观型', () {
    test('按自评推进的点数判定', () {
      final Goal g = goal('a', mechanism: Mechanism.subjective, currentValue: 55);
      final Commitment c = commitment('a', targetRatingPoints: 10, baselineValue: 45);
      final CommitmentEvaluation e =
          engineFor(<Goal>[g], <Commitment>[c]).evaluate(c);
      expect(e.fulfilled, isTrue);
      expect(e.actualText, contains('+10'));
    });
  });

  group('里程碑型', () {
    test('承诺完成某个子项', () {
      final Goal parent = goal('p', mechanism: Mechanism.milestone);
      final Goal child = goal('a', parentGoalId: 'p', lifecycle: Lifecycle.completed);
      final List<UpdateRecord> records = <UpdateRecord>[
        rec('a', at: now.subtract(const Duration(days: 1)), done: true),
      ];
      final Commitment c = commitment(
        'p',
        targetChildGoalId: 'a',
        createdAt: now.subtract(const Duration(days: 2)),
      );
      final CommitmentEvaluation e =
          engineFor(<Goal>[parent, child], <Commitment>[c], records).evaluate(c);
      expect(e.fulfilled, isTrue);
    });
  });

  group('指标型', () {
    test('只作结果期望，未达不解读为投入不足', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.metric,
        startValue: 80,
        currentValue: 78,
        targetValue: 70,
      );
      final Commitment c = commitment('a', expectation: '月底到 75 左右');
      final CommitmentEvaluation e =
          engineFor(<Goal>[g], <Commitment>[c]).evaluate(c);
      expect(e.expectationOnly, isTrue);
      expect(e.fulfilled, isFalse);
      expect(e.actualText, contains('结果期望'));
    });
  });

  group('窗口', () {
    test('inWindow 只取窗口内的承诺', () {
      final Goal g = goal('a', mechanism: Mechanism.completion);
      final Commitment thisWeek = commitment('a');
      final Commitment old = Commitment(
        id: 'old',
        goalId: 'a',
        start: now.subtract(const Duration(days: 90)),
        end: now.subtract(const Duration(days: 84)),
        createdAt: now.subtract(const Duration(days: 90)),
      );
      final List<Commitment> inWeek =
          engineFor(<Goal>[g], <Commitment>[thisWeek, old])
              .inWindow(currentWeek(now));
      expect(inWeek.length, 1);
      expect(inWeek.first.id, 'cmt_a');
    });
  });
}
