import '../../core/id.dart';
import 'enums.dart';
import 'json_helpers.dart';

/// 收集箱条目：不要求机制、不要求日期，也不参与任何统计。
class InboxItem {
  InboxItem({
    required this.id,
    required this.text,
    required this.createdAt,
    this.status = InboxStatus.pending,
    this.resolvedGoalId,
    this.resolvedAt,
  });

  factory InboxItem.capture(String text) => InboxItem(
        id: newId('inbox'),
        text: text,
        createdAt: DateTime.now(),
      );

  factory InboxItem.fromJson(Map<String, Object?> json) => InboxItem(
        id: readStringOr(json['id'], newId('inbox')),
        text: readStringOr(json['text'], ''),
        createdAt: readDate(json['createdAt']) ?? DateTime.now(),
        status: enumFromName(InboxStatus.values, readStringOrNull(json['status']), InboxStatus.pending),
        resolvedGoalId: readStringOrNull(json['resolvedGoalId']),
        resolvedAt: readDate(json['resolvedAt']),
      );

  final String id;
  final String text;
  final DateTime createdAt;
  InboxStatus status;
  String? resolvedGoalId;
  DateTime? resolvedAt;

  bool get isPending => status == InboxStatus.pending;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'resolvedGoalId': resolvedGoalId,
        'resolvedAt': resolvedAt?.toIso8601String(),
      };
}
