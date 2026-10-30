import 'package:flutter/material.dart';

import '../../core/date_utils.dart';

/// 一个分节卡片：标题 + 可选说明 + 内容。
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.children = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (children.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              ...children,
            ],
          ],
        ),
      ),
    );
  }
}

/// 一行「标签：值」。
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// 进度条：实际进度 + 计划进度标记（竖线）。
class PercentBar extends StatelessWidget {
  const PercentBar({
    super.key,
    required this.percent,
    this.planned,
    this.height = 8,
  });

  final double percent;
  final double? planned;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool over = percent > 100;
    final bool negative = percent < 0;
    final double fill = (percent / 100).clamp(0.0, 1.0).toDouble();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double w = constraints.maxWidth;
        final double markerX = planned == null
            ? 0
            : ((w * (planned! / 100).clamp(0.0, 1.0)) - 1)
                .clamp(0.0, w - 2)
                .toDouble();
        return SizedBox(
          height: height + 6,
          width: w,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              Container(
                height: height,
                width: w,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
              Container(
                height: height,
                width: w * fill,
                decoration: BoxDecoration(
                  color: negative
                      ? scheme.error
                      : (over ? scheme.tertiary : scheme.primary),
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
              if (planned != null)
                Positioned(
                  left: markerX,
                  child: Container(
                    width: 2,
                    height: height + 6,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 空状态提示。
class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key, this.icon, this.action});

  final String text;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: <Widget>[
          if (icon != null)
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          if (icon != null) const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// 小圆角标签。
class MiniChip extends StatelessWidget {
  const MiniChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.onDeleted,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color base = color ?? theme.colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: base.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: base),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: base),
          ),
          if (onDeleted != null) ...<Widget>[
            const SizedBox(width: 2),
            GestureDetector(
              onTap: onDeleted,
              child: Icon(Icons.close, size: 13, color: base),
            ),
          ],
        ],
      ),
    );
  }
}

/// 「还剩 X 天」等日期提示。
String dueText(DateTime? due, DateTime now) {
  if (due == null) return '未设截止日';
  final int days = daysBetween(now, due);
  if (days < 0) return '已过截止日 ${-days} 天';
  if (days == 0) return '今天截止';
  return '还剩 $days 天';
}

/// 快捷的 SnackBar。
void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(text)));
}
