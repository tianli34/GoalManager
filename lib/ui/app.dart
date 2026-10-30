import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'app_scope.dart';
import 'goals/goal_detail_screen.dart';
import 'goals/goal_editor_screen.dart';
import 'home_shell.dart';
import 'inbox/inbox_screen.dart';
import 'theme.dart';

/// 应用根组件。
class GoalManagerApp extends StatelessWidget {
  const GoalManagerApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: state,
      child: MaterialApp(
        title: '目标管理',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        onGenerateRoute: _onGenerateRoute,
        home: ListenableBuilder(
          listenable: state,
          builder: (BuildContext context, Widget? child) {
            if (!state.isLoaded) return const _SplashScreen();
            return const HomeShell();
          },
        ),
      ),
    );
  }
}

/// 集中管理命名路由，省得到处手搓 MaterialPageRoute。
Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/goal-detail':
      final String goalId = settings.arguments as String? ?? '';
      if (goalId.isEmpty) return null;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (BuildContext context) => GoalDetailScreen(goalId: goalId),
      );
    case '/goal-editor':
      final Map<String, Object?> args =
          (settings.arguments as Map<String, Object?>?) ?? <String, Object?>{};
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (BuildContext context) => GoalEditorScreen(
          goalId: args['goalId'] as String?,
          parentGoalId: args['parentGoalId'] as String?,
        ),
      );
    case '/inbox':
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (BuildContext context) => const InboxScreen(),
      );
  }
  return null;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppStateScope.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              state.error ?? '正在读取本地数据…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
