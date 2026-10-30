import 'package:flutter/material.dart';

import '../../../core/date_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/goal.dart';
import '../../../domain/milestone.dart';
import '../../../state/app_state.dart';
import '../../app_scope.dart';
import '../../widgets/common.dart';

/// 里程碑的子项区块：并列用「方框」，串行用「①②③ + 竖向连接线」。
class MilestonePanel extends StatelessWidget {
  const MilestonePanel({
    super.key,
    required this.parent,
    required this.engine,
  });

  final Goal parent;
  final MilestoneEngine engine;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = AppStateScope.of(context);
    final List<MilestoneChildView> children = engine.childrenOf(parent.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('执行模式', style: theme.textTheme.labelLarge),
            const SizedBox(width: 12),
            Expanded(
              child: SegmentedButton<ExecutionMode>(
                segments: ExecutionMode.values
                    .map(
                      (ExecutionMode m) => ButtonSegment<ExecutionMode>(
                        value: m,
                        label: Text(m.label),
                      ),
                    )
                    .toList(),
                selected: <ExecutionMode>{parent.executionMode},
                onSelectionChanged: (Set<ExecutionMode> next) =>
                    state.setExecutionMode(parent.id, next.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          parent.executionMode.hint,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (children.isEmpty)
          const EmptyHint(
            '还没有子项。子项可以是任意机制的目标，进度会加权上卷到这里。',
            icon: Icons.account_tree_outlined,
          )
        else
          for (int i = 0; i < children.length; i++)
            _ChildRow(
              view: children[i],
              isLast: i == children.length - 1,
              sequential: parent.executionMode == ExecutionMode.sequential,
            ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pushNamed<void>(
            '/goal-editor',
            arguments: <String, Object?>{'parentGoalId': parent.id},
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('添加子项'),
        ),
      ],
    );
  }
}

class _ChildRow extends StatelessWidget {
  const _ChildRow({
    required this.view,
    required this.isLast,
    required this.sequential,
  });

  final MilestoneChildView view;
  final bool isLast;
  final bool sequential;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppState state = AppStateScope.of(context);
    final Goal goal = view.goal;
    final bool dim = view.state == MilestoneChildState.locked;

    final Color accent = switch (view.state) {
      MilestoneChildState.completed => scheme.primary,
      MilestoneChildState.frozen => scheme.secondary,
      MilestoneChildState.regression => scheme.error,
      MilestoneChildState.active => scheme.primary,
      MilestoneChildState.locked => scheme.onSurfaceVariant,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IntrinsicHeight(
        child: Opacity(
          opacity: dim ? 0.55 : 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 34,
                child: Column(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: view.state == MilestoneChildState.active ||
                              view.state == MilestoneChildState.completed ||
                              view.state == MilestoneChildState.frozen
                          ? accent
                          : scheme.surfaceContainerHighest,
                      child: _badge(accent, scheme),
                    ),
                    if (sequential && !isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: accent.withValues(alpha: 0.35),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).pushNamed<void>(
                      '/goal-detail',
                      arguments: goal.id,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  goal.title,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18),
                                onSelected: (String value) =>
                                    _onMenu(context, state, value),
                                itemBuilder: (BuildContext context) =>
                                    <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'up',
                                    child: Text('上移'),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'down',
                                    child: Text('下移'),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'weight',
                                    child: Text('设置权重'),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'required',
                                    child: Text(goal.isRequired
                                        ? '取消「必需」'
                                        : '标记为必需'),
                                  ),
                                  if (view.state ==
                                      MilestoneChildState.locked)
                                    const PopupMenuItem<String>(
                                      value: 'force',
                                      child: Text('提前开始（软锁定可破）'),
                                    ),
                                  if (goal.mechanism == Mechanism.metric &&
                                      view.state !=
                                          MilestoneChildState.frozen)
                                    const PopupMenuItem<String>(
                                      value: 'freeze',
                                      child: Text('固化（停止接收新读数）'),
                                    ),
                                  if (view.state ==
                                      MilestoneChildState.frozen)
                                    const PopupMenuItem<String>(
                                      value: 'unfreeze',
                                      child: Text('取消固化'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: <Widget>[
                              MiniChip(
                                label: view.state.label,
                                color: accent,
                              ),
                              MiniChip(
                                label: '${goal.mechanism.label} ${fmtPercent(view.progress.percent)}',
                                color: scheme.onSurfaceVariant,
                              ),
                              if (goal.isRequired)
                                MiniChip(
                                  label: '必需 · 权重 ${fmtNum(goal.weight)}',
                                  color: scheme.tertiary,
                                ),
                              if (view.isFocus)
                                MiniChip(
                                  label: '当前聚焦',
                                  icon: Icons.center_focus_weak,
                                  color: scheme.primary,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          PercentBar(
                            percent: view.progress.percent,
                            planned: view.expectedPercent,
                            height: 6,
                          ),
                          if (view.paceText != null) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              view.paceText!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (view.state == MilestoneChildState.regression) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              '原始量回退了，但已解锁不回退：你可以补记录，或重新打开这一项。',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.error),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(Color accent, ColorScheme scheme) {
    switch (view.state) {
      case MilestoneChildState.completed:
        return const Icon(Icons.check, size: 16, color: Colors.white);
      case MilestoneChildState.frozen:
        return const Icon(Icons.lock_outline, size: 15, color: Colors.white);
      case MilestoneChildState.regression:
        return const Icon(Icons.priority_high, size: 15, color: Colors.white);
      case MilestoneChildState.active:
      case MilestoneChildState.locked:
        return Text(
          '${view.index}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: view.state == MilestoneChildState.active
                ? Colors.white
                : scheme.onSurfaceVariant,
          ),
        );
    }
  }

  Future<void> _onMenu(
    BuildContext context,
    AppState state,
    String value,
  ) async {
    final Goal goal = view.goal;
    switch (value) {
      case 'up':
        state.moveChild(goal.id, -1);
        break;
      case 'down':
        state.moveChild(goal.id, 1);
        break;
      case 'weight':
        final double? next = await _promptNumber(
          context,
          title: '权重（只在同一个父目标下有效）',
          initial: goal.weight,
        );
        if (next != null) state.updateChildLink(goal.id, weight: next);
        break;
      case 'required':
        state.updateChildLink(goal.id, isRequired: !goal.isRequired);
        break;
      case 'force':
        state.forceStartChild(goal.id);
        break;
      case 'freeze':
        state.freezeChild(goal.id);
        break;
      case 'unfreeze':
        state.unfreezeChild(goal.id);
        break;
    }
  }
}

Future<double?> _promptNumber(
  BuildContext context, {
  required String title,
  required double initial,
}) async {
  final TextEditingController controller =
      TextEditingController(text: fmtNum(initial));
  final double? result = await showDialog<double>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(double.tryParse(controller.text)),
            child: const Text('保存'),
          ),
        ],
      );
    },
  );
  return result;
}
