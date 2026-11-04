import 'package:flutter/material.dart';

import '../../data/facility_repository.dart';
import '../../domain/category.dart';
import '../../domain/facility.dart';
import '../../domain/ranking.dart';
import '../../l10n/app_localizations.dart';
import '../format.dart';
import '../scope.dart';
import '../widgets.dart';
import 'detail_screen.dart';
import 'emergency_screen.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'origin_picker.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key, required this.group});
  final CategoryGroup group;

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  bool _showMap = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scope = AppScope.of(context);
    final c = scope.controller;
    final now = c.clock();
    final items = c.ranked(widget.group);
    final needOrigin = c.origin.point == null;
    final general = items.where((r) => r.facility.audience == Audience.general).toList();
    final senior = items.where((r) => r.facility.audience == Audience.senior).toList();

    void openDetail(RankedFacility item) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(facilityId: item.facility.id)));

    Widget card(RankedFacility item) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: FacilityCard(
            key: Key('facility-${item.facility.id}'),
            item: item,
            now: now,
            onOpen: () => openDetail(item),
            onCall: item.facility.phone == null
                ? null
                : () async {
                    final ok = await scope.launcher.dial(item.facility.phone!);
                    if (!ok && context.mounted) showSnack(context, l.launchFailed);
                  },
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(groupTitle(l, widget.group)),
        actions: [
          if (!needOrigin) TextButton.icon(
            key: const Key('toggle-map'),
            style: TextButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondaryContainer),
            onPressed: () => setState(() => _showMap = !_showMap),
            icon: Icon(_showMap ? Icons.list : Icons.map, size: 26),
            label: Text(_showMap ? l.viewList : l.viewMap),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _showMap
          ? MapView(items: items, now: now, onOpen: openDetail)
          : RefreshIndicator(
              onRefresh: () async {
                final messenger = ScaffoldMessenger.of(context);
                if (await c.refresh() == UpdateResult.updated) {
                  messenger.showSnackBar(SnackBar(content: Text(l.updated)));
                }
              },
              child: ListView(
                key: const Key('facility-list'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const OriginBar(),
                  const SizedBox(height: 12),
                  if (needOrigin)
                    _NeedOrigin()
                  else ...[
                    _Banner(icon: Icons.phone_rounded, text: l.listCallFirstBanner),
                    const SizedBox(height: 12),
                    if (widget.group == CategoryGroup.clinic) ...[
                      _Banner(
                        key: const Key('clinic-info'),
                        icon: Icons.medical_information_rounded,
                        title: l.clinicInfoTitle,
                        text: l.clinicInfoBody,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (items.isEmpty) _Empty(),
                    for (final item in general) card(item),
                    if (senior.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Semantics(
                        header: true,
                        child: Text(
                          l.seniorSectionTitle,
                          key: const Key('senior-section'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(l.seniorSectionSub, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 12),
                      for (final item in senior) card(item),
                    ],
                  ],
                ],
              ),
            ),
      bottomNavigationBar: EmergencyBar(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmergencyScreen())),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.icon, required this.text, this.title});
  final IconData icon;
  final String? title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(20)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(l.listEmpty, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(l.listEmptyHelp, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// 기준 위치가 없을 때: 전국 목록 대신 위치부터 정하게 한다.
class _NeedOrigin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final theme = Theme.of(context);
    return Padding(
      key: const Key('need-origin'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.place_rounded, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(l.listNeedOrigin, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(l.listNeedOriginHelp, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('need-origin-pick'),
            onPressed: () => showOriginPicker(context),
            icon: const Icon(Icons.place_rounded, size: 28),
            label: Text(l.originSet),
          ),
        ],
      ),
    );
  }
}
