import 'package:flutter/material.dart';

import '../../domain/category.dart';
import '../../domain/freshness.dart';
import '../../domain/saved_places.dart';
import '../../l10n/app_localizations.dart';
import '../format.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets.dart';
import 'detail_screen.dart';
import 'emergency_screen.dart';

/// 첫 화면의 "저장한 곳" 버튼 하나. 누르면 저장한 곳 전체 화면.
/// 카드를 첫 화면에 늘어놓으면 카테고리 버튼이 밀려 내려가서 버튼 하나로 묶는다 (decisions #20).
/// 저장한 곳이 없으면 아무것도 그리지 않는다.
class HomeSavedSection extends StatelessWidget {
  const HomeSavedSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final c = AppScope.of(context).controller;
    final entries = c.savedEntriesNow();
    if (entries.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final open = entries.where((e) => e.current?.status.isOpenNow ?? false).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: BigButton(
        key: const Key('home-saved'),
        bg: scheme.tertiaryContainer,
        fg: scheme.onTertiaryContainer,
        icon: Icons.bookmarks_rounded,
        title: l.homeSavedTitle,
        subtitle: l.homeSavedSub,
        footnote: l.openCount(open, entries.length),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SavedScreen())),
      ),
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
          // 많아져도 헷갈리지 않게 첫 화면과 같은 순서·색으로 나눈다 (decisions #20).
          for (final (group, items) in groupSaved(entries)) ...[
            SavedGroupHeader(group: group, count: items.length),
            const SizedBox(height: 12),
            for (final e in items)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: SavedPlaceCard(entry: e)),
            const SizedBox(height: 12),
          ],
        ],
      ),
      bottomNavigationBar: EmergencyBar(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmergencyScreen())),
      ),
    );
  }
}

/// 저장한 곳을 첫 화면 버튼 순서(밥 → 잠자리 → 진료 …)로 묶는다. 묶음 안 순서는 그대로.
List<(CategoryGroup, List<SavedEntry>)> groupSaved(List<SavedEntry> entries) {
  final order = [...CategoryGroup.enabled, ...CategoryGroup.values.where((g) => !CategoryGroup.enabled.contains(g))];
  return [
    for (final g in order)
      if (entries.where((e) => g.contains(e.saved.category)).toList() case final items when items.isNotEmpty)
        (g, items),
  ];
}

/// 저장한 곳 화면의 묶음 제목: 첫 화면 버튼과 같은 아이콘·색.
class SavedGroupHeader extends StatelessWidget {
  const SavedGroupHeader({super.key, required this.group, required this.count});
  final CategoryGroup group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final theme = Theme.of(context);
    final c = context.groupColors.of(group, theme.colorScheme);
    return Semantics(
      header: true,
      label: l.savedGroupHeader(groupTitle(l, group), count),
      excludeSemantics: true,
      child: Container(
        key: Key('saved-group-${group.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle),
              child: Icon(groupIcon(group), size: 28, color: c.fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                groupTitle(l, group),
                style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            Text(l.placeCount(count), style: theme.textTheme.titleMedium?.copyWith(color: c.fg)),
          ],
        ),
      ),
    );
  }
}

/// 저장한 곳 카드 하나. 목록 카드보다 작게: 이름, 상태, 거리, 전화.
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
              Text(saved.name, style: placeNameStyle(context)),
              const SizedBox(height: 6),
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
              const SizedBox(height: 6),
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
              Text(f.name, style: placeNameStyle(context)),
              const SizedBox(height: 8),
              StatusLine(status: current.status, now: now),
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
