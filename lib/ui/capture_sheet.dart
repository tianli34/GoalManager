import 'package:flutter/material.dart';

import '../data/models/enums.dart';
import '../data/models/goal.dart';
import '../state/app_state.dart';
import 'app_scope.dart';
import 'goals/widgets/record_input.dart';
import 'widgets/common.dart';

/// 全局 FAB：捕获想法 / 更新已有目标。
Future<void> showCaptureSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => const _CaptureSheet(),
  );
}

class _CaptureSheet extends StatefulWidget {
  const _CaptureSheet();

  @override
  State<_CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends State<_CaptureSheet> {
  final TextEditingController _text = TextEditingController();
  final TextEditingController _search = TextEditingController();
  bool _picking = false;

  @override
  void dispose() {
    _text.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = AppStateScope.of(context);
    final String query = _search.text.trim().toLowerCase();
    final List<Goal> goals = state.data.goals
        .where((Goal g) =>
            !g.isClosed &&
            !g.isArchived &&
            g.mechanism != Mechanism.milestone &&
            (query.isEmpty || g.title.toLowerCase().contains(query)))
        .toList()
      ..sort((Goal a, Goal b) => a.title.compareTo(b.title));

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!_picking) ...<Widget>[
            TextField(
              controller: _text,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '脑子里在转什么？',
                hintText: '先记下来，之后再决定它是不是一个目标',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                final String text = _text.text.trim();
                if (text.isEmpty) return;
                state.capture(text);
                showMessage(context, '已收进收集箱');
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.inbox),
              label: const Text('收进收集箱'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() => _picking = true),
              icon: const Icon(Icons.edit),
              label: const Text('更新已有目标'),
            ),
          ] else ...<Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => setState(() => _picking = false),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    '要更新哪个目标？',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: '搜索目标',
              ),
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
                    leading: MiniChip(
                      label: goal.mechanism.label,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(goal.title),
                    onTap: () {
                      Navigator.of(context).pop();
                      showRecordSheet(context, goal: goal);
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
