import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../data/models/commitment.dart';
import '../../data/models/enums.dart';
import '../../domain/commitments.dart';
import '../../state/app_state.dart';
import '../app_scope.dart';
import 'common.dart';

class CommitmentCard extends StatelessWidget {
  const CommitmentCard({
    super.key,
    required this.evaluation,
    this.showGoalTitle = true,
  });

  final CommitmentEvaluation evaluation;
  final bool showGoalTitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppState state = AppStateScope.of(context);
    final Commitment c = evaluation.commitment;
    final bool active = c.status == CommitmentStatus.active;
    final double ratio = evaluation.ratio.isNaN
        ? 0
        : evaluation.ratio.clamp(0.0, 1.0).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    showGoalTitle ? evaluation.goalTitle : '承诺',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                MiniChip(
                  label: c.status.label,
                  color: switch (c.status) {
                    CommitmentStatus.fulfilled => scheme.primary,
                    CommitmentStatus.active => scheme.secondary,
                    CommitmentStatus.adjusted => scheme.tertiary,
                    CommitmentStatus.cancelled => scheme.onSurfaceVariant,
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${fmtDate(c.start)} ~ ${fmtDate(c.end)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              evaluation.expectationOnly
                  ? '结果期望：${evaluation.targetText}'
                  : '承诺：${evaluation.targetText}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 2),
            Text(
              evaluation.actualText,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (!evaluation.expectationOnly) ...<Widget>[
              const SizedBox(height: 8),
              PercentBar(percent: ratio * 100, height: 6),
            ],
            if (c.note.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                '备注：${c.note}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (active) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => state.markCommitmentFulfilled(c.id),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('标记兑现'),
                  ),
                  TextButton.icon(
                    onPressed: () => _ask(context, state, c.id, adjust: true),
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('调整'),
                  ),
                  TextButton.icon(
                    onPressed: () => _ask(context, state, c.id, adjust: false),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('取消'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _ask(
    BuildContext context,
    AppState state,
    String id, {
    required bool adjust,
  }) async {
    final TextEditingController controller = TextEditingController();
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(adjust ? '为什么调整这条承诺？' : '为什么取消这条承诺？'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(hintText: '写一句，会留在承诺历史里'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    if (adjust) {
      state.adjustCommitment(id, reason);
    } else {
      state.cancelCommitment(id, reason);
    }
  }
}
