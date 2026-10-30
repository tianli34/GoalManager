import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../data/models/app_data.dart';
import '../../data/models/commitment.dart';
import '../../data/models/enums.dart';
import '../../data/models/goal.dart';
import '../../data/models/review.dart';
import '../../data/models/update_record.dart';
import '../../domain/commitments.dart';
import '../../domain/progress.dart';
import '../../state/app_state.dart';
import '../app_scope.dart';
import '../widgets/common.dart';

/// 「回顾」：本周期变化 → 三问复盘 → 决定 → （下一期承诺在目标页建）。
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  String _period = 'week';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = AppStateScope.of(context);
    final DateTime now = DateTime.now();
    final DateWindow window =
        _period == 'week' ? currentWeek(now) : currentQuarter(now);
    final ProgressEngine progress = state.progressEngine(now);
    final CommitmentEngine commitmentEngine = state.commitmentEngine(now);

    final List<Review> reviews = List<Review>.from(state.data.reviews)
      ..sort((Review a, Review b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(title: const Text('回顾')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openReviewDialog(context, window),
        icon: const Icon(Icons.edit_note),
        label: const Text('写复盘'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: <Widget>[
          SegmentedButton<String>(
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(value: 'week', label: Text('本周')),
              ButtonSegment<String>(value: 'quarter', label: Text('本季度')),
            ],
            selected: <String>{_period},
            onSelectionChanged: (Set<String> next) =>
                setState(() => _period = next.first),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: '本周期变化',
            subtitle: '${fmtDate(window.start)} ~ ${fmtDate(window.end)}（只统计真实推进）',
            children: <Widget>[
              ..._changeLines(context, state, progress, window),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '历史复盘',
            subtitle: '产物的核心是 decision（继续 / 调整 / 暂停 / 结束）',
            children: <Widget>[
              if (reviews.isEmpty)
                const EmptyHint('还没有复盘。走一遍：记录事实 → 关注信号 → 复盘 → 决定。')
              else
                for (final Review r in reviews) _ReviewCard(review: r),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '达成记录',
            subtitle: '完成的目标、兑现的承诺',
            children: <Widget>[
              ..._achievements(context, state, commitmentEngine),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '回退与调整也会展示，但不计入「增长」。首版不做积分、等级和连续打卡。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  List<Widget> _changeLines(
    BuildContext context,
    AppState state,
    ProgressEngine progress,
    DateWindow window,
  ) {
    final ThemeData theme = Theme.of(context);
    final AppData data = state.data;
    final List<UpdateRecord> inWindow = data.records
        .where((UpdateRecord r) =>
            !r.timestamp.isBefore(window.start) &&
            !r.timestamp.isAfter(window.end))
        .toList();

    if (inWindow.isEmpty) {
      return <Widget>[
        const EmptyHint('这个周期还没有任何记录。', icon: Icons.timeline),
      ];
    }

    final Set<String> goalIds = inWindow
        .map((UpdateRecord r) => r.goalId)
        .where((String id) => data.goalById(id) != null)
        .toSet();

    final List<Widget> lines = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          '共 ${inWindow.length} 条记录，涉及 ${goalIds.length} 个目标',
          style: theme.textTheme.bodyMedium,
        ),
      ),
    ];

    for (final String id in goalIds) {
      final Goal goal = data.goalById(id)!;
      final double? before = progress.rawValueAt(goal, window.start);
      final double? after = progress.rawValueAt(goal, window.end);
      final List<UpdateRecord> mine =
          inWindow.where((UpdateRecord r) => r.goalId == id).toList();
      final int progresses = mine
          .where((UpdateRecord r) => r.type == RecordType.progress)
          .length;
      final int configs = mine
          .where((UpdateRecord r) => r.type == RecordType.configChange)
          .length;

      final String deltaText;
      if (before != null && after != null && after != before) {
        final double diff = after - before;
        deltaText = '${diff >= 0 ? '+' : '−'}${fmtNum(diff.abs())}${goal.unit.isEmpty ? '' : ' ${goal.unit}'}';
      } else {
        deltaText = '原始量无变化';
      }

      lines.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  goal.title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$deltaText · 记录 $progresses 条${configs == 0 ? '' : ' · 配置变更 $configs 条'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return lines;
  }

  List<Widget> _achievements(
    BuildContext context,
    AppState state,
    CommitmentEngine commitmentEngine,
  ) {
    final ThemeData theme = Theme.of(context);
    final AppData data = state.data;
    final List<Goal> done = data.goals
        .where((Goal g) => g.isCompleted)
        .toList();
    done.sort((Goal a, Goal b) {
      final DateTime at = data.completionTimeOf(b.id) ?? b.updatedAt;
      final DateTime bt = data.completionTimeOf(a.id) ?? a.updatedAt;
      return at.compareTo(bt);
    });

    final List<Commitment> fulfilled = data.commitments
        .where((Commitment c) => c.status == CommitmentStatus.fulfilled)
        .toList()
      ..sort((Commitment a, Commitment b) => b.createdAt.compareTo(a.createdAt));

    if (done.isEmpty && fulfilled.isEmpty) {
      return <Widget>[
        const EmptyHint('还没有完成的目标，也没有兑现的承诺。', icon: Icons.emoji_events_outlined),
      ];
    }

    return <Widget>[
      for (final Goal g in done.take(8))
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.check_circle_outline),
          title: Text(g.title),
          subtitle: Text(
            '${g.mechanism.label} · 完成于 ${_doneAt(data, g) ?? '未知'}',
          ),
          onTap: () => Navigator.of(context)
              .pushNamed<void>('/goal-detail', arguments: g.id),
        ),
      for (final Commitment c in fulfilled.take(8))
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.handshake_outlined),
          title: Text(
            commitmentEngine.evaluate(c).goalTitle,
          ),
          subtitle: Text('兑现承诺：${commitmentEngine.evaluate(c).targetText}'),
        ),
    ];
  }

  String? _doneAt(AppData data, Goal goal) {
    final DateTime? at = data.completionTimeOf(goal.id);
    return at == null ? null : fmtDate(at);
  }

  Future<void> _openReviewDialog(
    BuildContext context,
    DateWindow window,
  ) async {
    final AppState state = AppStateScope.of(context);
    final AppData data = state.data;
    final List<UpdateRecord> inWindow = data.records
        .where((UpdateRecord r) =>
            !r.timestamp.isBefore(window.start) &&
            !r.timestamp.isAfter(window.end))
        .toList();
    final List<String> goalIds = inWindow
        .map((UpdateRecord r) => r.goalId)
        .where((String id) => data.goalById(id) != null)
        .toSet()
        .toList();

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => _ReviewSheet(
        window: window,
        goalIds: goalIds,
        recordCount: inWindow.length,
        onSave: (
          String whatHappened,
          String stillWorth,
          bool? answer,
          ReviewDecision decision,
          String nextStep,
          bool apply,
        ) {
          final Review review = state.addReview(
            start: window.start,
            end: window.end,
            goalIds: goalIds,
            whatHappened: whatHappened,
            stillWorth: stillWorth,
            stillWorthAnswer: answer,
            decision: decision,
            nextStep: nextStep,
          );
          if (apply) state.applyReviewDecision(review.id);
        },
      ),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({
    required this.window,
    required this.goalIds,
    required this.recordCount,
    required this.onSave,
  });

  final DateWindow window;
  final List<String> goalIds;
  final int recordCount;
  final void Function(
    String whatHappened,
    String stillWorth,
    bool? answer,
    ReviewDecision decision,
    String nextStep,
    bool apply,
  ) onSave;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final TextEditingController _q1 = TextEditingController();
  final TextEditingController _q2 = TextEditingController();
  final TextEditingController _next = TextEditingController();
  bool? _answer;
  ReviewDecision _decision = ReviewDecision.cont;
  bool _apply = false;

  @override
  void dispose() {
    _q1.dispose();
    _q2.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = AppStateScope.of(context);
    final String goalTitles = widget.goalIds
        .map((String id) => state.goalById(id)?.title ?? id)
        .join('、');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '${widget.window.label}复盘',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '关联 ${widget.goalIds.length} 个目标 · 本周期 ${widget.recordCount} 条记录',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (goalTitles.isNotEmpty) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                goalTitles,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            Text('Q1 这周期实际发生了什么？', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            TextField(
              controller: _q1,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '只写事实，不评价自己',
              ),
            ),
            const SizedBox(height: 16),
            Text('Q2 原计划还值得继续吗？', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            TextField(
              controller: _q2,
              maxLines: 2,
              decoration: const InputDecoration(hintText: '为什么值得 / 为什么不值得'),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                ChoiceChip(
                  label: const Text('值得'),
                  selected: _answer == true,
                  onSelected: (_) => setState(() => _answer = true),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('不值得'),
                  selected: _answer == false,
                  onSelected: (_) => setState(() => _answer = false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Q3 决定', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<ReviewDecision>(
              segments: ReviewDecision.values
                  .map(
                    (ReviewDecision d) => ButtonSegment<ReviewDecision>(
                      value: d,
                      label: Text(d.label),
                    ),
                  )
                  .toList(),
              selected: <ReviewDecision>{_decision},
              onSelectionChanged: (Set<ReviewDecision> next) =>
                  setState(() => _decision = next.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _next,
              decoration: const InputDecoration(
                labelText: '下一步（只写一条）',
                hintText: '不引入任务模型，就一句话',
              ),
            ),
            if (_decision == ReviewDecision.pause ||
                _decision == ReviewDecision.end) ...<Widget>[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_decision == ReviewDecision.pause
                    ? '同时把关联目标设为「暂停」'
                    : '同时把关联目标设为「终止」'),
                value: _apply,
                onChanged: (bool v) => setState(() => _apply = v),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                widget.onSave(
                  _q1.text.trim(),
                  _q2.text.trim(),
                  _answer,
                  _decision,
                  _next.text.trim(),
                  _apply,
                );
                showMessage(context, '已记录这次复盘');
                Navigator.of(context).pop();
              },
              child: const Text('保存复盘'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = AppStateScope.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '${fmtDate(review.start)} ~ ${fmtDate(review.end)}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              MiniChip(
                label: '决定：${review.decision.label}',
                color: scheme.primary,
              ),
            ],
          ),
          if (review.goalIds.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              review.goalIds
                  .map((String id) => state.goalById(id)?.title ?? id)
                  .join('、'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if (review.whatHappened.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text('发生了什么：${review.whatHappened}'),
          ],
          if (review.stillWorth.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              '还值得吗：${review.stillWorth}'
              '${review.stillWorthAnswer == null ? '' : '（${review.stillWorthAnswer! ? '是' : '否'}）'}',
            ),
          ],
          if (review.nextStep != null && review.nextStep!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text('下一步：${review.nextStep}'),
          ],
        ],
      ),
    );
  }
}
