import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../data/models/commitment.dart';
import '../../data/models/enums.dart';
import '../../data/models/goal.dart';
import '../../domain/commitments.dart';
import '../../domain/progress.dart';
import '../../domain/signals.dart';
import '../../state/app_state.dart';
import '../app_scope.dart';
import '../capture_sheet.dart';
import '../widgets/commitment_card.dart';
import '../widgets/common.dart';
import '../widgets/signal_card.dart';

/// 「当下」：本期承诺 + 重点目标 + 需要关注 + 收集箱入口。
///
/// 只渲染筛选后的少数目标和带解释的信号：
/// 不做全量进度环、统计总分、逾期红色长列表。
class NowScreen extends StatelessWidget {
  const NowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = AppStateScope.of(context);
    final DateTime now = DateTime.now();
    final DateWindow week = currentWeek(now);
    final ProgressEngine progress = state.progressEngine(now);
    final CommitmentEngine commitmentEngine = state.commitmentEngine(now);
    final List<SignalItem> signals = state.signalEngine(now).all();
    final List<Commitment> commitments = commitmentEngine.inWindow(week);
    final List<Goal> focusGoals = state.data.goals
        .where((Goal g) =>
            g.isFocus && g.lifecycle == Lifecycle.active && !g.isArchived)
        .toList();
    final int pendingInbox =
        state.data.inbox.where((element) => element.isPending).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('当下'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.inbox_outlined),
            tooltip: '收集箱',
            onPressed: () => Navigator.of(context).pushNamed<void>('/inbox'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCaptureSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('捕获 / 更新'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: <Widget>[
          Text(
            '${week.label} ${fmtDateCn(week.start)} ~ ${fmtDateCn(week.end)}',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '只放这一周真正要推进的事，其余的都在「目标」里。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: '本期承诺',
            subtitle: '承诺是「我打算推进多少」，不是任务；未兑现不会判失败',
            children: <Widget>[
              if (commitments.isEmpty)
                const EmptyHint(
                  '这一周还没有承诺。到某个目标详情页点「新建」即可。',
                  icon: Icons.handshake_outlined,
                )
              else
                for (final Commitment c in commitments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CommitmentCard(
                      evaluation: commitmentEngine.evaluate(c),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '重点目标',
            subtitle:
                '建议聚焦 ${state.settings.focusSuggestion} 个左右，当前 ${focusGoals.length} 个（软性引导）',
            children: <Widget>[
              if (focusGoals.isEmpty)
                const EmptyHint(
                  '还没有重点目标。在目标列表里长按或点菜单，选「设为首页聚焦」。',
                  icon: Icons.star_border,
                )
              else
                for (final Goal goal in focusGoals)
                  _FocusRow(goal: goal, snapshot: progress.of(goal.id)),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '需要关注',
            subtitle: '信号都来自真实记录，每一条都带一个动作',
            children: <Widget>[
              if (signals.isEmpty)
                const EmptyHint(
                  '暂时没有需要关注的事。',
                  icon: Icons.check_circle_outline,
                )
              else
                for (final SignalItem item in signals.take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SignalCard(item: item),
                  ),
              if (signals.length > 6)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '还有 ${signals.length - 6} 条，处理完前面的再看。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '收集箱',
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.inbox_outlined),
                title: Text(pendingInbox == 0
                    ? '收集箱是空的'
                    : '$pendingInbox 条待处理'),
                subtitle: const Text('不要求机制、不要求日期，也不参与统计'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.of(context).pushNamed<void>('/inbox'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FocusRow extends StatelessWidget {
  const _FocusRow({required this.goal, required this.snapshot});

  final Goal goal;
  final ProgressSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = AppStateScope.of(context);
    final DateTime now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => Navigator.of(context)
            .pushNamed<void>('/goal-detail', arguments: goal.id),
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
                Text(
                  fmtPercent(snapshot.percent),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.star, size: 18),
                  tooltip: '取消聚焦',
                  onPressed: () => state.toggleFocus(goal.id),
                ),
              ],
            ),
            const SizedBox(height: 4),
            PercentBar(
              percent: snapshot.percent,
              planned: snapshot.plannedPercent,
              height: 6,
            ),
            const SizedBox(height: 3),
            Text(
              '${snapshot.rawText}'
              '${goal.dueDate == null ? '' : ' · ${dueText(goal.dueDate, now)}'}'
              '${snapshot.paceText == null ? '' : ' · ${snapshot.paceText}'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
