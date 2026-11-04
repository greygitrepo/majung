import 'package:flutter/material.dart';

import 'format.dart';

/// 잘 보이는 것이 최우선: 큰 글자, 높은 대비, 큰 터치 영역.
ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF00695C),
    brightness: brightness,
  ).copyWith(
    surface: dark ? const Color(0xFF121212) : Colors.white,
    onSurface: dark ? Colors.white : const Color(0xFF111111),
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
  final text = base.textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 28),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 22),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 19),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 18, height: 1.4),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 17, height: 1.4),
      labelLarge: text.labelLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 22),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        side: BorderSide(color: scheme.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant, width: 1.5),
      ),
    ),
    extensions: [StatusColors.of(brightness)],
  );
}

/// 상태 색. 색만으로 구분하지 않도록 항상 아이콘·글자와 함께 쓴다.
/// 모든 조합은 배경 대비 4.5:1 이상 (WCAG AA).
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({required this.open, required this.closingSoon, required this.closed, required this.unknown, required this.danger});

  factory StatusColors.of(Brightness b) => b == Brightness.dark
      ? const StatusColors(
          open: Color(0xFF81C995),
          closingSoon: Color(0xFFFFB74D),
          closed: Color(0xFFBDBDBD),
          unknown: Color(0xFF90CAF9),
          danger: Color(0xFFFF8A80),
        )
      : const StatusColors(
          open: Color(0xFF1B5E20),
          closingSoon: Color(0xFFB34700),
          closed: Color(0xFF555555),
          unknown: Color(0xFF0D47A1),
          danger: Color(0xFFB71C1C),
        );

  final Color open;
  final Color closingSoon;
  final Color closed;
  final Color unknown;
  final Color danger;

  Color forTone(StatusTone t) => switch (t) {
        StatusTone.open => open,
        StatusTone.closingSoon => closingSoon,
        StatusTone.closed => closed,
        StatusTone.unknown => unknown,
      };

  static IconData iconFor(StatusTone t) => switch (t) {
        StatusTone.open => Icons.check_circle,
        StatusTone.closingSoon => Icons.schedule,
        StatusTone.closed => Icons.do_not_disturb_on,
        StatusTone.unknown => Icons.help,
      };

  @override
  StatusColors copyWith() => this;

  @override
  StatusColors lerp(StatusColors? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension StatusColorsX on BuildContext {
  StatusColors get statusColors => Theme.of(this).extension<StatusColors>()!;
}
