import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/goal.dart';
import '../../data/models/inbox_item.dart';
import '../../state/app_state.dart';
import '../app_scope.dart';
import '../widgets/common.dart';

/// 收集箱：不要求机制、不要求日期，也不参与任何统计。
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = AppStateScope.of(context);
    final List<InboxItem> pending = state.data.inbox
        .where((InboxItem i) => i.isPending)
        .toList();
    final List<InboxItem> resolved = state.data.inbox
        .where((InboxItem i) => !i.isPending)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('收集箱')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _text,
                  decoration: const InputDecoration(
                    hintText: '脑子里在转什么？先记下来',
                  ),
                  onSubmitted: (String v) => _add(state, v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _add(state, _text.text),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '这里不需要想清楚机制或日期。之后再决定它要成为目标、并入已有目标，还是舍弃。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: '待处理',
            subtitle: '只有三条出路：转为目标 / 并入已有目标 / 舍弃',
            children: <Widget>[
              if (pending.isEmpty)
                const EmptyHint('收集箱是空的。想起来什么就先扔进来。')
              else
                for (final InboxItem item in pending)
                  _PendingRow(item: item),
            ],
          ),
          if (resolved.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            SectionCard(
              title: '已处理',
              children: <Widget>[
                for (final InboxItem item in resolved)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      item.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Text(item.status.label),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _add(AppState state, String raw) {
    final String text = raw.trim();
    if (text.isEmpty) return;
    state.capture(text);
    _text.clear();
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.item});

  final InboxItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = AppStateScope.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(item.text, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text(
            fmtDateTime(item.createdAt),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          Wrap(
            spacing: 4,
            children: <Widget>[
              TextButton.icon(
                onPressed: () => _convert(context, state),
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: const Text('转为目标'),
              ),
              TextButton.icon(
                onPressed: () => _merge(context, state),
                icon: const Icon(Icons.call_merge, size: 16),
                label: const Text('并入已有目标'),
              ),
              TextButton.icon(
                onPressed: () => state.discardInboxItem(item.id),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('舍弃'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _convert(BuildContext context, AppState state) async {
    final Mechanism? mechanism = await showModalBottomSheet<Mechanism>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '它会用哪种机制推进？',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final Mechanism m in Mechanism.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.label),
                  subtitle: Text(m.inputHint),
                  onTap: () => Navigator.of(context).pop(m),
                ),
            ],
          ),
        );
      },
    );
    if (mechanism == null) return;
    final Goal goal = state.convertInboxItemToGoal(
      item.id,
      mechanism: mechanism,
      startValue: mechanism == Mechanism.cumulative ? 0 : null,
      currentValue: mechanism == Mechanism.cumulative ? 0 : null,
    );
    if (!context.mounted) return;
    showMessage(context, '已转为目标，去补全达成条件吧');
    await Navigator.of(context)
        .pushNamed<void>('/goal-detail', arguments: goal.id);
  }

  Future<void> _merge(BuildContext context, AppState state) async {
    final List<Goal> goals = state.data.goals
        .where((Goal g) => !g.isClosed && !g.isArchived)
        .toList()
      ..sort((Goal a, Goal b) => a.title.compareTo(b.title));

    final String? goalId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '并到哪个目标？',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: goals.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Goal goal = goals[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(goal.title),
                      subtitle: Text(goal.mechanism.label),
                      onTap: () => Navigator.of(context).pop(goal.id),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (goalId == null) return;
    state.mergeInboxItem(item.id, goalId);
    if (!context.mounted) return;
    showMessage(context, '已并入目标时间线');
    await Navigator.of(context)
        .pushNamed<void>('/goal-detail', arguments: goalId);
  }
}
