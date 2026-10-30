import '../../core/id.dart';
import 'enums.dart';
import 'json_helpers.dart';

/// 一次周期复盘。产物是 decision（继续 / 调整 / 暂停 / 结束）。
class Review {
  Review({
    required this.id,
    required this.start,
    required this.end,
    List<String>? goalIds,
    this.whatHappened = '',
    this.stillWorth = '',
    this.stillWorthAnswer,
    this.decision = ReviewDecision.cont,
    this.nextStep,
    DateTime? createdAt,
  })  : goalIds = goalIds ?? <String>[],
        createdAt = createdAt ?? DateTime.now();

  factory Review.fromJson(Map<String, Object?> json) => Review(
        id: readStringOr(json['id'], newId('rev')),
        start: readDate(json['start']) ?? DateTime.now(),
        end: readDate(json['end']) ?? DateTime.now(),
        goalIds: readStringList(json['goalIds']),
        whatHappened: readStringOr(json['whatHappened'], ''),
        stillWorth: readStringOr(json['stillWorth'], ''),
        stillWorthAnswer: json['stillWorthAnswer'] is bool ? json['stillWorthAnswer']! as bool : null,
        decision: enumFromName(ReviewDecision.values, readStringOrNull(json['decision']), ReviewDecision.cont),
        nextStep: readStringOrNull(json['nextStep']),
        createdAt: readDate(json['createdAt']),
      );

  final String id;

  /// 复盘覆盖的时间窗口（周 / 季度只是窗口参数）。
  final DateTime start;
  final DateTime end;

  final List<String> goalIds;

  /// Q1 这周期实际发生了什么？
  final String whatHappened;

  /// Q2 原计划还值得继续吗？
  final String stillWorth;
  final bool? stillWorthAnswer;

  /// Q3 决定。
  final ReviewDecision decision;

  /// 下一步只有一条简短文本，不引入任务模型。
  final String? nextStep;

  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'goalIds': goalIds,
        'whatHappened': whatHappened,
        'stillWorth': stillWorth,
        'stillWorthAnswer': stillWorthAnswer,
        'decision': decision.name,
        'nextStep': nextStep,
        'createdAt': createdAt.toIso8601String(),
      };
}
