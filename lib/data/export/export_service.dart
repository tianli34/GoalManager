import 'dart:convert';

import '../../core/date_utils.dart';
import '../../domain/progress.dart';
import '../models/app_data.dart';
import '../models/commitment.dart';
import '../models/goal.dart';
import '../models/inbox_item.dart';
import '../models/review.dart';
import '../models/update_record.dart';
import 'file_writer.dart';

/// 导出 / 导入。
///
/// 两种格式：
/// - JSON：可完整恢复（导入后所有对象、原始量、层级、历史都在）；
/// - Markdown：人能读（备份到笔记、发给自己看）。
class ExportService {
  ExportService({required this.data, this.progress});

  final AppData data;

  /// 传入进度引擎时，Markdown 里会带上进度与配速解释。
  final ProgressEngine? progress;

  String get suggestedFileName {
    final DateTime now = DateTime.now();
    final String stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}-${_two(now.hour)}${_two(now.minute)}';
    return 'goalmanager-$stamp';
  }

  String toJsonString() =>
      const JsonEncoder.withIndent('  ').convert(data.toJson());

  /// 落盘（Web 上返回 null，界面退化为「复制文本」）。
  Future<String?> saveJsonToFile() =>
      writeTextFile('$suggestedFileName.json', toJsonString());

  Future<String?> saveMarkdownToFile() =>
      writeTextFile('$suggestedFileName.md', toMarkdown());

  // ------------------------------------------------------------------ 导入

  /// 解析备份 JSON。失败时抛出带说明的 FormatException。
  static AppData parse(String raw) {
    if (raw.trim().isEmpty) {
      throw const FormatException('内容为空');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      throw FormatException('不是合法的 JSON：$e');
    }
    if (decoded is! Map) {
      throw const FormatException('顶层必须是 JSON 对象');
    }
    final Map<String, Object?> json = decoded.cast<String, Object?>();
    final int version = json['schemaVersion'] is num
        ? (json['schemaVersion']! as num).toInt()
        : 1;
    if (version > kSchemaVersion) {
      throw FormatException(
          '备份的数据版本是 $version，高于当前应用支持的 $kSchemaVersion，请升级应用后再导入');
    }
    final AppData parsed = AppData.fromJson(json);
    if (parsed.goals.isEmpty && parsed.records.isEmpty) {
      throw const FormatException('备份里既没有目标也没有记录，可能不是本应用的备份');
    }
    return parsed;
  }

  // ---------------------------------------------------------------- Markdown

  String toMarkdown() {
    final StringBuffer sb = StringBuffer();
    final DateTime now = DateTime.now();
    sb.writeln('# GoalManager 备份');
    sb.writeln();
    sb.writeln('- 导出时间：${fmtDateTime(now)}');
    sb.writeln('- 数据结构版本：${data.schemaVersion}');
    sb.writeln(
        '- 目标 ${data.goals.length} 个 · 更新记录 ${data.records.length} 条 · 承诺 ${data.commitments.length} 条 · 复盘 ${data.reviews.length} 次 · 收集箱 ${data.inbox.length} 条');
    sb.writeln();

    sb.writeln('## 目标');
    sb.writeln();
    final List<Goal> roots = data.goals
        .where((Goal g) => g.parentGoalId == null)
        .toList()
      ..sort((Goal a, Goal b) => a.createdAt.compareTo(b.createdAt));
    if (roots.isEmpty) {
      sb.writeln('（暂无目标）');
      sb.writeln();
    }
    for (final Goal goal in roots) {
      _writeGoal(sb, goal, 2);
    }

    sb.writeln('## 承诺');
    sb.writeln();
    if (data.commitments.isEmpty) {
      sb.writeln('（暂无承诺）');
      sb.writeln();
    }
    for (final Commitment c in data.commitments) {
      final Goal? goal = data.goalById(c.goalId);
      sb.writeln('### ${goal?.title ?? c.goalId}（${c.status.label}）');
      sb.writeln('- 窗口：${fmtDate(c.start)} ~ ${fmtDate(c.end)}');
      if (c.targetDelta != null) sb.writeln('- 承诺增量：${_signed(c.targetDelta!)}');
      if (c.targetDone) sb.writeln('- 承诺：完成该目标');
      if (c.targetRatingPoints != null) {
        sb.writeln('- 承诺自评推进：${fmtNum(c.targetRatingPoints!)} 点');
      }
      if (c.targetChildGoalId != null) {
        final Goal? child = data.goalById(c.targetChildGoalId!);
        sb.writeln('- 承诺完成子项：${child?.title ?? c.targetChildGoalId}');
      }
      if (c.expectation.isNotEmpty) sb.writeln('- 结果期望：${c.expectation}');
      if (c.note.isNotEmpty) sb.writeln('- 备注：${c.note}');
      if (c.history.isNotEmpty) {
        sb.writeln('- 变更历史：');
        for (final CommitmentChange h in c.history) {
          sb.writeln(
              '  - ${fmtDateTime(h.at)}　${h.from.label} → ${h.to.label}${h.reason == null ? '' : '（${h.reason}）'}');
        }
      }
      sb.writeln();
    }

    sb.writeln('## 复盘');
    sb.writeln();
    if (data.reviews.isEmpty) {
      sb.writeln('（暂无复盘）');
      sb.writeln();
    }
    for (final Review r in data.reviews) {
      sb.writeln('### ${fmtDate(r.start)} ~ ${fmtDate(r.end)}（决定：${r.decision.label}）');
      sb.writeln('- 关联目标：${r.goalIds.map((String id) => data.goalById(id)?.title ?? id).join('、')}');
      sb.writeln('- Q1 发生了什么：${r.whatHappened}');
      sb.writeln(
          '- Q2 原计划还值得吗：${r.stillWorth}${r.stillWorthAnswer == null ? '' : '（${r.stillWorthAnswer! ? '是' : '否'}）'}');
      if (r.nextStep != null && r.nextStep!.isNotEmpty) {
        sb.writeln('- 下一步：${r.nextStep}');
      }
      sb.writeln();
    }

    sb.writeln('## 收集箱');
    sb.writeln();
    if (data.inbox.isEmpty) {
      sb.writeln('（收集箱是空的）');
      sb.writeln();
    }
    for (final InboxItem item in data.inbox) {
      sb.writeln('- ${fmtDateTime(item.createdAt)}　${item.text}　【${item.status.label}】');
    }
    sb.writeln();
    return sb.toString();
  }

  void _writeGoal(StringBuffer sb, Goal goal, int level) {
    final String heading = _repeat('#', level + 1);
    final String pad = _repeat('  ', level);
    final ProgressSnapshot? ps = progress?.of(goal.id);
    final String parentTag = goal.parentGoalId == null
        ? ''
        : '　（子项：权重 ${fmtNum(goal.weight)}${goal.isRequired ? '，必需' : '，非必需'}）';

    sb.writeln('$heading ${goal.title}$parentTag');
    sb.writeln('- 机制：${goal.mechanism.label} · 生命周期：${goal.lifecycle.label}${goal.isArchived ? ' · 已归档' : ''}');
    if (goal.why.isNotEmpty) sb.writeln('- 为什么：${goal.why}');
    if (goal.successCriteria.isNotEmpty) {
      sb.writeln('- 达成条件：${goal.successCriteria}');
    }
    if (goal.tags.isNotEmpty) sb.writeln('- 领域/标签：${goal.tags.join('、')}');
    sb.writeln(
        '- 时间：${goal.startDate == null ? '未设起始' : fmtDate(goal.startDate!)} ~ ${goal.dueDate == null ? '未设截止' : fmtDate(goal.dueDate!)}');
    if (goal.mechanism == Mechanism.cumulative ||
        goal.mechanism == Mechanism.metric) {
      sb.writeln(
          '- 原始量：起始 ${_num(goal.startValue)} → 当前 ${_num(goal.currentValue)} → 目标 ${_num(goal.targetValue)} ${goal.unit}');
    }
    if (goal.mechanism == Mechanism.subjective) {
      sb.writeln('- 自评进度：${_num(goal.currentValue)}%');
    }
    if (goal.mechanism == Mechanism.metric) {
      sb.writeln('- 稳定达标：连续 ${goal.stableWindow} 次读数达标才算完成');
    }
    if (goal.mechanism == Mechanism.milestone) {
      sb.writeln('- 执行模式：${goal.executionMode.label}');
    }
    if (ps != null) {
      sb.writeln('- 进度：${fmtPercent(ps.percent)}（${ps.rawText}）');
      if (ps.plannedPercent != null) {
        sb.writeln('- 计划进度：${fmtPercent(ps.plannedPercent!)}');
      }
      if (ps.paceText != null) sb.writeln('- 配速：${ps.paceText}');
      sb.writeln('- 完成判定：${goal.mechanism.completionRule}（当前${ps.isComplete ? '满足' : '未满足'}）');
    }
    sb.writeln();

    final List<UpdateRecord> records = data.recordsOf(goal.id);
    if (records.isNotEmpty) {
      sb.writeln('$pad- 时间线（${records.length} 条）：');
      for (final UpdateRecord r in records) {
        sb.writeln('  $pad${_recordLine(r)}');
      }
      sb.writeln();
    }

    final List<Goal> children = data.childrenOf(goal.id);
    for (final Goal child in children) {
      _writeGoal(sb, child, level + 1);
    }
  }

  String _recordLine(UpdateRecord r) {
    final List<String> parts = <String>[r.type.label];
    if (r.delta != null) parts.add('增量 ${_signed(r.delta!)}');
    if (r.reading != null) parts.add('读数 ${fmtNum(r.reading!)}');
    if (r.selfRating != null) parts.add('自评 ${fmtNum(r.selfRating!)}%');
    if (r.done != null) parts.add(r.done! ? '标记完成' : '撤销完成');
    if (r.configChanges.isNotEmpty) {
      parts.add(r.configChanges.entries
          .map((MapEntry<String, String> e) => '${e.key}：${e.value}')
          .join('；'));
    }
    if (r.fromLifecycle != null && r.toLifecycle != null) {
      parts.add('${r.fromLifecycle!.label} → ${r.toLifecycle!.label}');
    }
    if (r.note.isNotEmpty) parts.add('备注：${r.note}');
    if (r.changeReason != null && r.changeReason!.isNotEmpty) {
      parts.add('原因：${r.changeReason}');
    }
    if (r.attachments.isNotEmpty) {
      parts.add('附件：${r.attachments.join('、')}');
    }
    return '- ${fmtDateTime(r.timestamp)}　${parts.join(' · ')}';
  }

  String _num(double? v) => v == null ? '—' : fmtNum(v);

  /// Dart 的 String 没有乘号，这里自己拼。
  String _repeat(String unit, int times) =>
      times <= 0 ? '' : List<String>.filled(times, unit).join();

  String _signed(double v) => '${v >= 0 ? '+' : '−'}${fmtNum(v.abs())}';

  String _two(int v) => v < 10 ? '0$v' : '$v';
}
