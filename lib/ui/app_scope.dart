import 'package:flutter/widgets.dart';

import '../state/app_state.dart';

/// 把 AppState 挂在 widget 树上的 InheritedNotifier。
///
/// 任何子 widget 用 `AppStateScope.of(context)` 拿状态，
/// 并自动在状态变化时重建。
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required Widget child,
  }) : super(notifier: state, child: child);

  /// 建立依赖：widget 会随状态变化重建。
  static AppState of(BuildContext context) {
    final AppState? state = context
        .dependOnInheritedWidgetOfExactType<AppStateScope>()
        ?.notifier;
    assert(state != null, 'AppStateScope 没有出现在 widget 树上');
    return state!;
  }

  /// 只读取、不建立依赖：给 initState 之类的场景用。
  static AppState readOf(BuildContext context) {
    final AppState? state =
        context.getInheritedWidgetOfExactType<AppStateScope>()?.notifier;
    assert(state != null, 'AppStateScope 没有出现在 widget 树上');
    return state!;
  }
}
