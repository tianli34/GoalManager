import '../core/date_utils.dart';
import '../core/id.dart';
import '../data/models/app_data.dart';
import '../data/models/commitment.dart';
import '../data/models/enums.dart';
import '../data/models/goal.dart';
import '../data/models/inbox_item.dart';
import '../data/models/review.dart';
import '../data/models/update_record.dart';

/// 首次启动的示例数据：覆盖五种机制，方便立刻看懂每种机制在做什么。
/// 设置页可以随时清空 / 重新载入。
AppData buildSeedData() {
  final DateTime now = DateTime.now();
  final DateWindow week = currentWeek(now);
  final DateWindow lastWeekWindow = lastWeek(now);

  final AppData data = AppData();

  void add(Goal g) => data.goals.add(g);

  // ---------------------------------------------------------------- 完成型
  final Goal checkup = Goal.create(
    title: '预约并完成年度体检',
    mechanism: Mechanism.completion,
    why: '这两年一直拖着，想确认身体指标，别再靠感觉判断健康。',
    successCriteria: '体检做完，拿到报告，并和医生过一遍异常项。',
    lifecycle: Lifecycle.active,
    dueDate: now.add(const Duration(days: 20)),
    tags: <String>['健康'],
    isFocus: true,
  );
  add(checkup);

  // ---------------------------------------------------------------- 累积型
  final Goal reading = Goal.create(
    title: '今年读完 24 本书',
    mechanism: Mechanism.cumulative,
    why: '想系统地补一补产品与心理学，而不是碎片化刷文章。',
    successCriteria: '读完 24 本，每本至少写一条自己的笔记。',
    lifecycle: Lifecycle.active,
    startDate: DateTime(now.year, 1, 1),
    dueDate: DateTime(now.year, 12, 31),
    tags: <String>['阅读', '成长'],
    startValue: 0,
    currentValue: 13,
    targetValue: 24,
    unit: '本',
    isFocus: true,
  );
  add(reading);
  // 最后一次记录刻意放在 20 天前：首屏就能看到「久未更新」这条信号长什么样。
  final List<List<Object>> readingLog = <List<Object>>[
    <Object>[-50, 3],
    <Object>[-40, 2],
    <Object>[-30, 4],
    <Object>[-25, 2],
    <Object>[-20, 2],
  ];
  for (final List<Object> row in readingLog) {
    final int days = row[0]! as int;
    final double delta = (row[1]! as num).toDouble();
    data.records.add(UpdateRecord.progress(
      goalId: reading.id,
      at: now.add(Duration(days: days)),
      delta: delta,
      note: '读完 ${delta.toStringAsFixed(0)} 本',
    ));
  }

  // ---------------------------------------------------------------- 指标型
  final Goal weight = Goal.create(
    title: '体重从 78kg 降到 72kg',
    mechanism: Mechanism.metric,
    why: '不是为了好看，是为了让膝盖在爬山时轻松一点。',
    successCriteria: '连续 3 次晨起读数 ≤ 72kg（避免单日波动误判）。',
    lifecycle: Lifecycle.active,
    startDate: now.subtract(const Duration(days: 60)),
    dueDate: now.add(const Duration(days: 60)),
    tags: <String>['健康'],
    startValue: 78,
    currentValue: 75.4,
    targetValue: 72,
    unit: 'kg',
    stableWindow: 3,
    isFocus: true,
  );
  add(weight);
  final List<List<Object>> weightLog = <List<Object>>[
    <Object>[-60, 78.0],
    <Object>[-45, 77.2],
    <Object>[-30, 76.5],
    <Object>[-15, 76.0],
    <Object>[-3, 75.4],
  ];
  for (final List<Object> row in weightLog) {
    final int days = row[0]! as int;
    final double value = (row[1]! as num).toDouble();
    data.records.add(UpdateRecord.progress(
      goalId: weight.id,
      at: now.add(Duration(days: days)),
      reading: value,
      note: '晨起读数',
    ));
  }

  // ---------------------------------------------------------------- 主观型
  final Goal english = Goal.create(
    title: '用英文做工作汇报更自信',
    mechanism: Mechanism.subjective,
    why: '技术能力够了，卡在表达上，这件事没法用数字衡量，只能靠体感。',
    successCriteria: '能在英文会上自然地讲完一整段，不依赖逐字稿。',
    lifecycle: Lifecycle.active,
    tags: <String>['成长', '工作'],
    currentValue: 45,
  );
  add(english);
  data.records.add(UpdateRecord.progress(
    goalId: english.id,
    at: now.add(const Duration(days: -40)),
    selfRating: 30,
    note: '第一次英文站会，全程念稿',
  ));
  data.records.add(UpdateRecord.progress(
    goalId: english.id,
    at: now.add(const Duration(days: -20)),
    selfRating: 38,
    note: '能脱稿讲两分钟了，但被打断就慌',
  ));
  data.records.add(UpdateRecord.progress(
    goalId: english.id,
    at: now.add(const Duration(days: -5)),
    selfRating: 45,
    note: '提前写好要点，讲完一整段没卡壳',
  ));

  // ------------------------------------------------------------ 里程碑（串行）
  final Goal site = Goal.create(
    title: '上线个人网站 v1',
    mechanism: Mechanism.milestone,
    why: '想有一个完全属于自己的地方放作品和笔记。',
    successCriteria: '域名可访问、首页与作品集页面完成、部署到生产环境。',
    lifecycle: Lifecycle.active,
    startDate: now.subtract(const Duration(days: 10)),
    dueDate: now.add(const Duration(days: 45)),
    tags: <String>['项目'],
    executionMode: ExecutionMode.sequential,
    isFocus: true,
  );
  add(site);

  final Goal domain = Goal.create(
    title: '买域名并配置 DNS',
    mechanism: Mechanism.completion,
    lifecycle: Lifecycle.completed,
    parentGoalId: site.id,
    sortOrder: 100,
    tags: <String>['项目'],
  );
  add(domain);
  data.records.add(UpdateRecord.progress(
    goalId: domain.id,
    at: now.add(const Duration(days: -9)),
    done: true,
    note: '域名已解析到托管平台',
  ));

  final Goal homePage = Goal.create(
    title: '搭好首页与作品集页面',
    mechanism: Mechanism.completion,
    lifecycle: Lifecycle.active,
    parentGoalId: site.id,
    sortOrder: 200,
    tags: <String>['项目'],
  );
  add(homePage);

  final Goal deploy = Goal.create(
    title: '部署到生产环境并验收',
    mechanism: Mechanism.completion,
    lifecycle: Lifecycle.pending,
    parentGoalId: site.id,
    sortOrder: 300,
    tags: <String>['项目'],
  );
  add(deploy);

  // ------------------------------------------------------------ 里程碑（并列）
  final Goal move = Goal.create(
    title: '准备搬家',
    mechanism: Mechanism.milestone,
    why: '租约下个月到期，想搬得离公司近一点。',
    successCriteria: '房子定下来、杂物清完、搬家当天有人帮忙。',
    lifecycle: Lifecycle.active,
    dueDate: now.add(const Duration(days: 30)),
    tags: <String>['生活'],
    executionMode: ExecutionMode.parallel,
  );
  add(move);
  final Goal house = Goal.create(
    title: '定下新房子并签合同',
    mechanism: Mechanism.completion,
    lifecycle: Lifecycle.active,
    parentGoalId: move.id,
    sortOrder: 100,
    tags: <String>['生活'],
  );
  add(house);
  final Goal declutter = Goal.create(
    title: '清掉不用的杂物',
    mechanism: Mechanism.cumulative,
    lifecycle: Lifecycle.active,
    parentGoalId: move.id,
    sortOrder: 200,
    startValue: 0,
    currentValue: 3,
    targetValue: 10,
    unit: '箱',
    weight: 2,
    tags: <String>['生活'],
  );
  add(declutter);
  data.records.add(UpdateRecord.progress(
    goalId: declutter.id,
    at: now.add(const Duration(days: -4)),
    delta: 3,
    note: '先清了书柜',
  ));

  // ------------------------------------------------------------------ 承诺
  data.commitments.add(Commitment(
    id: newId('cmt'),
    goalId: reading.id,
    start: week.start,
    end: week.end,
    targetDelta: 2,
    note: '这周通勤路上读完 2 本',
    baselineValue: reading.currentValue ?? 0,
    createdAt: week.start.add(const Duration(hours: 9)),
  ));
  data.commitments.add(Commitment(
    id: newId('cmt'),
    goalId: site.id,
    start: week.start,
    end: week.end,
    targetChildGoalId: homePage.id,
    note: '这周把首页做出来',
    baselineValue: 0,
    createdAt: week.start.add(const Duration(hours: 9)),
  ));

  // ------------------------------------------------------------------ 复盘
  data.reviews.add(Review(
    id: newId('rev'),
    start: lastWeekWindow.start,
    end: lastWeekWindow.end,
    goalIds: <String>[reading.id, weight.id],
    whatHappened: '读了 2 本书，体重掉了 0.6kg；英文汇报这周没机会练。',
    stillWorth: '值得，读的书直接用在了一次方案评审里。',
    stillWorthAnswer: true,
    decision: ReviewDecision.cont,
    nextStep: '下周把英文汇报的场景主动约一次',
    createdAt: lastWeekWindow.end,
  ));

  // ---------------------------------------------------------------- 收集箱
  data.inbox.add(InboxItem(
    id: newId('inbox'),
    text: '想试试每周留出两小时做「什么都不安排」的时间',
    createdAt: now.add(const Duration(days: -2)),
  ));
  data.inbox.add(InboxItem(
    id: newId('inbox'),
    text: '给爸妈换个好点的路由器',
    createdAt: now.add(const Duration(days: -1)),
  ));

  return data;
}
