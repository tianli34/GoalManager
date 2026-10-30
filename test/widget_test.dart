import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_manager/data/storage/app_repository.dart';
import 'package:goal_manager/data/storage/key_value_store.dart';
import 'package:goal_manager/state/app_state.dart';
import 'package:goal_manager/ui/app.dart';
import 'package:goal_manager/ui/goals/goals_screen.dart';

const String kReadingGoal = '今年读完 24 本书';

Future<AppState> _boot() async {
  final AppState state = AppState(repository: AppRepository(InMemoryStore()));
  await state.init();
  return state;
}

/// 默认测试视口只有 800×600，懒加载的 ListView 下半部分不会被构建，
/// 这里用接近桌面端的窗口尺寸，保证整屏内容都在。
void _useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// IndexedStack 会把四个页面都建出来，
/// 所以查找时要限定在某个页面 / 某个容器里，否则会命中多个。
void main() {
  testWidgets('首屏渲染「当下」：承诺 / 重点目标 / 需要关注', (WidgetTester tester) async {
    _useLargeSurface(tester);
    final AppState state = await _boot();
    await tester.pumpWidget(GoalManagerApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('本期承诺'), findsOneWidget);
    expect(find.text('重点目标'), findsOneWidget);
    expect(find.text('需要关注'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('切到「目标」页并进入详情', (WidgetTester tester) async {
    _useLargeSurface(tester);
    final AppState state = await _boot();
    await tester.pumpWidget(GoalManagerApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('目标'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('新建目标'), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.byType(GoalsScreen),
      matching: find.text(kReadingGoal),
    ));
    await tester.pumpAndSettle();

    expect(find.text('状态与进度'), findsOneWidget);
    expect(find.text('达成条件'), findsOneWidget);
    expect(find.text('时间线'), findsOneWidget);
  });

  testWidgets('记录一次累积型增量会改变进度', (WidgetTester tester) async {
    final AppState state = await _boot();
    await tester.pumpWidget(GoalManagerApp(state: state));
    await tester.pumpAndSettle();

    final String goalId =
        state.data.goals.firstWhere((g) => g.title == kReadingGoal).id;

    state.recordDelta(goalId, 1, note: '测试');
    await tester.pumpAndSettle();

    expect(state.goalById(goalId)!.currentValue, 14);
    expect(
      state.data.recordsOf(goalId).last.delta,
      1,
      reason: '原始量要留在记录里，百分比只是派生展示',
    );
  });
}
