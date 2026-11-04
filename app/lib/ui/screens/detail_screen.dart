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
      return Scaffold(appBar: AppBar(), body: Center(child: Text(l.listEmpty)));
    }
    final ranked = RankedFacility(
      facility: f,
      status: f.hours.statusAt(now, isHoliday: dataset.isHoliday),
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
          Text(f.name, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          StatusLine(status: ranked.status, now: now, large: true),
          if (ranked.distance != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.directions_walk),
              const SizedBox(width: 8),
              Expanded(child: Text(walkText(l, ranked.distance!), style: theme.textTheme.titleMedium)),
            ]),
          ],
          const SizedBox(height: 12),
          FreshnessWarning(freshness: ranked.freshness),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('detail-call'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
            onPressed: f.phone == null ? null : () => run(() => scope.launcher.dial(f.phone!)),
            icon: const Icon(Icons.call, size: 30),
            label: Text(f.phone == null ? l.noPhone : '${l.callLong}  ${f.phone}'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('detail-directions'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(64)),
            onPressed: () => run(() => scope.launcher.directions(f.name, f.location)),
            icon: const Icon(Icons.directions_walk, size: 30),
            label: Text(l.directions),
          ),
          const SizedBox(height: 28),
          _Section(title: l.detailHours, child: _HoursTable(facility: f, now: now)),
          if (f.hoursNote != null)
            _Section(title: l.detailNote, child: Text(f.hoursNote!, style: theme.textTheme.bodyLarge)),
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
          const Divider(height: 32),
          Text(l.detailVerified(dateText(f.lastVerified)), style: theme.textTheme.bodyMedium),
          if (source != null)
            Text(l.detailSource(source.provider == null ? source.name : '${source.provider} · ${source.name}'),
                style: theme.textTheme.bodyMedium),
          if (scope.config.reportEmail != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('detail-report'),
              onPressed: () => run(() => scope.launcher.email(
                    scope.config.reportEmail!,
                    subject: '[마중 정보 오류] ${f.name}',
                    body: '시설: ${f.name} (${f.id})\n틀린 내용:\n\n맞는 내용:\n',
                  )),
              icon: const Icon(Icons.flag_outlined),
              label: Text(l.detailReport),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
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
    if (facility.hours.isEmpty) return Text(l.detailNoHours, style: theme.textTheme.bodyLarge);
    final today = Weekday.fromNumber(now.weekday);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groupHoursByDay(l, facility.hours.rules))
          Builder(builder: (context) {
            final isToday = group.days.contains(today);
            final weight = isToday ? FontWeight.w800 : FontWeight.w400;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: isToday ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6) : null,
                borderRadius: BorderRadius.circular(8),
              ),
              // 요일과 시간을 위아래로 두어 글자를 키워도 겹치지 않게 한다.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isToday ? '${group.label} (${l.today})' : group.label,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Text(group.text, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: weight)),
                ],
              ),
            );
          }),
      ],
    );
  }
}
