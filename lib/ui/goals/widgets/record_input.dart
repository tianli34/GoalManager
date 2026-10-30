import 'package:flutter/material.dart';

import '../../../core/date_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/goal.dart';
import '../../../state/app_state.dart';
import '../../app_scope.dart';
import '../../widgets/fields.dart';

/// 按机制切换的「轻量更新入口」。
Future<void> showRecordSheet(BuildContext context, {required Goal goal}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => _RecordSheet(goal: goal),
  );
}

class _RecordSheet extends StatefulWidget {
  const _RecordSheet({required this.goal});

  final Goal goal;

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  final TextEditingController _note = TextEditingController();
  final TextEditingController _number = TextEditingController();
  double _rating = 0;

  /// 累积型支持两种输入：增量 Δ，或直接给当前累计值（读数）。
  bool _useDelta = true;

  Goal get goal => widget.goal;

  @override
  void initState() {
    super.initState();
    _rating = (goal.currentValue ?? 0).clamp(0.0, 100.0).toDouble();
  }

  @override
  void dispose() {
    _note.dispose();
    _number.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final AppState state = AppStateScope.of(context);
    final String note = _note.text.trim();
    switch (goal.mechanism) {
      case Mechanism.completion:
        state.recordCompletion(goal.id, !goal.isCompleted, note: note);
        break;
      case Mechanism.cumulative:
        final double? value = parseNumber(_number);
        if (value == null) {
          _warn(_useDelta ? '请填写增量（可为负）' : '请填写当前累计值');
          return;
        }
        // 「直接设置当前值」也换算成增量存下来，保证时间线只有一种语义。
        final double delta = _useDelta
            ? value
            : value - (goal.currentValue ?? goal.startValue ?? 0);
        if (delta == 0) {
          _warn('和当前值一样，没有变化');
          return;
        }
        state.recordDelta(goal.id, delta, note: note);
        break;
      case Mechanism.metric:
        final double? reading = parseNumber(_number);
        if (reading == null) {
          _warn('请填写当前读数');
          return;
        }
        state.recordReading(goal.id, reading, note: note);
        break;
      case Mechanism.subjective:
        state.recordRating(goal.id, _rating, note: note);
        break;
      case Mechanism.milestone:
        _warn('里程碑的进度来自子项，请到子目标里记录');
        return;
    }
    Navigator.of(context).pop();
  }

  void _warn(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
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
            goal.title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '${goal.mechanism.label} · ${goal.mechanism.inputHint}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ..._body(theme),
          const SizedBox(height: 12),
          AppTextField(
            controller: _note,
            label: '备注',
            hint: goal.mechanism == Mechanism.subjective ? '今天发生了什么？' : '可选',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _submit(context),
            child: Text(goal.mechanism == Mechanism.completion
                ? (goal.isCompleted ? '撤销完成' : '标记完成')
                : '保存记录'),
          ),
        ],
        ),
      ),
    );
  }

  List<Widget> _body(ThemeData theme) {
    switch (goal.mechanism) {
      case Mechanism.completion:
        return <Widget>[
          Text(
            goal.isCompleted ? '当前：已完成' : '当前：未完成',
            style: theme.textTheme.bodyMedium,
          ),
        ];

      case Mechanism.cumulative:
        final double current = goal.currentValue ?? goal.startValue ?? 0;
        return <Widget>[
          Text(
            '当前 ${fmtQuantity(current, goal.unit)} → 目标 ${fmtQuantity(goal.targetValue ?? 0, goal.unit)}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(value: true, label: Text('记增量')),
              ButtonSegment<bool>(value: false, label: Text('直接设当前值')),
            ],
            selected: <bool>{_useDelta},
            onSelectionChanged: (Set<bool> next) =>
                setState(() => _useDelta = next.first),
          ),
          const SizedBox(height: 10),
          NumberField(
            controller: _number,
            label: _useDelta ? '本次增量' : '当前累计值',
            suffix: goal.unit.isEmpty ? null : goal.unit,
            hint: _useDelta ? '可为负，例如 -2' : '例如 15',
          ),
          const SizedBox(height: 8),
          if (_useDelta)
            Wrap(
              spacing: 8,
              children: <Widget>[
                _quick('+1', 1),
                _quick('+5', 5),
                _quick('−1', -1),
              ],
            ),
        ];

      case Mechanism.metric:
        return <Widget>[
          Text(
            '起始 ${fmtQuantity(goal.startValue ?? 0, goal.unit)} → 当前 ${fmtQuantity(goal.currentValue ?? 0, goal.unit)} → 目标 ${fmtQuantity(goal.targetValue ?? 0, goal.unit)}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '读数会覆盖当前值，但历史读数全部保留。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          NumberField(
            controller: _number,
            label: '本次读数',
            suffix: goal.unit.isEmpty ? null : goal.unit,
            hint: '例如 74.8',
          ),
        ];

      case Mechanism.subjective:
        return <Widget>[
          Row(
            children: <Widget>[
              Text('自评进度', style: theme.textTheme.bodyMedium),
              const Spacer(),
              Text(
                '${fmtNum(_rating)}%',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Slider(
            value: _rating,
            min: 0,
            max: 100,
            divisions: 100,
            label: '${_rating.round()}%',
            onChanged: (double v) => setState(() => _rating = v),
          ),
          Text(
            '系统不会替你调整这个值，只有你能判断。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ];

      case Mechanism.milestone:
        return <Widget>[
          Text(
            '父级进度由子目标加权上卷，不能直接记录进度。',
            style: theme.textTheme.bodyMedium,
          ),
        ];
    }
  }

  Widget _quick(String label, double value) => ActionChip(
        label: Text(label),
        onPressed: () => setState(() => _number.text = value.toString()),
      );
}
