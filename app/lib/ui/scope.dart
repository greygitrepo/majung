import 'package:flutter/widgets.dart';

import '../app_controller.dart';
import '../config.dart';
import '../services/launcher.dart';

/// 화면들이 공통으로 쓰는 것들을 아래로 내려준다.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required this.launcher,
    required this.config,
    required super.child,
  }) : super(notifier: controller);

  final ActionLauncher launcher;
  final AppConfig config;

  AppController get controller => notifier!;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope 가 없음');
    return scope!;
  }

  /// 다시 그리기 구독 없이 읽기 (initState 등).
  static AppScope read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope 가 없음');
    return scope!;
  }
}
