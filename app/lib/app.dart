import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_controller.dart';
import 'config.dart';
import 'l10n/app_localizations.dart';
import 'services/launcher.dart';
import 'ui/scope.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

class MajungApp extends StatefulWidget {
  const MajungApp({super.key, required this.controller, required this.launcher, required this.config});

  final AppController controller;
  final ActionLauncher launcher;
  final AppConfig config;

  @override
  State<MajungApp> createState() => _MajungAppState();
}

class _MajungAppState extends State<MajungApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 앱으로 돌아오면 "지금 열림" 상태를 다시 계산하고 새 데이터가 있는지 본다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.refresh();
  }

  @override
  Widget build(BuildContext context) => AppScope(
        controller: widget.controller,
        launcher: widget.launcher,
        config: widget.config,
        child: MaterialApp(
          onGenerateTitle: (context) => L10n.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          locale: const Locale('ko'),
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomeScreen(),
        ),
      );
}
