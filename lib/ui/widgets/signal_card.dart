import 'package:flutter/material.dart';

import '../../data/models/enums.dart';
import '../../data/models/goal.dart';
import '../../domain/signals.dart';
import '../../state/app_state.dart';
import '../app_scope.dart';
import '../goals/widgets/record_input.dart';
import 'common.dart';

/// 关注信号卡片：解释「为什么提醒你」，并且一定给出操作入口。
class SignalCard extends StatelessWidget {
  const SignalCard({super.key, required this.item});

  final SignalItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppState state = AppStateScope.of(context);
    final Goal? goal = state.goalById(item.goalId);

    final Color color = switch (item.kind) {
      AttentionSignal.dateRisk => scheme.error,
      AttentionSignal.possibleStall => scheme.tertiary,
      AttentionSignal.noRecentUpdate => scheme.secondary,
      AttentionSignal.insufficientData => scheme.onSurfaceVariant,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(_icon(item.kind), size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  item.kind.label,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    item.goalTitle,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(item.reason, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 2),
            Text(
              item.actionHint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (goal != null) ...<Widget>[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => showRecordSheet(context, goal: goal),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('更新'),
                  ),
                  if (item.kind == AttentionSignal.noRecentUpdate ||
                      item.kind == AttentionSignal.insufficientData)
                    TextButton.icon(
                      onPressed: () {
                        state.confirmNoChange(goal.id);
                        showMessage(context, '已记录「确认无变化」');
                      },
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('确认无变化'),
                    ),
                  if (item.kind == AttentionSignal.possibleStall)
                    TextButton.icon(
                      onPressed: () => _writeNote(context, state, goal.id),
                      icon: const Icon(Icons.notes, size: 16),
                      label: const Text('写说明'),
                    ),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed<void>(
                      '/goal-editor',
                      arguments: <String, Object?>{'goalId': goal.id},
                    ),
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('调整'),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        state.setLifecycle(goal.id, Lifecycle.paused, reason: '从提醒里暂停'),
                    icon: const Icon(Icons.pause, size: 16),
                    label: const Text('暂停'),
                  ),
                  TextButton.icon(
                    onPressed: () => state.setLifecycle(
                      goal.id,
                      Lifecycle.terminated,
                      reason: '从提醒里结束',
                    ),
                    icon: const Icon(Icons.stop, size: 16),
                    label: const Text('结束'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _icon(AttentionSignal kind) => switch (kind) {
        AttentionSignal.dateRisk => Icons.event_busy,
        AttentionSignal.possibleStall => Icons.trending_flat,
        AttentionSignal.noRecentUpdate => Icons.schedule,
        AttentionSignal.insufficientData => Icons.help_outline,
      };

  Future<void> _writeNote(
    BuildContext context,
    AppState state,
    String goalId,
  ) async {
    final TextEditingController controller = TextEditingController();
    final String? note = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('写一句说明'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '发生了什么？卡在哪？'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('记录'),
          ),
        ],
      ),
    );
    if (note != null && note.isNotEmpty) state.addNote(goalId, note);
  }
}
