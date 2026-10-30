import 'package:flutter_test/flutter_test.dart';
import 'package:goal_manager/data/models/enums.dart';
import 'package:goal_manager/data/models/goal.dart';
import 'package:goal_manager/data/models/update_record.dart';
import 'package:goal_manager/domain/progress.dart';

import '../helpers.dart';

void main() {
  group('完成型', () {
    test('未完成 0%，完成 100%，不做落后判断', () {
      final Goal g = goal('a', dueDate: now.add(const Duration(days: 5)));
      final ProgressSnapshot s =
          ProgressEngine(data: dataWith(<Goal>[g]), now: now).of(g.id);

      expect(s.percent, 0);
      expect(s.plannedPercent, isNull, reason: '完成型不计算计划进度');
      expect(s.paceText, contains('还剩 5 天'));
      expect(s.isComplete, isFalse);
    });

    test('已完成就是 100%', () {
      final Goal g = goal('a', lifecycle: Lifecycle.completed);
      final ProgressSnapshot s =
          ProgressEngine(data: dataWith(<Goal>[g]), now: now).of(g.id);
      expect(s.percent, 100);
      expect(s.isComplete, isTrue);
    });
  });

  group('累积型', () {
    test('进度 = (当前-起始)/(目标-起始)，不截断', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.cumulative,
        startValue: 0,
        currentValue: 30,
        targetValue: 100,
        startDate: now.subtract(const Duration(days: 10)),
        dueDate: now.add(const Duration(days: 10)),
        unit: '页',
      );
      final ProgressSnapshot s =
          ProgressEngine(data: dataWith(<Goal>[g]), now: now).of(g.id);

      expect(s.percent, closeTo(30, 0.001));
      expect(s.plannedPercent, closeTo(50, 0.001));
      expect(s.rawText, '30 页 / 100 页');
      expect(s.paceText, contains('落后 20 个百分点'));
      expect(s.paceText, contains('每日还需'));
      expect(s.isComplete, isFalse);
    });

    test('允许负值与超过 100%', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.cumulative,
        startValue: 10,
        currentValue: 5,
        targetValue: 20,
      );
      final ProgressSnapshot s =
          ProgressEngine(data: dataWith(<Goal>[g]), now: now).of(g.id);
      expect(s.percent, closeTo(-50, 0.001));
    });

    test('达到目标值即判定完成', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.cumulative,
        startValue: 0,
        currentValue: 120,
        targetValue: 100,
      );
      final ProgressSnapshot s =
          ProgressEngine(data: dataWith(<Goal>[g]), now: now).of(g.id);
      expect(s.percent, 120);
      expect(s.isComplete, isTrue);
    });

    test('递减目标（越花越少）也能算', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.cumulative,
        startValue: 100,
        currentValue: 40,
        targetValue: 0,
      );
      final ProgressSnapshot s =
          ProgressEngine(data: dataWith(<Goal>[g]), now: now).of(g.id);
      expect(s.percent, closeTo(60, 0.001));
    });
  });

  group('指标型', () {
    test('一次读数到目标不算达成，要连续 N 次', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.metric,
        startValue: 80,
        currentValue: 72,
        targetValue: 70,
        stableWindow: 3,
      );
      final List<UpdateRecord> records = <UpdateRecord>[
        UpdateRecord.progress(goalId: 'a', at: now.subtract(const Duration(days: 4)), reading: 75),
        UpdateRecord.progress(goalId: 'a', at: now.subtract(const Duration(days: 3)), reading: 70),
        UpdateRecord.progress(goalId: 'a', at: now.subtract(const Duration(days: 2)), reading: 69),
      ];
      final ProgressSnapshot s =
          ProgressEngine(data: dataWith(<Goal>[g], records), now: now).of(g.id);
      expect(s.isComplete, isFalse, reason: '最近 3 次里有 1 次没达标');

      records.add(UpdateRecord.progress(goalId: 'a', at: now, reading: 68));
      final ProgressSnapshot s2 =
          ProgressEngine(data: dataWith(<Goal>[g], records), now: now).of(g.id);
      expect(s2.isComplete, isTrue, reason: '最近 3 次分别是 70 / 69 / 68，全部达标');
    });

    test('读数回退会回到未完成（需要靠固化锁定）', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.metric,
        startValue: 80,
        currentValue: 74,
        targetValue: 70,
        stableWindow: 2,
      );
      final List<UpdateRecord> records = <UpdateRecord>[
        UpdateRecord.progress(goalId: 'a', at: now.subtract(const Duration(days: 2)), reading: 70),
        UpdateRecord.progress(goalId: 'a', at: now.subtract(const Duration(days: 1)), reading: 69),
        UpdateRecord.progress(goalId: 'a', at: now, reading: 74),
      ];
      final ProgressSnapshot s =
          ProgressEngine(data: dataWith(<Goal>[g], records), now: now).of(g.id);
      expect(s.isComplete, isFalse);
      expect(s.percent, closeTo(((74 - 80) / (70 - 80)) * 100, 0.001));
    });

    test('样本不足时给出「尚无法判断」的说明', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.metric,
        startValue: 80,
        currentValue: 76,
        targetValue: 70,
      );
      final ProgressSnapshot s =
          ProgressEngine(data: dataWith(<Goal>[g]), now: now).of(g.id);
      expect(
        s.notes.any((String n) => n.contains('尚无法判断')),
        isTrue,
      );
    });
  });

  group('主观型', () {
    test('进度等于自评值，且不输出「落后」', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.subjective,
        currentValue: 45,
        startDate: now.subtract(const Duration(days: 10)),
        dueDate: now.add(const Duration(days: 10)),
      );
      final ProgressSnapshot s =
          ProgressEngine(data: dataWith(<Goal>[g]), now: now).of(g.id);

      expect(s.percent, 45);
      expect(s.plannedPercent, isNull);
      expect(s.paceText, isNull);
      expect(s.timeElapsedRatio, closeTo(0.5, 0.001), reason: '时间线仍然并排展示');
    });
  });

  group('里程碑型', () {
    test('进度是子项加权上卷，完成判定看必需子项', () {
      final Goal parent = goal(
        'p',
        mechanism: Mechanism.milestone,
        parentGoalId: null,
      );
      final Goal a = goal(
        'a',
        mechanism: Mechanism.completion,
        lifecycle: Lifecycle.completed,
        parentGoalId: 'p',
        sortOrder: 100,
      );
      final Goal b = goal(
        'b',
        mechanism: Mechanism.cumulative,
        startValue: 0,
        currentValue: 25,
        targetValue: 100,
        parentGoalId: 'p',
        sortOrder: 200,
        weight: 3,
      );
      final Goal c = goal(
        'c',
        mechanism: Mechanism.completion,
        parentGoalId: 'p',
        sortOrder: 300,
        isRequired: false,
      );

      final ProgressSnapshot s =
          ProgressEngine(data: dataWith(<Goal>[parent, a, b, c]), now: now).of('p');

      // (100*1 + 25*3 + 0*1) / 5 = 35
      expect(s.percent, closeTo(35, 0.001));
      expect(s.isComplete, isFalse, reason: '必需子项 b 还没完成');
      expect(s.rawText, contains('1 / 3'));
    });

    test('全部必需子项完成才算完成（非必需子项不影响）', () {
      final Goal parent = goal('p', mechanism: Mechanism.milestone);
      final Goal a = goal(
        'a',
        mechanism: Mechanism.completion,
        lifecycle: Lifecycle.completed,
        parentGoalId: 'p',
        sortOrder: 100,
      );
      final Goal b = goal(
        'b',
        mechanism: Mechanism.completion,
        parentGoalId: 'p',
        sortOrder: 200,
        isRequired: false,
      );
      final ProgressSnapshot s =
          ProgressEngine(data: dataWith(<Goal>[parent, a, b]), now: now).of('p');
      expect(s.isComplete, isTrue);
    });

    test('循环父子关系不会导致无限递归', () {
      final Goal a = goal('a', mechanism: Mechanism.milestone, parentGoalId: 'b');
      final Goal b = goal('b', mechanism: Mechanism.milestone, parentGoalId: 'a');
      final ProgressSnapshot s =
          ProgressEngine(data: dataWith(<Goal>[a, b]), now: now).of('a');
      expect(s.notes.any((String n) => n.contains('循环')), isTrue);
    });
  });

  group('历史回放', () {
    test('rawValueAt 能还原某个时间点的原始量', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.cumulative,
        startValue: 0,
        currentValue: 30,
        targetValue: 100,
      );
      final List<UpdateRecord> records = <UpdateRecord>[
        UpdateRecord.progress(goalId: 'a', at: now.subtract(const Duration(days: 10)), delta: 10),
        UpdateRecord.progress(goalId: 'a', at: now.subtract(const Duration(days: 5)), delta: 20),
      ];
      final ProgressEngine engine =
          ProgressEngine(data: dataWith(<Goal>[g], records), now: now);
      expect(engine.rawValueAt(g, now.subtract(const Duration(days: 12))), 0);
      expect(engine.rawValueAt(g, now.subtract(const Duration(days: 8))), 10);
      expect(engine.rawValueAt(g, now), 30);
    });
  });
}
