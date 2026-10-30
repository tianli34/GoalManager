import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../data/models/commitment.dart';
import '../../data/models/enums.dart';
import '../../data/models/goal.dart';
import '../../data/models/update_record.dart';
import '../../domain/commitments.dart';
import '../../domain/milestone.dart';
import '../../domain/progress.dart';
import '../../state/app_state.dart';
import '../app_scope.dart';
import '../widgets/commitment_card.dart';
import '../widgets/commitment_sheet.dart';
import '../widgets/common.dart';
import 'widgets/milestone_panel.dart';
import 'widgets/progress_panel.dart';
import 'widgets/record_input.dart';

/// 目标详情：所有机制共用同一套骨架，
/// 只有「进度区」和「记录输入区」按机制切换。
class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppStateScope.of(context);
    final Goal? goal = state.goalById(goalId);
    if (goal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('目标')),
        body: const Center(child: Text('这个目标不存在或已被删除')),
      );
    }

    final DateTime now = DateTime.now();
    final ProgressEngine progress = state.progressEngine(now);
    final ProgressSnapshot snapshot = progress.of(goal.id);
    final MilestoneEngine milestone = state.milestoneEngine(now);
    final CommitmentEngine commitmentEngine = state.commitmentEngine(now);
    final List<UpdateRecord> records =
        state.data.recordsOf(goal.id).reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title),
        actions: <Widget>[
          IconButton(
            icon: Icon(goal.isFocus ? Icons.star : Icons.star_border),
            tooltip: goal.isFocus ? '取消首页聚焦' : '设为首页聚焦',
            onPressed: () => state.toggleFocus(goal.id),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑',
            onPressed: () => Navigator.of(context).pushNamed<void>(
              '/goal-editor',
              arguments: <String, Object?>{'goalId': goal.id},
            ),
          ),
          _GoalMenu(goal: goal),
        ],
      ),
      floatingActionButton: goal.mechanism == Mechanism.milestone
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).pushNamed<void>(
                '/goal-editor',
                arguments: <String, Object?>{'parentGoalId': goal.id},
              ),
              icon: const Icon(Icons.add),
              label: const Text('添加子项'),
            )
          : FloatingActionButton.extended(
              onPressed: () => showRecordSheet(context, goal: goal),
              icon: const Icon(Icons.edit),
              label: const Text('记录更新'),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: <Widget>[
          if (goal.parentGoalId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ParentChip(parentId: goal.parentGoalId!),
            ),
          if (goal.why.isNotEmpty)
            SectionCard(
              title: '为什么',
              children: <Widget>[
                Text(goal.why),
              ],
            ),
          if (goal.why.isNotEmpty) const SizedBox(height: 12),
          SectionCard(
            title: '达成条件',
            subtitle: goal.mechanism.completionRule,
            children: <Widget>[
              Text(
                goal.successCriteria.isEmpty
                    ? '（还没写清楚「怎样才算达成」）'
                    : goal.successCriteria,
                style: TextStyle(
                  fontStyle: goal.successCriteria.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '状态与进度',
            subtitle: '${goal.mechanism.label} · ${goal.mechanism.inputHint}',
            children: <Widget>[
              GoalProgressPanel(goal: goal, snapshot: snapshot),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '日期与时间参照',
            children: <Widget>[
              InfoRow(
                '起始',
                goal.startDate == null ? '未设置' : fmtDate(goal.startDate!),
                icon: Icons.play_arrow,
              ),
              InfoRow(
                '截止',
                goal.dueDate == null ? '未设置' : fmtDate(goal.dueDate!),
                icon: Icons.flag_outlined,
              ),
              InfoRow(
                '剩余',
                snapshot.timeElapsedRatio == null && goal.dueDate == null
                    ? '未设日期，不计算时间线'
                    : dueText(goal.dueDate, now),
                icon: Icons.hourglass_empty,
              ),
              if (goal.tags.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: goal.tags
                      .map((String t) => MiniChip(
                            label: t,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '没有日期的目标不算「落后」：时间线只是参照，不是压力来源。',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '当前承诺',
            subtitle: '承诺按机制的自然语义记录，未兑现不会判失败',
            trailing: TextButton.icon(
              onPressed: () => showCommitmentSheet(context, goal: goal),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('新建'),
            ),
            children: <Widget>[
              if (state.data.commitmentsOf(goal.id).isEmpty)
                const EmptyHint(
                  '这个周期还没有承诺。承诺是「我打算推进多少」，不是任务。',
                  icon: Icons.handshake_outlined,
                )
              else
                for (final Commitment c in state.data.commitmentsOf(goal.id))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CommitmentCard(
                      evaluation: commitmentEngine.evaluate(c),
                      showGoalTitle: false,
                    ),
                  ),
            ],
          ),
          if (goal.mechanism == Mechanism.milestone) ...<Widget>[
            const SizedBox(height: 12),
            SectionCard(
              title: '子目标',
              subtitle: '父级进度由子项加权上卷，只读',
              children: <Widget>[
                MilestonePanel(parent: goal, engine: milestone),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SectionCard(
            title: '时间线',
            subtitle: '配置变更与真实推进分开记录',
            children: <Widget>[
              if (records.isEmpty)
                const EmptyHint('还没有记录。', icon: Icons.timeline)
              else
                for (final UpdateRecord r in records) _RecordRow(record: r),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParentChip extends StatelessWidget {
  const _ParentChip({required this.parentId});

  final String parentId;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppStateScope.of(context);
    final Goal? parent = state.goalById(parentId);
    if (parent == null) return const SizedBox.shrink();
    return ActionChip(
      avatar: const Icon(Icons.account_tree_outlined, size: 16),
      label: Text('子项 · 属于「${parent.title}」'),
      onPressed: () => Navigator.of(context)
          .pushNamed<void>('/goal-detail', arguments: parent.id),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record});

  final UpdateRecord record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isConfig = record.type == RecordType.configChange;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConfig ? scheme.tertiary : scheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    MiniChip(
                      label: record.type.label,
                      color: isConfig ? scheme.tertiary : scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      fmtDateTime(record.timestamp),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(_valueText(), style: theme.textTheme.bodyMedium),
                if (record.note.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    record.note,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                if (record.changeReason != null &&
                    record.changeReason!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    '原因：${record.changeReason}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _valueText() {
    final List<String> parts = <String>[];
    if (record.delta != null) {
      parts.add('增量 ${record.delta! >= 0 ? '+' : '−'}${fmtNum(record.delta!.abs())}');
    }
    if (record.reading != null) parts.add('读数 ${fmtNum(record.reading!)}');
    if (record.selfRating != null) {
      parts.add('自评 ${fmtNum(record.selfRating!)}%');
    }
    if (record.done != null) parts.add(record.done! ? '标记完成' : '撤销完成');
    for (final MapEntry<String, String> e in record.configChanges.entries) {
      parts.add('${e.key}：${e.value}');
    }
    if (record.fromLifecycle != null && record.toLifecycle != null) {
      parts.add('${record.fromLifecycle!.label} → ${record.toLifecycle!.label}');
    }
    if (parts.isEmpty) return '—';
    return parts.join(' · ');
  }
}

class _GoalMenu extends StatelessWidget {
  const _GoalMenu({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppStateScope.of(context);
    return PopupMenuButton<String>(
      onSelected: (String value) async {
        switch (value) {
          case 'pause':
            state.setLifecycle(goal.id, Lifecycle.paused, reason: '手动暂停');
            break;
          case 'resume':
            state.setLifecycle(goal.id, Lifecycle.active);
            break;
          case 'complete':
            state.setLifecycle(goal.id, Lifecycle.completed, reason: '手动标记完成');
            break;
          case 'terminate':
            state.setLifecycle(
              goal.id,
              Lifecycle.terminated,
              reason: '手动终止',
            );
            break;
          case 'reopen':
            state.reopenGoal(goal.id, reason: '手动重新打开');
            break;
          case 'archive':
            state.toggleArchive(goal.id);
            break;
          case 'delete':
            final bool? ok = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Text('删除目标？'),
                content: const Text('子目标、时间线与该目标的承诺会一起删除。'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              state.deleteGoal(goal.id);
              if (context.mounted) Navigator.of(context).pop();
            }
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        if (goal.lifecycle == Lifecycle.active)
          const PopupMenuItem<String>(value: 'pause', child: Text('暂停')),
        if (goal.lifecycle == Lifecycle.paused ||
            goal.lifecycle == Lifecycle.pending)
          const PopupMenuItem<String>(
            value: 'resume',
            child: Text('开始 / 继续'),
          ),
        if (!goal.isCompleted)
          const PopupMenuItem<String>(
            value: 'complete',
            child: Text('标记完成'),
          ),
        if (!goal.isClosed)
          const PopupMenuItem<String>(value: 'terminate', child: Text('终止')),
        if (goal.isClosed)
          const PopupMenuItem<String>(
            value: 'reopen',
            child: Text('重新打开'),
          ),
        PopupMenuItem<String>(
          value: 'archive',
          child: Text(goal.isArchived ? '取消归档' : '归档'),
        ),
        const PopupMenuItem<String>(value: 'delete', child: Text('删除')),
      ],
    );
  }
}
