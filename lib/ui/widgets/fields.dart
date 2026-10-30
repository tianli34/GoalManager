import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../../data/models/enums.dart';

/// 通用文本输入。
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.suffixText,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? suffixText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffixText,
      ),
    );
  }
}

/// 数值输入（带单位后缀）。
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    this.label,
    this.suffix,
    this.hint,
  });

  final TextEditingController controller;
  final String? label;
  final String? suffix;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
      ),
    );
  }
}

double? parseNumber(TextEditingController controller) {
  final String raw = controller.text.trim();
  if (raw.isEmpty) return null;
  return double.tryParse(raw);
}

/// 日期选择。
class DatePickerTile extends StatelessWidget {
  const DatePickerTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.event_outlined, size: 20),
      title: Text(label, style: theme.textTheme.bodyMedium),
      subtitle: Text(value == null ? '未设置' : fmtDate(value!)),
      trailing: value == null
          ? const Icon(Icons.chevron_right, size: 20)
          : IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () => onChanged(null),
            ),
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (!context.mounted) return;
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// 标签 / 领域编辑。
class TagsField extends StatefulWidget {
  const TagsField({
    super.key,
    required this.tags,
    required this.onChanged,
    this.suggestions = const <String>[],
  });

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final List<String> suggestions;

  @override
  State<TagsField> createState() => _TagsFieldState();
}

class _TagsFieldState extends State<TagsField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) return;
    final List<String> next = List<String>.from(widget.tags);
    if (!next.contains(text)) next.add(text);
    widget.onChanged(next);
    _controller.clear();
  }

  void _remove(String tag) {
    final List<String> next = List<String>.from(widget.tags)..remove(tag);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> suggestions = widget.suggestions
        .where((String s) => !widget.tags.contains(s))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: '领域 / 标签',
                  hintText: '回车添加',
                ),
                onSubmitted: _add,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _add(_controller.text),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        if (widget.tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.tags
                .map(
                  (String tag) => InputChip(
                    label: Text(tag, style: theme.textTheme.labelMedium),
                    onDeleted: () => _remove(tag),
                  ),
                )
                .toList(),
          ),
        ],
        if (suggestions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: suggestions
                .take(8)
                .map(
                  (String s) => ActionChip(
                    label: Text(s, style: theme.textTheme.labelSmall),
                    onPressed: () => _add(s),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

/// 机制选择。
class MechanismPicker extends StatelessWidget {
  const MechanismPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Mechanism value;
  final ValueChanged<Mechanism> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('机制', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: Mechanism.values
              .map(
                (Mechanism m) => ChoiceChip(
                  label: Text(m.label),
                  selected: m == value,
                  onSelected: (_) => onChanged(m),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        Text(
          value.inputHint,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// 生命周期选择。
class LifecyclePicker extends StatelessWidget {
  const LifecyclePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Lifecycle value;
  final ValueChanged<Lifecycle> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<Lifecycle>(
      segments: Lifecycle.values
          .map(
            (Lifecycle l) => ButtonSegment<Lifecycle>(
              value: l,
              label: Text(l.label),
            ),
          )
          .toList(),
      selected: <Lifecycle>{value},
      onSelectionChanged: (Set<Lifecycle> next) => onChanged(next.first),
    );
  }
}
