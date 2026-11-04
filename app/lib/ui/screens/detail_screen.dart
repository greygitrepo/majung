import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/facility.dart';
import '../../domain/geo.dart';
import '../../domain/opening_hours.dart';
import '../../domain/ranking.dart';
import '../../l10n/app_localizations.dart';
import '../format.dart';
import '../scope.dart';
import '../widgets.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.facilityId});
  final String facilityId;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scope = AppScope.of(context);
    final c = scope.controller;
    final now = c.clock();
    final dataset = c.dataset!;
    final f = dataset.facilities.where((x) => x.id == facilityId).firstOrNull;
    if (f == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.listEmpty)),
      );
    }
    final ranked = RankedFacility(
      facility: f,
      status: f.statusAt(now, isHoliday: dataset.isHoliday),
      freshness: f.freshnessAt(now),
      distance: c.origin.point == null ? null : distanceMeters(c.origin.point!, f.location),
    );
    final theme = Theme.of(context);
    final source = dataset.sourceById(f.sourceId);

    Future<void> run(Future<bool> Function() action) async {
      final ok = await action();
      if (!ok && context.mounted) showSnack(context, l.launchFailed);
    }

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        key: const Key('detail'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          StatusLine(status: ranked.status, now: now, large: true),
          const SizedBox(height: 12),
          Text(f.name, style: theme.textTheme.headlineLarge),
          if (clinicTypeLabel(l, f.clinicType) case final kind?) ...[
            const SizedBox(height: 4),
            Text(kind, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
          ],
          if (ranked.distance != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.directions_walk_rounded, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    distanceText(l, ranked.distance!),
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          FreshnessWarning(freshness: ranked.freshness),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('detail-call'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
            onPressed: f.phone == null ? null : () => run(() => scope.launcher.dial(f.phone!)),
            icon: const Icon(Icons.phone_rounded, size: 28),
            label: Text(f.phone == null ? l.noPhone : '${l.callLong}  ${f.phone}'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('detail-directions'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(64)),
            onPressed: () => run(() => scope.launcher.directions(f.name, f.location)),
            icon: const Icon(Icons.directions_rounded, size: 28),
            label: Text(l.directions),
          ),
          const SizedBox(height: 12),
          _SaveButton(facility: f),
          const SizedBox(height: 24),
          _Section(
            title: l.detailHours,
            child: _HoursTable(facility: f, now: now),
          ),
          if (f.hoursNote != null && f.hoursTrusted)
            _Section(
              title: l.detailNote,
              child: Text(f.hoursNote!, style: theme.textTheme.bodyLarge),
            ),
          _Section(
            title: l.detailWho,
            child: Text(f.eligibility ?? l.detailUnknownField, style: theme.textTheme.bodyLarge),
          ),
          _Section(
            title: l.detailRequirements,
            child: Text(f.requirements ?? l.detailUnknownField, style: theme.textTheme.bodyLarge),
          ),
          _Section(
            title: l.detailAddress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(f.address, style: theme.textTheme.bodyLarge),
                if (f.geocoded)
                  Text(
                    l.detailGeocoded,
                    key: const Key('geocoded-note'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: f.address));
                    if (context.mounted) showSnack(context, l.detailCopied);
                  },
                  icon: const Icon(Icons.copy),
                  label: Text(l.detailCopyAddress),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.detailVerified(dateText(f.lastVerified)),
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (source != null)
            Text(
              l.detailSource(source.provider == null ? source.name : '${source.provider} · ${source.name}'),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          if (scope.config.reportEmail != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('detail-report'),
              onPressed: () => run(
                () => scope.launcher.email(
                  scope.config.reportEmail!,
                  subject: '[마중 정보 오류] ${f.name}',
                  body: '시설: ${f.name} (${f.id})\n틀린 내용:\n\n맞는 내용:\n',
                ),
              ),
              icon: const Icon(Icons.flag_rounded),
              label: Text(l.detailReport),
            ),
          ],
        ],
      ),
    );
  }
}

/// 저장하기 / 저장한 곳에서 빼기. 글자로 상태를 알려 준다 (아이콘만 두지 않음).
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.facility});
  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final c = AppScope.of(context).controller;
    final saved = c.isSaved(facility.id);
    Future<void> toggle() async {
      final nowSaved = await c.toggleSaved(facility);
      if (context.mounted) showSnack(context, nowSaved ? l.savedAdded : l.savedRemoved);
    }

    final style = OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(64));
    // 버튼 글자가 상태를 말해 준다 ("저장하기" / "저장한 곳에서 빼기").
    return saved
          ? FilledButton.tonalIcon(
              key: const Key('detail-save'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
              onPressed: toggle,
              icon: const Icon(Icons.bookmark_remove_rounded, size: 28),
              label: Text(l.detailUnsave),
            )
          : OutlinedButton.icon(
              key: const Key('detail-save'),
              style: style,
              onPressed: toggle,
              icon: const Icon(Icons.bookmark_add_outlined, size: 28),
              label: Text(l.detailSave),
            );
  }
}

/// 흰 카드 안에 제목 + 내용.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// 요일별 운영 시간. 오늘 줄은 굵게 강조.
class _HoursTable extends StatelessWidget {
  const _HoursTable({required this.facility, required this.now});
  final Facility facility;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final theme = Theme.of(context);
    if (!facility.hoursTrusted) {
      // 사람이 확인하지 않은 시간은 표로 만들지 않고 원문 그대로 + 전화 확인 (decisions #16).
      final note = facility.hoursNote;
      return Column(
        key: const Key('unverified-hours'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note == null ? l.detailNoHours : l.detailUnverifiedHours,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(note, style: theme.textTheme.bodyLarge),
          ],
        ],
      );
    }
    final today = Weekday.fromNumber(now.weekday);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groupHoursByDay(l, facility.hours.rules))
          Builder(
            builder: (context) {
              final isToday = group.days.contains(today);
              final weight = isToday ? FontWeight.w800 : FontWeight.w400;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isToday ? theme.colorScheme.primaryContainer : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                // 요일과 시간을 위아래로 두어 글자를 키워도 겹치지 않게 한다.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday ? '${group.label} (${l.today})' : group.label,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(group.text, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: weight)),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
