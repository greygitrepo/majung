import 'package:flutter/material.dart';

import '../domain/category.dart';
import '../domain/freshness.dart';
import '../domain/opening_hours.dart';
import '../domain/ranking.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';
import 'theme.dart';

/// 상태 한 줄: [아이콘] 지금 열려 있어요 · 오후 1시까지
class StatusLine extends StatelessWidget {
  const StatusLine({super.key, required this.status, required this.now, this.large = false});

  final OpenStatus status;
  final DateTime now;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = statusText(l, status, now);
    final color = context.statusColors.forTone(t.tone);
    final style = (large ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.titleMedium)?.copyWith(
      color: color,
      fontWeight: FontWeight.w700,
    );
    final detailStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 옅은 같은 색 알약 안에 아이콘 + 글자 (색만으로 구분하지 않는다).
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: large ? 8 : 6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(StatusColors.iconFor(t.tone), color: color, size: large ? 26 : 22),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: t.headline, style: style),
                      if (t.detail.isNotEmpty) TextSpan(text: ' · ${t.detail}', style: detailStyle),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (status.holidayUncertain)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              l.holidayWarning,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.statusColors.closingSoon),
            ),
          ),
      ],
    );
  }
}

/// 오래된 정보 경고 띠.
class FreshnessWarning extends StatelessWidget {
  const FreshnessWarning({super.key, required this.freshness});
  final Freshness freshness;

  @override
  Widget build(BuildContext context) {
    if (freshness == Freshness.fresh) return const SizedBox.shrink();
    final l = L10n.of(context);
    final color = context.statusColors.closingSoon;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            freshness == Freshness.stale ? l.staleWarning : l.expiredWarning,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// 목록의 시설 카드 하나. 카드 전체를 누르면 자세히, 전화 버튼은 바로 전화.
class FacilityCard extends StatelessWidget {
  const FacilityCard({super.key, required this.item, required this.now, required this.onOpen, required this.onCall});

  final RankedFacility item;
  final DateTime now;
  final VoidCallback onOpen;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final f = item.facility;
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusLine(status: item.status, now: now),
              const SizedBox(height: 10),
              Text(f.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              if (item.distance != null) _IconText(icon: Icons.directions_walk, text: walkText(l, item.distance!)),
              _IconText(icon: Icons.person, text: l.whoCanUse(f.eligibility ?? l.detailUnknownField)),
              if (item.freshness != Freshness.fresh) ...[
                const SizedBox(height: 6),
                FreshnessWarning(freshness: item.freshness),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onCall,
                      icon: const Icon(Icons.call),
                      label: Text(onCall == null ? l.noPhone : l.call),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(onPressed: onOpen, child: Text(l.details)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
      ],
    ),
  );
}

/// 홈 화면의 큰 카테고리 버튼. 카테고리마다 부드러운 색(GroupColors).
class BigCategoryButton extends StatelessWidget {
  const BigCategoryButton({
    super.key,
    required this.group,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.footnote,
    required this.onTap,
  });

  final CategoryGroup group;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? footnote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.groupColors.of(group, theme.colorScheme);
    final ink = theme.colorScheme.onSurface;
    return Material(
      color: c.bg,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 120),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle),
                  child: Icon(icon, size: 40, color: c.fg),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: theme.textTheme.headlineMedium?.copyWith(color: ink)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      if (footnote != null) ...[
                        const SizedBox(height: 4),
                        Text(footnote!, style: theme.textTheme.titleMedium?.copyWith(color: c.fg)),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 36, color: c.fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 앱 이름 옆 작은 등불 (런처 아이콘과 같은 모양).
class LanternMark extends StatelessWidget {
  const LanternMark({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: const _LanternPainter()),
  );
}

class _LanternPainter extends CustomPainter {
  const _LanternPainter();

  static const _bg = Color(0xFF3E2C4F);
  static const _amber = Color(0xFFF6B24A);
  static const _glow = Color(0xFFFFE2A6);
  static const _cream = Color(0xFFF3D9B1);

  @override
  void paint(Canvas canvas, Size size) {
    // 108 단위 좌표계 (res/drawable/ic_launcher_foreground.xml 과 같음)
    final k = size.width / 108;
    canvas.scale(k);
    canvas.drawCircle(const Offset(54, 54), 54, Paint()..color = _bg);
    canvas.translate(54, 56);
    canvas.scale(0.8);
    canvas.translate(-54, -56);
    canvas.drawCircle(const Offset(54, 58), 30, Paint()..color = _amber.withValues(alpha: 0.18));
    final cream = Paint()..color = _cream;
    final handle = Path()
      ..moveTo(46, 31)
      ..quadraticBezierTo(54, 19, 62, 31);
    canvas.drawPath(
      handle,
      Paint()
        ..color = _cream
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(RRect.fromLTRBR(44, 30, 64, 37, const Radius.circular(3.5)), cream);
    canvas.drawRRect(RRect.fromLTRBR(36, 36, 72, 78, const Radius.circular(18)), Paint()..color = _amber);
    canvas.drawOval(const Rect.fromLTRB(44, 41, 64, 69), Paint()..color = _glow);
    canvas.drawRRect(RRect.fromLTRBR(45, 76, 63, 82, const Radius.circular(3)), cream);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 화면 아래 고정 "급할 때 전화하기". [showHint] 면 위에 다정한 한 줄을 붙인다.
class EmergencyBar extends StatelessWidget {
  const EmergencyBar({super.key, required this.onPressed, this.showHint = false});
  final VoidCallback onPressed;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final danger = context.statusColors.danger;
    final l = L10n.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHint)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l.emergencyHint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            FilledButton.icon(
              key: const Key('emergency'),
              style: FilledButton.styleFrom(
                backgroundColor: danger,
                foregroundColor: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                minimumSize: const Size.fromHeight(64),
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              onPressed: onPressed,
              icon: const Icon(Icons.phone_in_talk_rounded, size: 28),
              label: Text(l.emergencyButton),
            ),
          ],
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontSize: 18))));
}
