import '../../core/id.dart';
import 'enums.dart';
import 'json_helpers.dart';

/// 承诺的量按机制的自然语义存储，不统一成百分比：
/// - 累积型：目标增量（如 +500）
/// - 完成型：布尔
/// - 主观型：自评推进 N 点
/// - 里程碑型：指定某个子目标完成
/// - 指标型：只写「结果期望」，未达不解读为投入不足
class Commitment {
  Commitment({
    required this.id,
    required this.goalId,
    required this.start,
    required this.end,
    this.targetDelta,
    this.targetDone = false,
    this.targetRatingPoints,
    this.targetChildGoalId,
    this.expectation = '',
    this.note = '',
    this.status = CommitmentStatus.active,
    List<CommitmentChange>? history,
    this.baselineValue = 0,
    required this.createdAt,
  }) : history = history ?? <CommitmentChange>[];

  factory Commitment.fromJson(Map<String, Object?> json) => Commitment(
        id: readStringOr(json['id'], newId('cmt')),
        goalId: readStringOr(json['goalId'], ''),
        start: readDate(json['start']) ?? DateTime.now(),
        end: readDate(json['end']) ?? DateTime.now(),
        targetDelta: readDouble(json['targetDelta']),
        targetDone: readBoolOr(json['targetDone'], false),
        targetRatingPoints: readDouble(json['targetRatingPoints']),
        targetChildGoalId: readStringOrNull(json['targetChildGoalId']),
        expectation: readStringOr(json['expectation'], ''),
        note: readStringOr(json['note'], ''),
        status: enumFromName(
          CommitmentStatus.values,
          readStringOrNull(json['status']),
          CommitmentStatus.active,
        ),
        history: readList<CommitmentChange>(
          json['history'],
          (Object? raw) => CommitmentChange.fromJson(raw is Map ? raw.cast<String, Object?>() : <String, Object?>{}),
        ),
        baselineValue: readDoubleOr(json['baselineValue'], 0),
        createdAt: readDate(json['createdAt']) ?? DateTime.now(),
      );

  final String id;
  final String goalId;
  final DateTime start;
  final DateTime end;

  final double? targetDelta;
  final bool targetDone;
  final double? targetRatingPoints;
  final String? targetChildGoalId;
  final String expectation;

  final String note;
  CommitmentStatus status;

  /// 历史变更记录：调整 / 取消都追加，不覆盖删除。
  final List<CommitmentChange> history;

  /// 创建时目标原始量的快照。
  ///
  /// 有了它，后续修改目标值 / 权重 / 范围都不会让旧承诺「自动变成已兑现」。
  final double baselineValue;

  final DateTime createdAt;

  void addChange(CommitmentStatus from, CommitmentStatus to, String? reason) {
    history.add(CommitmentChange(at: DateTime.now(), from: from, to: to, reason: reason));
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'goalId': goalId,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'targetDelta': targetDelta,
        'targetDone': targetDone,
        'targetRatingPoints': targetRatingPoints,
        'targetChildGoalId': targetChildGoalId,
        'expectation': expectation,
        'note': note,
        'status': status.name,
        'history': history.map((CommitmentChange c) => c.toJson()).toList(),
        'baselineValue': baselineValue,
        'createdAt': createdAt.toIso8601String(),
      };
}

class CommitmentChange {
  CommitmentChange({
    required this.at,
    required this.from,
    required this.to,
    this.reason,
  });

  factory CommitmentChange.fromJson(Map<String, Object?> json) => CommitmentChange(
        at: readDate(json['at']) ?? DateTime.now(),
        from: enumFromName(CommitmentStatus.values, readStringOrNull(json['from']), CommitmentStatus.active),
        to: enumFromName(CommitmentStatus.values, readStringOrNull(json['to']), CommitmentStatus.active),
        reason: readStringOrNull(json['reason']),
      );

  final DateTime at;
  final CommitmentStatus from;
  final CommitmentStatus to;
  final String? reason;

  Map<String, Object?> toJson() => <String, Object?>{
        'at': at.toIso8601String(),
        'from': from.name,
        'to': to.name,
        'reason': reason,
      };
}
