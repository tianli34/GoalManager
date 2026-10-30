import 'package:flutter/material.dart';

import '../../../core/date_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/goal.dart';
import '../../../domain/progress.dart';
import '../../widgets/common.dart';

/// 「状态与进度解释」区块：只按机制切换这一块，其余骨架共用。
class GoalProgressPanel extends StatelessWidget {
  const GoalProgressPanel({
    super.key,
    required this.goal,
    required this.snapshot,
  });

  final Goal goal;
  final ProgressSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double? planned = snapshot.plannedPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              fmtPercent(snapshot.percent),
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                snapshot.rawText,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PercentBar(percent: snapshot.percent, planned: planned),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Text('实际 ${fmtPercent(snapshot.percent)}',
                style: theme.textTheme.bodySmall),
            if (planned != null) ...<Widget>[
              const SizedBox(width: 12),
              Text('计划 ${fmtPercent(planned)}（竖线）',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
        if (snapshot.paceText != null) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.timeline, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  snapshot.paceText!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
        if (snapshot.timeElapsedRatio != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            '时间消耗 ${fmtPercent(snapshot.timeElapsedRatio! * 100)}'
            '${snapshot.timeElapsedRatio! > 1 ? '（已超过截止日）' : ''}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: <Widget>[
            MiniChip(
              label: '完成判定：${goal.mechanism.completionRule}',
              icon: snapshot.isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
              color: snapshot.isComplete ? scheme.primary : scheme.onSurfaceVariant,
            ),
            MiniChip(
              label: '生命周期：${goal.lifecycle.label}',
              icon: Icons.flag_outlined,
              color: scheme.secondary,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ExpansionTile(
          dense: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(
            '这个值是怎么算出来的',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              decoration: TextDecoration.underline,
            ),
          ),
          children: <Widget>[
            const SizedBox(height: 4),
            for (final String note in snapshot.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('· ', style: theme.textTheme.bodySmall),
                    Expanded(
                      child: Text(note, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
