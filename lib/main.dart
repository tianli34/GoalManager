import 'package:flutter/material.dart';

import 'data/storage/app_repository.dart';
import 'data/storage/key_value_store.dart';
import 'state/app_state.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 本地优先：整份数据就是 shared_preferences 里的一个 JSON 快照，
  // 无账号、无网络也能完整使用。
  final AppState state = AppState(
    repository: AppRepository(SharedPrefsStore()),
  );
  await state.init();

  runApp(GoalManagerApp(state: state));
}
