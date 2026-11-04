import 'package:flutter/material.dart';

import '../../domain/freshness.dart';
import '../../domain/saved_places.dart';
import '../../l10n/app_localizations.dart';
import '../format.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets.dart';
import 'detail_screen.dart';
import 'emergency_screen.dart';

/// 첫 화면에 보여 줄 저장한 곳 수. 더 있으면 "모두 보기".
const homeSavedLimit = 3;

/// 첫 화면 위쪽 "저장한 곳" 묶음. 저장한 곳이 없으면 아무것도 그리지 않는다.
class HomeSavedSection extends StatelessWidget {
  const HomeSavedSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final entries = AppScope.of(context).controller.savedEntriesNow();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('home-saved'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l.homeSavedTitle, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 10),
        for (final e in entries.take(homeSavedLimit))
          Padding(padding: const EdgeInsets.only(bottom: 12), child: SavedPlaceCard(entry: e)),
        if (entries.length > homeSavedLimit)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('home-saved-more'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SavedScreen())),
              icon: const Icon(Icons.bookmarks_rounded),
              label: Text(l.homeSavedMore(entries.length)),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// 저장한 곳 전체.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final entries = AppScope.of(context).controller.savedEntriesNow();
    return Scaffold(
      appBar: AppBar(title: Text(l.homeSavedTitle)),
      body: ListView(
        key: const Key('saved-list'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(l.savedEmpty, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            ),
          for (final e in entries)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: SavedPlaceCard(entry: e)),
        ],
      ),
      bottomNavigationBar: EmergencyBar(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmergencyScreen())),
      ),
    );
  }
}

/// 저장한 곳 카드 하나. 목록 카드보다 작게: 상태, 이름, 거리, 전화.
/// 지금 데이터에서 못 찾은 곳은 예전 정보라고 분명히 보여 준다.
class SavedPlaceCard extends StatelessWidget {
  const SavedPlaceCard({super.key, required this.entry});
  final SavedEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final now = scope.controller.clock();

    void openDetail(String id) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(facilityId: id)));

    Future<void> dial(String phone) async {
      final ok = await scope.launcher.dial(phone);
      if (!ok && context.mounted) showSnack(context, l.launchFailed);
    }

    final current = entry.current;
    if (current == null) {
      final saved = entry.saved;
      final warn = context.statusColors.closingSoon;
      return Card(
        key: Key('saved-${saved.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: warn),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.savedMissing,
                      style: theme.textTheme.titleMedium?.copyWith(color: warn, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(saved.name, style: theme.textTheme.titleLarge),
              Text(saved.address, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              if (saved.phone != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l.savedOldPhone(saved.phone!), style: theme.textTheme.bodyLarge),
                ),
              for (final s in entry.similar)
                TextButton.icon(
                  key: Key('saved-similar-${s.id}'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => openDetail(s.id),
                  icon: const Icon(Icons.search_rounded),
                  label: Text(l.savedSimilar(s.name)),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (saved.phone != null)
                    OutlinedButton.icon(
                      key: Key('saved-call-old-${saved.id}'),
                      onPressed: () => dial(saved.phone!),
                      icon: const Icon(Icons.call),
                      label: Text(l.savedCallOld),
                    ),
                  TextButton.icon(
                    key: Key('saved-remove-${saved.id}'),
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: () => scope.controller.removeSaved(saved.id),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(l.savedRemove),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final f = current.facility;
    return Card(
      key: Key('saved-${f.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openDetail(f.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusLine(status: current.status, now: now),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(Icons.bookmark_rounded, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(f.name, style: theme.textTheme.titleLarge)),
                ],
              ),
              if (current.distance != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.directions_walk, size: 22, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(child: Text(distanceText(l, current.distance!), style: theme.textTheme.bodyLarge)),
                    ],
                  ),
                ),
              if (current.freshness != Freshness.fresh) ...[
                const SizedBox(height: 6),
                FreshnessWarning(freshness: current.freshness),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: Key('saved-call-${f.id}'),
                      onPressed: f.phone == null ? null : () => dial(f.phone!),
                      icon: const Icon(Icons.call),
                      label: Text(f.phone == null ? l.noPhone : l.call),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(onPressed: () => openDetail(f.id), child: Text(l.details)),
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
