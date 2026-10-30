import 'package:flutter_test/flutter_test.dart';
import 'package:goal_manager/data/models/app_data.dart';
import 'package:goal_manager/data/models/enums.dart';
import 'package:goal_manager/data/models/goal.dart';
import 'package:goal_manager/data/models/update_record.dart';
import 'package:goal_manager/domain/progress.dart';
import 'package:goal_manager/domain/signals.dart';

import '../helpers.dart';

SignalEngine signalEngineFor(
  List<Goal> goals,
  List<UpdateRecord> records, {
  DateTime at = now,
}) {
  final AppData data = dataWith(goals, records);
  return SignalEngine(
    data: data,
    progress: ProgressEngine(data: data, now: at),
    now: at,
  );
}

void main() {
  group('久未更新', () {
    test('超过阈值就提醒', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.cumulative,
        startValue: 0,
        currentValue: 5,
        targetValue: 100,
      );
      final List<UpdateRecord> records = <UpdateRecord>[
        rec('a', at: now.subtract(const Duration(days: 30)), delta: 5),
      ];
      final List<SignalItem> items =
          signalEngineFor(<Goal>[g], records).forGoal('a');

      expect(items.map((SignalItem i) => i.kind),
          contains(AttentionSignal.noRecentUpdate));
      expect(items.first.reason, contains('30 天'));
    });

    test('刚刚记录过就不提醒', () {
      final Goal g = goal('a', mechanism: Mechanism.completion);
      final List<UpdateRecord> records = <UpdateRecord>[
        rec('a', at: now.subtract(const Duration(days: 2))),
      ];
      final List<SignalItem> items =
          signalEngineFor(<Goal>[g], records).forGoal('a');
      expect(items.map((SignalItem i) => i.kind),
          isNot(contains(AttentionSignal.noRecentUpdate)));
    });

    test('按目标自己的阈值覆盖', () {
      final Goal g = goal('a', mechanism: Mechanism.completion);
      g.noUpdateThresholdDays = 60;
      final List<UpdateRecord> records = <UpdateRecord>[
        rec('a', at: now.subtract(const Duration(days: 30))),
      ];
      final List<SignalItem> items =
          signalEngineFor(<Goal>[g], records).forGoal('a');
      expect(items, isEmpty, reason: '30 天没更新，但这个目标自己的阈值是 60 天');
    });
  });

  group('排除规则', () {
    test('暂停的目标不产生任何提醒', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.cumulative,
        lifecycle: Lifecycle.paused,
        startValue: 0,
        currentValue: 1,
        targetValue: 100,
        dueDate: now.subtract(const Duration(days: 30)),
      );
      final List<SignalItem> items =
          signalEngineFor(<Goal>[g], <UpdateRecord>[]).forGoal('a');
      expect(items, isEmpty);
    });

    test('完成型长期 0% 不触发疑似停滞', () {
      final Goal g = goal('a', mechanism: Mechanism.completion);
      final List<UpdateRecord> records = <UpdateRecord>[
        rec('a', at: now.subtract(const Duration(days: 60)), note: '还是没做'),
      ];
      final List<SignalItem> items =
          signalEngineFor(<Goal>[g], records).forGoal('a');
      expect(items.map((SignalItem i) => i.kind),
          isNot(contains(AttentionSignal.possibleStall)));
    });

    test('指标型样本不足时输出「尚无法判断」而不是「疑似停滞」', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.metric,
        startValue: 80,
        currentValue: 79,
        targetValue: 70,
      );
      final List<UpdateRecord> records = <UpdateRecord>[
        rec('a', at: now.subtract(const Duration(days: 40)), reading: 80),
        rec('a', at: now.subtract(const Duration(days: 30)), reading: 79),
      ];
      final List<SignalItem> items =
          signalEngineFor(<Goal>[g], records).forGoal('a');
      expect(items.map((SignalItem i) => i.kind),
          contains(AttentionSignal.insufficientData));
      expect(items.map((SignalItem i) => i.kind),
          isNot(contains(AttentionSignal.possibleStall)));
    });

    test('主观型不输出「落后」类判断', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.subjective,
        currentValue: 20,
        startDate: now.subtract(const Duration(days: 30)),
        dueDate: now.add(const Duration(days: 2)),
      );
      final List<SignalItem> items =
          signalEngineFor(<Goal>[g], <UpdateRecord>[]).forGoal('a');
      expect(items.map((SignalItem i) => i.kind),
          isNot(contains(AttentionSignal.dateRisk)));
    });
  });

  group('疑似停滞', () {
    test('有记录但原始量长期不变', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.cumulative,
        startValue: 0,
        currentValue: 10,
        targetValue: 100,
      );
      final List<UpdateRecord> records = <UpdateRecord>[
        rec('a', at: now.subtract(const Duration(days: 40)), delta: 10),
        rec('a', at: now.subtract(const Duration(days: 3)), note: '还在看'),
      ];
      final List<SignalItem> items =
          signalEngineFor(<Goal>[g], records).forGoal('a');
      expect(items.map((SignalItem i) => i.kind),
          contains(AttentionSignal.possibleStall));
    });
  });

  group('日期风险', () {
    test('临近截止且明显落后于计划', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.cumulative,
        startValue: 0,
        currentValue: 20,
        targetValue: 100,
        startDate: now.subtract(const Duration(days: 30)),
        dueDate: now.add(const Duration(days: 3)),
      );
      final List<SignalItem> items =
          signalEngineFor(<Goal>[g], <UpdateRecord>[]).forGoal('a');
      final SignalItem risk = items.firstWhere(
        (SignalItem i) => i.kind == AttentionSignal.dateRisk,
      );
      expect(risk.reason, contains('落后'));
    });

    test('已过截止日且未完成', () {
      final Goal g = goal(
        'a',
        mechanism: Mechanism.completion,
        dueDate: now.subtract(const Duration(days: 5)),
      );
      final List<SignalItem> items =
          signalEngineFor(<Goal>[g], <UpdateRecord>[]).forGoal('a');
      expect(items.map((SignalItem i) => i.kind),
          contains(AttentionSignal.dateRisk));
    });
  });

  test('全部信号按紧急度排序：日期风险在最前', () {
    final Goal g1 = goal(
      'a',
      mechanism: Mechanism.completion,
      dueDate: now.subtract(const Duration(days: 5)),
    );
    final Goal g2 = goal(
      'b',
      mechanism: Mechanism.cumulative,
      startValue: 0,
      currentValue: 10,
      targetValue: 100,
    );
    final List<UpdateRecord> records = <UpdateRecord>[
      rec('b', at: now.subtract(const Duration(days: 30)), delta: 10),
    ];
    final List<SignalItem> all =
        signalEngineFor(<Goal>[g1, g2], records).all();
    expect(all.first.kind, AttentionSignal.dateRisk);
  });
}
