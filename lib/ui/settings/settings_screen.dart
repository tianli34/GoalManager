import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/export/export_service.dart';
import '../../data/models/app_data.dart';
import '../../state/app_state.dart';
import '../app_scope.dart';
import '../widgets/common.dart';

/// 设置：备份、导入导出、阈值偏好。
///
/// 本地备份 / 恢复在同步之前就必须存在（换机、丢机场景）。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _import = TextEditingController();

  @override
  void dispose() {
    _import.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppStateScope.of(context);
    final AppSettings s = state.settings;
    final AppData data = state.data;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          SectionCard(
            title: '备份与导出',
            subtitle: '两种格式：JSON 可完整恢复，Markdown 便于阅读',
            children: <Widget>[
              Wrap(
                spacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () => _exportJson(context, state),
                    icon: const Icon(Icons.save_alt),
                    label: const Text('导出 JSON'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _exportMarkdown(context, state),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('导出 Markdown'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '当前：目标 ${data.goals.length} 个 · 记录 ${data.records.length} 条 · 承诺 ${data.commitments.length} 条 · 复盘 ${data.reviews.length} 次',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '导入恢复',
            subtitle: '粘贴之前导出的 JSON，会整份替换当前数据',
            children: <Widget>[
              TextField(
                controller: _import,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '把备份的 JSON 粘到这里',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _doImport(context, state),
                icon: const Icon(Icons.upload_file),
                label: const Text('恢复'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '关注信号的阈值',
            subtitle: '信号来自真实记录，阈值只影响什么时候提醒你',
            children: <Widget>[
              _ThresholdTile(
                label: '久未更新（天）',
                value: s.noUpdateDays,
                min: 1,
                max: 90,
                onChanged: (int v) {
                  s.noUpdateDays = v;
                  state.updateSettings(s);
                },
              ),
              _ThresholdTile(
                label: '疑似停滞（天）',
                value: s.stallDays,
                min: 1,
                max: 180,
                onChanged: (int v) {
                  s.stallDays = v;
                  state.updateSettings(s);
                },
              ),
              _ThresholdTile(
                label: '日期风险提前（天）',
                value: s.dateRiskDays,
                min: 1,
                max: 60,
                onChanged: (int v) {
                  s.dateRiskDays = v;
                  state.updateSettings(s);
                },
              ),
              _ThresholdTile(
                label: '指标型最小样本（条）',
                value: s.metricMinSamples,
                min: 2,
                max: 20,
                onChanged: (int v) {
                  s.metricMinSamples = v;
                  state.updateSettings(s);
                },
              ),
              _ThresholdTile(
                label: '首页聚焦建议数量',
                value: s.focusSuggestion,
                min: 1,
                max: 12,
                onChanged: (int v) {
                  s.focusSuggestion = v;
                  state.updateSettings(s);
                },
              ),
              const SizedBox(height: 6),
              Text(
                '严重落后才算风险：实际比计划落后超过 ${(s.dateRiskTolerance * 100).round()}% 才提示。',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '数据',
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restart_alt),
                title: const Text('重新载入示例数据'),
                subtitle: const Text('会覆盖当前数据，用于快速看懂五种机制'),
                onTap: () => _confirm(
                  context,
                  title: '载入示例数据？',
                  content: '当前数据会被替换。',
                  onOk: () => state.loadSampleData(),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_forever_outlined),
                title: const Text('清空全部数据'),
                subtitle: const Text('不可撤销，建议先导出备份'),
                onTap: () => _confirm(
                  context,
                  title: '清空全部数据？',
                  content: '所有目标、记录、承诺、复盘都会被删除。',
                  onOk: () => state.clearAll(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '关于',
            children: <Widget>[
              const Text(
                '本地优先：无账号也能用，核心读写不依赖网络。\n'
                '机制（怎么推进）、生命周期（状态）、时间范围、领域标签、关注信号，五个维度互相独立。\n'
                '首版不做：预测算法、复杂停滞诊断、成就体系、同步协作。',
              ),
              if (state.error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  '提示：${state.error}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportJson(BuildContext context, AppState state) async {
    final String content = state.exportJson();
    final String? path = await state.exportJsonToFile();
    if (!context.mounted) return;
    await _showExport(context, 'JSON 备份', content, path);
  }

  Future<void> _exportMarkdown(BuildContext context, AppState state) async {
    final String content = state.exportMarkdown();
    final String? path = await state.exportMarkdownToFile();
    if (!context.mounted) return;
    await _showExport(context, 'Markdown 备份', content, path);
  }

  Future<void> _showExport(
    BuildContext context,
    String title,
    String content,
    String? path,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (path != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  '已保存到：$path',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  '当前平台不支持写文件，请复制下面的内容自行保存。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                height: 320,
                child: SingleChildScrollView(
                  child: SelectableText(
                    content.length > 20000
                        ? '${content.substring(0, 20000)}\n…（已截断，完整内容请看文件）'
                        : content,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: content));
                  if (context.mounted) {
                    showMessage(context, '已复制到剪贴板');
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('复制全文'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _doImport(BuildContext context, AppState state) {
    final String raw = _import.text;
    try {
      // 先解析一次，给出可读的错误提示。
      ExportService.parse(raw);
      state.importData(raw);
      _import.clear();
      showMessage(context, '已恢复备份');
    } catch (e) {
      showMessage(context, '导入失败：$e');
    }
  }

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String content,
    required VoidCallback onOk,
  }) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (ok == true) onOk();
  }
}

class _ThresholdTile extends StatelessWidget {
  const _ThresholdTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          SizedBox(
            width: 150,
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              label: '$value',
              onChanged: (double v) => onChanged(v.round()),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
