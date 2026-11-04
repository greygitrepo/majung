import 'package:flutter/material.dart';

import '../domain/category.dart';
import 'format.dart';

/// 따뜻하고 편안하게, 그러면서도 잘 보이는 것이 최우선: 큰 글자, 높은 대비(4.5:1 이상), 큰 터치 영역.
/// 색: 크림 바탕 + 테라코타 주색 + 진한 갈색 글자. 디자인 시안(마중 따뜻한 디자인 시안)과 같다.
class Palette {
  static const cream = Color(0xFFFFF8F0); // 바탕
  static const sand = Color(0xFFF6E9DC); // 보조 버튼·위치 바
  static const ink = Color(0xFF3A2A1F); // 본문 글자
  static const inkSoft = Color(0xFF6B5444); // 보조 글자
  static const terracotta = Color(0xFFB5532C); // 주 버튼
  static const terracottaDeep = Color(0xFF9A4524); // 링크·강조 글자
  static const honey = Color(0xFFFFF0D6); // 안내 띠

  // 어두운 모드: 따뜻한 밤 색
  static const night = Color(0xFF1E1714);
  static const nightCard = Color(0xFF2A211C);
  static const nightSand = Color(0xFF3A2E28);
  static const nightInk = Color(0xFFF5EDE6);
  static const nightInkSoft = Color(0xFFD8C8BB);
  static const apricot = Color(0xFFFFB590);

  /// 제목 글꼴 (pubspec.yaml fonts). 본문은 휴대폰 기본 글꼴.
  static const titleFont = 'GowunDodum';
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base0 = ColorScheme.fromSeed(seedColor: Palette.terracotta, brightness: brightness);
  final scheme = dark
      ? base0.copyWith(
          primary: Palette.apricot,
          onPrimary: const Color(0xFF4A1C06),
          primaryContainer: const Color(0xFF4A2A1C),
          onPrimaryContainer: const Color(0xFFFFDCC8),
          secondaryContainer: Palette.nightSand,
          onSecondaryContainer: Palette.nightInk,
          tertiaryContainer: const Color(0xFF4A3518),
          onTertiaryContainer: const Color(0xFFFFE0B0),
          surface: Palette.night,
          onSurface: Palette.nightInk,
          onSurfaceVariant: Palette.nightInkSoft,
          surfaceContainerLow: Palette.nightCard,
        )
      : base0.copyWith(
          primary: Palette.terracotta,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFFCE3CF),
          onPrimaryContainer: Palette.ink,
          secondaryContainer: Palette.sand,
          onSecondaryContainer: Palette.ink,
          tertiaryContainer: Palette.honey,
          onTertiaryContainer: const Color(0xFF5C3A10),
          surface: Palette.cream,
          onSurface: Palette.ink,
          onSurfaceVariant: Palette.inkSoft,
          surfaceContainerLow: Colors.white,
        );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
  final text = base.textTheme.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  const pill = StadiumBorder();
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text.copyWith(
      // 큰 제목은 부드러운 고운돋움 (굵기는 하나뿐이라 w400).
      headlineLarge: text.headlineLarge
          ?.copyWith(fontFamily: Palette.titleFont, fontWeight: FontWeight.w400, fontSize: 32, height: 1.3),
      headlineMedium: text.headlineMedium
          ?.copyWith(fontFamily: Palette.titleFont, fontWeight: FontWeight.w400, fontSize: 29, height: 1.25),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 22),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 19),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 18, height: 1.45),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 17, height: 1.45),
      labelLarge: text.labelLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge
          ?.copyWith(fontFamily: Palette.titleFont, fontWeight: FontWeight.w400, fontSize: 26),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        shape: pill,
      ),
    ),
    // 테두리 선 대신 옅은 모래색으로 채운 보조 버튼.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 56),
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        side: BorderSide.none,
        shape: pill,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: dark ? Palette.apricot : Palette.terracottaDeep,
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        shape: pill,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dividerTheme: DividerThemeData(color: scheme.onSurface.withValues(alpha: 0.12)),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    extensions: [StatusColors.of(brightness), GroupColors.of(brightness)],
  );
}

/// 카테고리마다 다른 부드러운 색. 밥 = 살구, 잠자리 = 저녁 하늘 보라.
/// fg 는 bg 위 글자·아이콘 색 (4.5:1 이상).
class GroupColors extends ThemeExtension<GroupColors> {
  const GroupColors(this._colors);
  final Map<CategoryGroup, ({Color bg, Color fg})> _colors;

  factory GroupColors.of(Brightness b) => b == Brightness.dark
      ? const GroupColors({
          CategoryGroup.meal: (bg: Color(0xFF4A2A1C), fg: Color(0xFFFFD9C2)),
          CategoryGroup.sleep: (bg: Color(0xFF2E2D4A), fg: Color(0xFFDCDBFF)),
          CategoryGroup.clinic: (bg: Color(0xFF1F3A2A), fg: Color(0xFFCFEBD9)),
        })
      : const GroupColors({
          CategoryGroup.meal: (bg: Color(0xFFFCE3CF), fg: Color(0xFF9A4524)),
          CategoryGroup.sleep: (bg: Color(0xFFE6E4F4), fg: Color(0xFF4A4E8C)),
          CategoryGroup.clinic: (bg: Color(0xFFE0F0E6), fg: Color(0xFF2F6B45)),
        });

  /// 아직 색을 정하지 않은 카테고리는 모래색.
  ({Color bg, Color fg}) of(CategoryGroup g, ColorScheme scheme) =>
      _colors[g] ?? (bg: scheme.secondaryContainer, fg: scheme.onSecondaryContainer);

  @override
  GroupColors copyWith() => this;

  @override
  GroupColors lerp(GroupColors? other, double t) => t < 0.5 ? this : (other ?? this);
}

/// 상태 색. 색만으로 구분하지 않도록 항상 아이콘·글자와 함께 쓴다.
/// 모든 조합은 배경 대비 4.5:1 이상 (WCAG AA).
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.open,
    required this.closingSoon,
    required this.closed,
    required this.unknown,
    required this.danger,
  });

  factory StatusColors.of(Brightness b) => b == Brightness.dark
      ? const StatusColors(
          open: Color(0xFF81C995),
          closingSoon: Color(0xFFFFB74D),
          closed: Color(0xFFBDBDBD),
          unknown: Color(0xFF90CAF9),
          danger: Color(0xFFFF8A80),
        )
      : const StatusColors(
          open: Color(0xFF2F6B2F),
          closingSoon: Color(0xFF8A4B00),
          closed: Color(0xFF5E524A),
          unknown: Color(0xFF3B4A9A),
          danger: Color(0xFFB3261E),
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
  GroupColors get groupColors => Theme.of(this).extension<GroupColors>()!;
}
