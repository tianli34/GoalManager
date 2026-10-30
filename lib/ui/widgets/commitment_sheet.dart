import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/goal.dart';
import '../../state/app_state.dart';
import '../app_scope.dart';
import 'common.dart';
import 'fields.dart';

/// 新建一条周期承诺：量按机制的自然语义存储。
Future<void> showCommitmentSheet(BuildContext context, {required Goal goal}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => _CommitmentSheet(goal: goal),
  );
}

class _CommitmentSheet extends StatefulWidget {
  const _CommitmentSheet({required this.goal});

  final Goal goal;

  @override
  State<_CommitmentSheet> createState() => _CommitmentSheetState();
}

class _CommitmentSheetState extends State<_CommitmentSheet> {
  final TextEditingController _delta = TextEditingController();
  final TextEditingController _points = TextEditingController();
  final TextEditingController _expectation = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String _window = 'week';
  String? _childId;

  Goal get goal => widget.goal;

  @override
  void dispose() {
    _delta.dispose();
    _points.dispose();
    _expectation.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = AppStateScope.of(context);
    final List<Goal> children = state.childrenOf(goal.id);
    if (_childId == null && children.isNotEmpty) {
      _childId = children.first.id;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '为「${goal.title}」许一个承诺',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '承诺的量按 ${goal.mechanism.label} 的自然语义记录；未兑现不会判失败，也不会改目标状态。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(value: 'week', label: Text('本周')),
              ButtonSegment<String>(value: 'next', label: Text('下周')),
              ButtonSegment<String>(value: 'quarter', label: Text('本季度')),
            ],
            selected: <String>{_window},
            onSelectionChanged: (Set<String> next) =>
                setState(() => _window = next.first),
          ),
          const SizedBox(height: 14),
          ...switch (goal.mechanism) {
            Mechanism.cumulative => <Widget>[
                NumberField(
                  controller: _delta,
                  label: '这个周期打算推进多少',
                  suffix: goal.unit.isEmpty ? null : goal.unit,
                  hint: '例如 2',
                ),
              ],
            Mechanism.completion => <Widget>[
                Text(
                  '完成型：承诺就是「这个周期内做完」。',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            Mechanism.subjective => <Widget>[
                NumberField(
                  controller: _points,
                  label: '自评推进多少点',
                  suffix: '%',
                  hint: '例如 10',
                ),
              ],
            Mechanism.milestone => <Widget>[
                if (children.isEmpty)
                  const EmptyHint('这个里程碑还没有子项，先去添加子项。')
                else ...<Widget>[
                  Text(
                    '承诺完成哪个子项',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: children
                        .map(
                          (Goal c) => ChoiceChip(
                            label: Text(c.title),
                            selected: _childId == c.id,
                            onSelected: (_) =>
                                setState(() => _childId = c.id),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            Mechanism.metric => <Widget>[
                AppTextField(
                  controller: _expectation,
                  label: '结果期望',
                  hint: '例如：月底读数到 74kg 左右',
                  maxLines: 2,
                ),
                const SizedBox(height: 6),
                Text(
                  '指标型承诺只作结果期望：没达到不会解读为你投入不足。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
          },
          const SizedBox(height: 12),
          AppTextField(
            controller: _note,
            label: '备注',
            hint: '可选',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _save(context),
            child: const Text('建立承诺'),
          ),
        ],
        ),
      ),
    );
  }

  void _save(BuildContext context) {
    final AppState state = AppStateScope.of(context);
    final DateTime now = DateTime.now();
    final DateWindow window = switch (_window) {
      'next' => nextWeek(now),
      'quarter' => currentQuarter(now),
      _ => currentWeek(now),
    };

    double? delta;
    double? points;
    String expectation = '';
    switch (goal.mechanism) {
      case Mechanism.cumulative:
        delta = parseNumber(_delta);
        if (delta == null || delta == 0) {
          showMessage(context, '请填写这个周期打算推进的量');
          return;
        }
        break;
      case Mechanism.subjective:
        points = parseNumber(_points);
        if (points == null || points == 0) {
          showMessage(context, '请填写自评推进的点数');
          return;
        }
        break;
      case Mechanism.metric:
        expectation = _expectation.text.trim();
        if (expectation.isEmpty) {
          showMessage(context, '请写下结果期望');
          return;
        }
        break;
      case Mechanism.milestone:
        if (_childId == null) {
          showMessage(context, '请先添加子项');
          return;
        }
        break;
      case Mechanism.completion:
        break;
    }

    state.addCommitment(
      goalId: goal.id,
      start: window.start,
      end: window.end,
      targetDelta: delta,
      targetDone: goal.mechanism == Mechanism.completion,
      targetRatingPoints: points,
      targetChildGoalId: _childId,
      expectation: expectation,
      note: _note.text.trim(),
    );
    showMessage(context, '已建立${window.label}的承诺');
    Navigator.of(context).pop();
  }
}
