import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:goal_manager/data/export/export_service.dart';
import 'package:goal_manager/data/models/app_data.dart';
import 'package:goal_manager/data/models/enums.dart';
import 'package:goal_manager/data/models/goal.dart';
import 'package:goal_manager/data/models/update_record.dart';
import 'package:goal_manager/domain/progress.dart';
import 'package:goal_manager/state/seed_data.dart';

void main() {
  group('JSON 备份', () {
    test('往返之后所有内容都还在', () {
      final AppData data = buildSeedData();
      final String json = ExportService(data: data).toJsonString();
      final AppData restored = ExportService.parse(json);

      expect(restored.schemaVersion, data.schemaVersion);
      expect(restored.goals.length, data.goals.length);
      expect(restored.records.length, data.records.length);
      expect(restored.commitments.length, data.commitments.length);
      expect(restored.reviews.length, data.reviews.length);
      expect(restored.inbox.length, data.inbox.length);

      for (final Goal before in data.goals) {
        final Goal after =
            restored.goals.firstWhere((Goal g) => g.id == before.id);
        expect(after.title, before.title);
        expect(after.mechanism, before.mechanism);
        expect(after.lifecycle, before.lifecycle);
        expect(after.startDate, before.startDate);
        expect(after.dueDate, before.dueDate);
        expect(after.tags, before.tags);
        expect(after.unit, before.unit);
        expect(after.startValue, before.startValue);
        expect(after.currentValue, before.currentValue);
        expect(after.targetValue, before.targetValue);
        expect(after.executionMode, before.executionMode);
        expect(after.stableWindow, before.stableWindow);
        // 父子层级 + 权重 + isRequired 必须完整保留。
        expect(after.parentGoalId, before.parentGoalId);
        expect(after.weight, before.weight);
        expect(after.isRequired, before.isRequired);
        expect(after.sortOrder, before.sortOrder);
      }

      for (final UpdateRecord before in data.records) {
        final UpdateRecord after =
            restored.records.firstWhere((UpdateRecord r) => r.id == before.id);
        expect(after.type, before.type);
        expect(after.delta, before.delta);
        expect(after.reading, before.reading);
        expect(after.selfRating, before.selfRating);
        expect(after.done, before.done);
        expect(after.note, before.note);
      }
    });

    test('配置变更记录里的字段变更也保留', () {
      final AppData data = AppData();
      final Goal g = Goal.create(
        id: 'a',
        title: '读 24 本书',
        mechanism: Mechanism.cumulative,
        targetValue: 24,
      );
      data.goals.add(g);
      data.records.add(UpdateRecord.configChange(
        goalId: 'a',
        at: DateTime(2026, 5, 1),
        changes: <String, String>{'目标值': '30 → 24'},
        reason: '算了下时间，24 更现实',
      ));

      final AppData restored = ExportService.parse(
        ExportService(data: data).toJsonString(),
      );
      final UpdateRecord record = restored.records.single;
      expect(record.type, RecordType.configChange);
      expect(record.configChanges['目标值'], '30 → 24');
      expect(record.changeReason, '算了下时间，24 更现实');
    });

    test('非法输入给出可读的错误', () {
      expect(() => ExportService.parse(''), throwsA(isA<FormatException>()));
      expect(() => ExportService.parse('不是 JSON'),
          throwsA(isA<FormatException>()));
      expect(() => ExportService.parse('[]'),
          throwsA(isA<FormatException>()));
      expect(() => ExportService.parse('{}'),
          throwsA(isA<FormatException>()));
      expect(
        () => ExportService.parse(
          jsonEncode(<String, Object?>{'schemaVersion': 999, 'goals': <Object>[]}),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Markdown 备份', () {
    test('包含目标定义、机制参数、原始量与时间线', () {
      final AppData data = buildSeedData();
      final ProgressEngine progress = ProgressEngine(data: data);
      final String md = ExportService(data: data, progress: progress).toMarkdown();

      expect(md, contains('# 北极星 备份'));
      expect(md, contains('今年读完 24 本书'));
      expect(md, contains('累积型'));
      expect(md, contains('原始量'));
      expect(md, contains('时间线'));
      expect(md, contains('## 承诺'));
      expect(md, contains('## 复盘'));
      expect(md, contains('## 收集箱'));
    });

    test('串行里程碑会导出执行模式与子项', () {
      final AppData data = buildSeedData();
      final String md = ExportService(data: data).toMarkdown();
      expect(md, contains('执行模式：串行'));
      expect(md, contains('部署到生产环境并验收'));
    });
  });
}
