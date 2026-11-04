import 'package:flutter/material.dart';

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
    final style = (large ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.titleMedium)
        ?.copyWith(color: color, fontWeight: FontWeight.w800);
    final detailStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(StatusColors.iconFor(t.tone), color: color, size: large ? 28 : 24),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: t.headline, style: style),
                  if (t.detail.isNotEmpty) TextSpan(text: '  ${t.detail}', style: detailStyle),
                ]),
              ),
            ),
          ],
        ),
        if (status.holidayUncertain)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 32),
            child: Text(l.holidayWarning,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.statusColors.closingSoon)),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              StatusLine(status: item.status, now: now),
              const SizedBox(height: 6),
              if (item.distance != null)
                _IconText(icon: Icons.directions_walk, text: walkText(l, item.distance!)),
              _IconText(icon: Icons.person, text: l.whoCanUse(f.eligibility ?? l.detailUnknownField)),
              if (item.freshness != Freshness.fresh) ...[
                const SizedBox(height: 6),
                FreshnessWarning(freshness: item.freshness),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onCall,
                      icon: const Icon(Icons.call),
                      label: Text(onCall == null ? l.noPhone : l.call),
                    ),
                  ),
                  const SizedBox(width: 12),
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

/// 홈 화면의 큰 카테고리 버튼.
class BigCategoryButton extends StatelessWidget {
  const BigCategoryButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.footnote,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? footnote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 120),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, size: 56, color: scheme.onPrimaryContainer),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: theme.textTheme.headlineMedium?.copyWith(color: scheme.onPrimaryContainer)),
                      Text(subtitle,
                          style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onPrimaryContainer)),
                      if (footnote != null)
                        Text(footnote!,
                            style: theme.textTheme.titleMedium?.copyWith(color: scheme.onPrimaryContainer)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 36, color: scheme.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 화면 아래 고정 "급할 때 전화하기".
class EmergencyBar extends StatelessWidget {
  const EmergencyBar({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final danger = context.statusColors.danger;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          key: const Key('emergency'),
          style: FilledButton.styleFrom(
            backgroundColor: danger,
            foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
            minimumSize: const Size.fromHeight(60),
          ),
          onPressed: onPressed,
          icon: const Icon(Icons.phone_in_talk, size: 28),
          label: Text(L10n.of(context).emergencyButton),
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
