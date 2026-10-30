import 'package:flutter_test/flutter_test.dart';
import 'package:goal_manager/data/models/enums.dart';
import 'package:goal_manager/data/models/goal.dart';
import 'package:goal_manager/domain/milestone.dart';
import 'package:goal_manager/domain/progress.dart';

import '../helpers.dart';

MilestoneEngine engineFor(List<Goal> goals) {
  final data = dataWith(goals);
  return MilestoneEngine(
    data: data,
    progress: ProgressEngine(data: data, now: now),
    now: now,
  );
}

void main() {
  group('串行模式', () {
    test('第一项聚焦，后面的待解锁', () {
      final parent = goal(
        'p',
        mechanism: Mechanism.milestone,
        executionMode: ExecutionMode.sequential,
      );
      final a = goal('a', parentGoalId: 'p', sortOrder: 100, lifecycle: Lifecycle.active);
      final b = goal('b', parentGoalId: 'p', sortOrder: 200, lifecycle: Lifecycle.pending);

      final views = engineFor(<Goal>[parent, a, b]).childrenOf('p');

      expect(views[0].state, MilestoneChildState.active);
      expect(views[0].isFocus, isTrue);
      expect(views[0].state.acceptsInput, isTrue);
      expect(views[1].state, MilestoneChildState.locked);
      expect(views[1].state.acceptsInput, isFalse, reason: '待解锁默认隐藏录入入口');
    });

    test('前一项完成后，下一项成为聚焦', () {
      final parent = goal(
        'p',
        mechanism: Mechanism.milestone,
        executionMode: ExecutionMode.sequential,
      );
      final a = goal(
        'a',
        parentGoalId: 'p',
        sortOrder: 100,
        lifecycle: Lifecycle.completed,
      );
      final b = goal('b', parentGoalId: 'p', sortOrder: 200, lifecycle: Lifecycle.active);

      final MilestoneEngine engine = engineFor(<Goal>[parent, a, b]);
      final views = engine.childrenOf('p');

      expect(views[0].state, MilestoneChildState.completed);
      expect(views[1].isFocus, isTrue);
      expect(engine.focusOf('p')!.goal.id, 'b');
    });

    test('软锁定：允许提前开始，且允许同时存在多个进行中', () {
      final parent = goal(
        'p',
        mechanism: Mechanism.milestone,
        executionMode: ExecutionMode.sequential,
      );
      final a = goal('a', parentGoalId: 'p', sortOrder: 100, lifecycle: Lifecycle.active);
      final b = goal(
        'b',
        parentGoalId: 'p',
        sortOrder: 200,
        lifecycle: Lifecycle.active,
        statusOverride: ChildStatusOverride.forceActive,
      );

      final views = engineFor(<Goal>[parent, a, b]).childrenOf('p');

      expect(views[0].state, MilestoneChildState.active);
      expect(views[1].state, MilestoneChildState.active);
      expect(views[1].isFocus, isFalse);
    });

    test('已完成后原始量回退：只标记异常，不回退锁定', () {
      final parent = goal(
        'p',
        mechanism: Mechanism.milestone,
        executionMode: ExecutionMode.sequential,
      );
      final a = goal(
        'a',
        mechanism: Mechanism.cumulative,
        parentGoalId: 'p',
        sortOrder: 100,
        lifecycle: Lifecycle.completed,
        startValue: 0,
        currentValue: 8,
        targetValue: 10,
      );
      final b = goal('b', parentGoalId: 'p', sortOrder: 200, lifecycle: Lifecycle.active);

      final views = engineFor(<Goal>[parent, a, b]).childrenOf('p');

      expect(views[0].state, MilestoneChildState.regression);
      expect(views[1].state, MilestoneChildState.active, reason: '解锁不回退');
    });

    test('指标型固化后不再接收新读数', () {
      final parent = goal(
        'p',
        mechanism: Mechanism.milestone,
        executionMode: ExecutionMode.sequential,
      );
      final a = goal(
        'a',
        mechanism: Mechanism.metric,
        parentGoalId: 'p',
        sortOrder: 100,
        lifecycle: Lifecycle.completed,
        startValue: 80,
        currentValue: 70,
        targetValue: 70,
        statusOverride: ChildStatusOverride.frozen,
      );
      final b = goal('b', parentGoalId: 'p', sortOrder: 200, lifecycle: Lifecycle.active);

      final views = engineFor(<Goal>[parent, a, b]).childrenOf('p');

      expect(views[0].state, MilestoneChildState.frozen);
      expect(views[0].state.acceptsInput, isFalse);
      expect(views[1].isFocus, isTrue);
    });
  });

  group('并列模式', () {
    test('所有子项同时激活，没有聚焦项', () {
      final parent = goal(
        'p',
        mechanism: Mechanism.milestone,
        executionMode: ExecutionMode.parallel,
      );
      final a = goal('a', parentGoalId: 'p', sortOrder: 100);
      final b = goal('b', parentGoalId: 'p', sortOrder: 200);

      final MilestoneEngine engine = engineFor(<Goal>[parent, a, b]);
      final views = engine.childrenOf('p');

      expect(views.every((MilestoneChildView v) => v.state == MilestoneChildState.active), isTrue);
      expect(engine.focusOf('p'), isNull);
    });
  });

  group('配速', () {
    test('前项延期会把剩余时间挤压给后面的子项', () {
      final parent = goal(
        'p',
        mechanism: Mechanism.milestone,
        executionMode: ExecutionMode.sequential,
        startDate: now.subtract(const Duration(days: 10)),
        dueDate: now.add(const Duration(days: 10)),
      );
      final a = goal('a', parentGoalId: 'p', sortOrder: 100, lifecycle: Lifecycle.active);
      final b = goal('b', parentGoalId: 'p', sortOrder: 200, lifecycle: Lifecycle.pending);

      final views = engineFor(<Goal>[parent, a, b]).childrenOf('p');

      // 剩余 10 天由 a、b 平分 → a 只分到 5 天；
      // a 从 10 天前就激活了，所以它的预期进度已经是 200%。
      expect(views[0].expectedPercent, closeTo(200, 1));
      expect(views[0].paceText, contains('落后'));
    });
  });
}
