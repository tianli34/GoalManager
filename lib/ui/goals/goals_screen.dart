import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/goal.dart';
import '../../domain/progress.dart';
import '../../state/app_state.dart';
import '../app_scope.dart';
import '../widgets/common.dart';

/// 目标列表：按生命周期分组 + 领域/标签筛选 + 树结构（只渲染当前层）。
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final TextEditingController _search = TextEditingController();
  final Set<String> _expanded = <String>{};
  String _tag = '';
  bool _showArchived = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Goal> _visible(AppState state, List<Lifecycle> lifecycles) {
    final String query = _search.text.trim().toLowerCase();
    return state.data.goals.where((Goal g) {
      if (!lifecycles.contains(g.lifecycle)) return false;
      if (g.isArchived && !_showArchived) return false;
      if (_tag.isNotEmpty && !g.tags.contains(_tag)) return false;
      if (query.isEmpty) return true;
      return g.title.toLowerCase().contains(query) ||
          g.why.toLowerCase().contains(query) ||
          g.tags.any((String t) => t.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppStateScope.of(context);
    final ProgressEngine progress = state.progressEngine();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('目标'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: '进行中'),
              Tab(text: '待开始/暂停'),
              Tab(text: '已完成/终止'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              Navigator.of(context).pushNamed<void>('/goal-editor'),
          icon: const Icon(Icons.add),
          label: const Text('新建目标'),
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: '搜索目标、说明或标签',
                ),
              ),
            ),
            _buildTagRow(state),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _buildList(state, progress, <Lifecycle>[Lifecycle.active]),
                  _buildList(
                    state,
                    progress,
                    <Lifecycle>[Lifecycle.pending, Lifecycle.paused],
                  ),
                  _buildList(
                    state,
                    progress,
                    <Lifecycle>[Lifecycle.completed, Lifecycle.terminated],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagRow(AppState state) {
    final List<String> tags = state.allTags;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('全部'),
              selected: _tag.isEmpty,
              onSelected: (_) => setState(() => _tag = ''),
            ),
          ),
          for (final String tag in tags)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(tag),
                selected: _tag == tag,
                onSelected: (_) => setState(() => _tag = tag),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('含已归档'),
              selected: _showArchived,
              onSelected: (bool v) => setState(() => _showArchived = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    AppState state,
    ProgressEngine progress,
    List<Lifecycle> lifecycles,
  ) {
    final List<Goal> all = _visible(state, lifecycles);
    final List<Goal> roots =
        all.where((Goal g) => g.parentGoalId == null).toList()
          ..sort((Goal a, Goal b) => a.createdAt.compareTo(b.createdAt));

    if (roots.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const SizedBox(height: 40),
          const EmptyHint(
            '这里还没有目标。先随手记下一个想法，再决定它属于哪种机制。',
            icon: Icons.flag_outlined,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: <Widget>[
        for (final Goal goal in roots)
          _GoalTile(
            goal: goal,
            progress: progress,
            depth: 0,
            all: all,
            expanded: _expanded,
            onToggle: (String id) => setState(() {
              if (_expanded.contains(id)) {
                _expanded.remove(id);
              } else {
                _expanded.add(id);
              }
            }),
          ),
      ],
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.goal,
    required this.progress,
    required this.depth,
    required this.all,
    required this.expanded,
    required this.onToggle,
  });

  final Goal goal;
  final ProgressEngine progress;
  final int depth;
  final List<Goal> all;
  final Set<String> expanded;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppState state = AppStateScope.of(context);
    final ProgressSnapshot snapshot = progress.of(goal.id);
    final List<Goal> children =
        all.where((Goal g) => g.parentGoalId == goal.id).toList()
          ..sort((Goal a, Goal b) => a.sortOrder.compareTo(b.sortOrder));
    final bool isOpen = expanded.contains(goal.id);
    final DateTime now = DateTime.now();

    return Padding(
      padding: EdgeInsets.only(left: depth * 12.0, bottom: 8),
      child: Column(
        children: <Widget>[
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context)
                  .pushNamed<void>('/goal-detail', arguments: goal.id),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            goal.title,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (children.isNotEmpty)
                          IconButton(
                            onPressed: () => onToggle(goal.id),
                            icon: Icon(
                              isOpen
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_right,
                              size: 20,
                            ),
                          ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (String value) =>
                              _onMenu(context, state, value),
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'focus',
                              child: Text(goal.isFocus
                                  ? '取消首页聚焦'
                                  : '设为首页聚焦'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('编辑'),
                            ),
                            if (goal.lifecycle == Lifecycle.active)
                              const PopupMenuItem<String>(
                                value: 'pause',
                                child: Text('暂停'),
                              ),
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
                            if (goal.isClosed)
                              const PopupMenuItem<String>(
                                value: 'reopen',
                                child: Text('重新打开'),
                              ),
                            PopupMenuItem<String>(
                              value: 'archive',
                              child: Text(goal.isArchived
                                  ? '取消归档'
                                  : '归档'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('删除'),
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
                          label: goal.mechanism.label,
                          icon: _mechanismIcon(goal.mechanism),
                          color: scheme.primary,
                        ),
                        MiniChip(
                          label: goal.lifecycle.label,
                          color: scheme.secondary,
                        ),
                        if (goal.isFocus)
                          MiniChip(
                            label: '聚焦',
                            icon: Icons.center_focus_weak,
                            color: scheme.tertiary,
                          ),
                        if (goal.dueDate != null)
                          MiniChip(
                            label: dueText(goal.dueDate, now),
                            icon: goal.isOverdue(now)
                                ? Icons.warning_amber
                                : Icons.event,
                            color: goal.isOverdue(now)
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                          ),
                        for (final String tag in goal.tags.take(3))
                          MiniChip(
                            label: tag,
                            color: scheme.onSurfaceVariant,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    PercentBar(
                      percent: snapshot.percent,
                      planned: snapshot.plannedPercent,
                      height: 6,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Text(
                          '${fmtPercent(snapshot.percent)} · ${snapshot.rawText}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const Spacer(),
                        if (children.isNotEmpty)
                          Text(
                            '${children.length} 个子项',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isOpen)
            for (final Goal child in children)
              _GoalTile(
                goal: child,
                progress: progress,
                depth: depth + 1,
                all: all,
                expanded: expanded,
                onToggle: onToggle,
              ),
        ],
      ),
    );
  }

  IconData _mechanismIcon(Mechanism m) => switch (m) {
        Mechanism.completion => Icons.check_circle_outline,
        Mechanism.cumulative => Icons.add_chart,
        Mechanism.metric => Icons.show_chart,
        Mechanism.subjective => Icons.self_improvement,
        Mechanism.milestone => Icons.account_tree_outlined,
      };

  Future<void> _onMenu(
    BuildContext context,
    AppState state,
    String value,
  ) async {
    switch (value) {
      case 'focus':
        state.toggleFocus(goal.id);
        break;
      case 'edit':
        await Navigator.of(context).pushNamed<void>(
          '/goal-editor',
          arguments: <String, Object?>{'goalId': goal.id},
        );
        break;
      case 'pause':
        await _askReason(context, (String reason) =>
            state.setLifecycle(goal.id, Lifecycle.paused, reason: reason));
        break;
      case 'resume':
        state.setLifecycle(goal.id, Lifecycle.active);
        break;
      case 'complete':
        state.setLifecycle(goal.id, Lifecycle.completed, reason: '手动标记完成');
        break;
      case 'reopen':
        await _askReason(context,
            (String reason) => state.reopenGoal(goal.id, reason: reason));
        break;
      case 'archive':
        state.toggleArchive(goal.id);
        break;
      case 'delete':
        final bool? ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('删除目标？'),
            content: const Text('子目标、更新记录与该目标的承诺都会一起删除，且无法撤销。'),
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
        if (ok == true) state.deleteGoal(goal.id);
        break;
    }
  }

  Future<void> _askReason(
    BuildContext context,
    ValueChanged<String> onDone,
  ) async {
    final TextEditingController controller = TextEditingController();
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('原因（会记进时间线）'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(hintText: '为什么调整？'),
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
    if (reason != null) onDone(reason);
  }
}
