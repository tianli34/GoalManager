import 'package:flutter/material.dart';

import '../../data/models/enums.dart';
import '../../data/models/goal.dart';
import '../../state/app_state.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';

/// 新建 / 编辑目标。编辑时会把字段变化记成一条「配置变更」。
class GoalEditorScreen extends StatefulWidget {
  const GoalEditorScreen({super.key, this.goalId, this.parentGoalId});

  final String? goalId;
  final String? parentGoalId;

  bool get isEditing => goalId != null;

  @override
  State<GoalEditorScreen> createState() => _GoalEditorScreenState();
}

class _GoalEditorScreenState extends State<GoalEditorScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _why = TextEditingController();
  final TextEditingController _criteria = TextEditingController();
  final TextEditingController _unit = TextEditingController();
  final TextEditingController _start = TextEditingController();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _target = TextEditingController();
  final TextEditingController _stable = TextEditingController(text: '3');
  final TextEditingController _reason = TextEditingController();

  Mechanism _mechanism = Mechanism.completion;
  Lifecycle _lifecycle = Lifecycle.active;
  ExecutionMode _executionMode = ExecutionMode.parallel;
  DateTime? _startDate;
  DateTime? _dueDate;
  List<String> _tags = <String>[];
  bool _isFocus = false;
  Goal? _original;

  @override
  void initState() {
    super.initState();
    final AppState state = AppStateScope.readOf(context);
    final Goal? existing =
        widget.goalId == null ? null : state.goalById(widget.goalId!);
    _original = existing;
    if (existing != null) {
      _title.text = existing.title;
      _why.text = existing.why;
      _criteria.text = existing.successCriteria;
      _unit.text = existing.unit;
      if (existing.startValue != null) {
        _start.text = _fmt(existing.startValue!);
      }
      if (existing.currentValue != null) {
        _current.text = _fmt(existing.currentValue!);
      }
      if (existing.targetValue != null) {
        _target.text = _fmt(existing.targetValue!);
      }
      _stable.text = '${existing.stableWindow}';
      _mechanism = existing.mechanism;
      _lifecycle = existing.lifecycle;
      _executionMode = existing.executionMode;
      _startDate = existing.startDate;
      _dueDate = existing.dueDate;
      _tags = List<String>.from(existing.tags);
      _isFocus = existing.isFocus;
    } else if (widget.parentGoalId != null) {
      // 子项默认「完成型」，够用且最容易上卷。
      _mechanism = Mechanism.completion;
    }
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  @override
  void dispose() {
    _title.dispose();
    _why.dispose();
    _criteria.dispose();
    _unit.dispose();
    _start.dispose();
    _current.dispose();
    _target.dispose();
    _stable.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _save() {
    final AppState state = AppStateScope.of(context);
    final String title = _title.text.trim();
    if (title.isEmpty) {
      showMessage(context, '先给目标起个名字');
      return;
    }
    final double? startValue = parseNumber(_start);
    final double? currentValue = parseNumber(_current);
    final double? targetValue = parseNumber(_target);
    final int stableWindow = int.tryParse(_stable.text.trim()) ?? 3;

    if (widget.isEditing && _original != null) {
      final Goal updated = _original!.clone()
        ..title = title
        ..why = _why.text.trim()
        ..successCriteria = _criteria.text.trim()
        ..mechanism = _mechanism
        ..lifecycle = _lifecycle
        ..startDate = _startDate
        ..dueDate = _dueDate
        ..tags = _tags
        ..unit = _unit.text.trim()
        ..startValue = startValue
        ..currentValue = currentValue
        ..targetValue = targetValue
        ..executionMode = _executionMode
        ..stableWindow = stableWindow
        ..isFocus = _isFocus;
      state.updateGoal(updated, reason: _reason.text.trim());
    } else {
      state.createGoal(
        title: title,
        mechanism: _mechanism,
        why: _why.text.trim(),
        successCriteria: _criteria.text.trim(),
        lifecycle: _lifecycle,
        startDate: _startDate,
        dueDate: _dueDate,
        tags: _tags,
        parentGoalId: widget.parentGoalId,
        startValue: startValue,
        currentValue: currentValue,
        targetValue: targetValue,
        unit: _unit.text.trim(),
        executionMode: _executionMode,
        stableWindow: stableWindow,
        isFocus: _isFocus,
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppStateScope.of(context);
    final ThemeData theme = Theme.of(context);
    final bool editing = widget.isEditing;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? '编辑目标' : '新建目标'),
        actions: <Widget>[
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          SectionCard(
            title: '定义',
            children: <Widget>[
              AppTextField(
                controller: _title,
                label: '目标',
                hint: '一句话说清要做什么',
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _why,
                label: '为什么（可留空）',
                hint: '这件事对你意味着什么',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _criteria,
                label: '达成条件',
                hint: '怎样才算真的达成了？',
                maxLines: 2,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '机制',
            subtitle: '机制决定输入什么、进度怎么算、什么算完成',
            children: <Widget>[
              MechanismPicker(
                value: _mechanism,
                onChanged: (Mechanism m) => setState(() => _mechanism = m),
              ),
              const SizedBox(height: 12),
              ..._mechanismFields(theme),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '状态与时间',
            children: <Widget>[
              LifecyclePicker(
                value: _lifecycle,
                onChanged: (Lifecycle l) => setState(() => _lifecycle = l),
              ),
              const SizedBox(height: 8),
              DatePickerTile(
                label: '起始日',
                value: _startDate,
                onChanged: (DateTime? v) => setState(() => _startDate = v),
              ),
              DatePickerTile(
                label: '截止日',
                value: _dueDate,
                onChanged: (DateTime? v) => setState(() => _dueDate = v),
              ),
              const SizedBox(height: 4),
              Text(
                '日期可选。没有日期的目标不做「落后」判断。',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '领域 / 标签',
            subtitle: '只用于筛选，不构成目标层级',
            children: <Widget>[
              TagsField(
                tags: _tags,
                onChanged: (List<String> next) =>
                    setState(() => _tags = next),
                suggestions: state.allTags,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '其他',
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('放到首页「重点目标」'),
                subtitle: const Text('建议 3~5 个，不做硬性限制'),
                value: _isFocus,
                onChanged: (bool v) => setState(() => _isFocus = v),
              ),
              if (editing) ...<Widget>[
                const SizedBox(height: 8),
                AppTextField(
                  controller: _reason,
                  label: '这次修改的原因（记进时间线）',
                  maxLines: 2,
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }

  List<Widget> _mechanismFields(ThemeData theme) {
    switch (_mechanism) {
      case Mechanism.completion:
        return <Widget>[
          Text(
            '完成型没有中间进度：只有 0% 和 100%，配速只显示剩余时间。',
            style: theme.textTheme.bodySmall,
          ),
        ];

      case Mechanism.cumulative:
        return <Widget>[
          AppTextField(controller: _unit, label: '单位', hint: '本 / 页 / 元'),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: NumberField(controller: _start, label: '起始值'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NumberField(controller: _current, label: '当前累计'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NumberField(controller: _target, label: '目标值'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '之后每次记录「增量」（可为负）。进度 =（当前 − 起始）÷（目标 − 起始）。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ];

      case Mechanism.metric:
        return <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: NumberField(controller: _unit, label: '单位')),
              const SizedBox(width: 10),
              Expanded(
                child: NumberField(controller: _stable, label: '连续达标次数'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: NumberField(controller: _start, label: '起始值 From'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NumberField(controller: _current, label: '当前读数'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NumberField(controller: _target, label: '目标值 To'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '读数会波动回退：要连续 N 次达标才算完成，避免一次读数误判。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ];

      case Mechanism.subjective:
        return <Widget>[
          NumberField(
            controller: _current,
            label: '当前自评（0~100）',
            suffix: '%',
          ),
          const SizedBox(height: 8),
          Text(
            '系统永远不会替你改这个值，只有你能判断。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ];

      case Mechanism.milestone:
        return <Widget>[
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
                  selected: <ExecutionMode>{_executionMode},
                  onSelectionChanged: (Set<ExecutionMode> next) =>
                      setState(() => _executionMode = next.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _executionMode.hint,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            '保存后就可以在详情页添加子项了。父级进度由子项加权上卷，不能直接填写。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ];
    }
  }
}
