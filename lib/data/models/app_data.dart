import 'commitment.dart';
import 'enums.dart';
import 'goal.dart';
import 'inbox_item.dart';
import 'json_helpers.dart';
import 'review.dart';
import 'update_record.dart';

/// 当前数据结构版本。导入备份时用于判断兼容性。
const int kSchemaVersion = 1;

/// 全局偏好：主要是关注信号的阈值。
class AppSettings {
  AppSettings({
    this.noUpdateDays = 14,
    this.stallDays = 21,
    this.dateRiskDays = 7,
    this.dateRiskTolerance = 0.2,
    this.metricMinSamples = 3,
    this.focusSuggestion = 5,
  });

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
        noUpdateDays: readIntOr(json['noUpdateDays'], 14),
        stallDays: readIntOr(json['stallDays'], 21),
        dateRiskDays: readIntOr(json['dateRiskDays'], 7),
        dateRiskTolerance: readDoubleOr(json['dateRiskTolerance'], 0.2),
        metricMinSamples: readIntOr(json['metricMinSamples'], 3),
        focusSuggestion: readIntOr(json['focusSuggestion'], 5),
      );

  /// 距上次进度记录超过这个天数 → 久未更新。
  int noUpdateDays;

  /// 原始量超过这个天数没有变化 → 疑似停滞。
  int stallDays;

  /// 截止日进入这个天数内 → 开始检查日期风险。
  int dateRiskDays;

  /// 落后计划多少个百分点才算「明显落后」。
  double dateRiskTolerance;

  /// 指标型判断趋势 / 稳定达标所需的最小读数样本数。
  int metricMinSamples;

  /// 首页聚焦目标的软性建议数量（不做硬性校验）。
  int focusSuggestion;

  Map<String, Object?> toJson() => <String, Object?>{
        'noUpdateDays': noUpdateDays,
        'stallDays': stallDays,
        'dateRiskDays': dateRiskDays,
        'dateRiskTolerance': dateRiskTolerance,
        'metricMinSamples': metricMinSamples,
        'focusSuggestion': focusSuggestion,
      };
}

/// 整份本地数据（导出 / 恢复的最小完整单元）。
class AppData {
  AppData({
    this.schemaVersion = kSchemaVersion,
    List<Goal>? goals,
    List<UpdateRecord>? records,
    List<Commitment>? commitments,
    List<Review>? reviews,
    List<InboxItem>? inbox,
    AppSettings? settings,
  })  : goals = goals ?? <Goal>[],
        records = records ?? <UpdateRecord>[],
        commitments = commitments ?? <Commitment>[],
        reviews = reviews ?? <Review>[],
        inbox = inbox ?? <InboxItem>[],
        settings = settings ?? AppSettings();

  factory AppData.fromJson(Object? raw) {
    final Map<String, Object?> json =
        raw is Map ? raw.cast<String, Object?>() : <String, Object?>{};
    return AppData(
      schemaVersion: readIntOr(json['schemaVersion'], kSchemaVersion),
      goals: readList<Goal>(
        json['goals'],
        (Object? e) => Goal.fromJson(e is Map ? e.cast<String, Object?>() : <String, Object?>{}),
      ),
      records: readList<UpdateRecord>(
        json['records'],
        (Object? e) => UpdateRecord.fromJson(e is Map ? e.cast<String, Object?>() : <String, Object?>{}),
      ),
      commitments: readList<Commitment>(
        json['commitments'],
        (Object? e) => Commitment.fromJson(e is Map ? e.cast<String, Object?>() : <String, Object?>{}),
      ),
      reviews: readList<Review>(
        json['reviews'],
        (Object? e) => Review.fromJson(e is Map ? e.cast<String, Object?>() : <String, Object?>{}),
      ),
      inbox: readList<InboxItem>(
        json['inbox'],
        (Object? e) => InboxItem.fromJson(e is Map ? e.cast<String, Object?>() : <String, Object?>{}),
      ),
      settings: AppSettings.fromJson(
        json['settings'] is Map ? (json['settings']! as Map).cast<String, Object?>() : <String, Object?>{},
      ),
    );
  }

  final int schemaVersion;
  final List<Goal> goals;
  final List<UpdateRecord> records;
  final List<Commitment> commitments;
  final List<Review> reviews;
  final List<InboxItem> inbox;
  AppSettings settings;

  Goal? goalById(String id) {
    for (final Goal g in goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  List<Goal> childrenOf(String parentId) => goals
      .where((Goal g) => g.parentGoalId == parentId)
      .toList()
    ..sort((Goal a, Goal b) {
      final int c = a.sortOrder.compareTo(b.sortOrder);
      return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
    });

  List<UpdateRecord> recordsOf(String goalId) => records
      .where((UpdateRecord r) => r.goalId == goalId)
      .toList()
    ..sort((UpdateRecord a, UpdateRecord b) => a.timestamp.compareTo(b.timestamp));

  List<Commitment> commitmentsOf(String goalId) =>
      commitments.where((Commitment c) => c.goalId == goalId).toList()
        ..sort((Commitment a, Commitment b) => b.createdAt.compareTo(a.createdAt));

  /// 目标最近一次被标记完成的时间（用于串行里程碑的配速挤压）。
  DateTime? completionTimeOf(String goalId) {
    DateTime? found;
    for (final UpdateRecord r in records) {
      final bool hit = r.goalId == goalId &&
          ((r.type == RecordType.lifecycleChange &&
                  r.toLifecycle == Lifecycle.completed) ||
              (r.type == RecordType.progress && r.done == true));
      if (hit && (found == null || r.timestamp.isAfter(found))) {
        found = r.timestamp;
      }
    }
    return found;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'goals': goals.map((Goal g) => g.toJson()).toList(),
        'records': records.map((UpdateRecord r) => r.toJson()).toList(),
        'commitments': commitments.map((Commitment c) => c.toJson()).toList(),
        'reviews': reviews.map((Review r) => r.toJson()).toList(),
        'inbox': inbox.map((InboxItem i) => i.toJson()).toList(),
        'settings': settings.toJson(),
      };
}
