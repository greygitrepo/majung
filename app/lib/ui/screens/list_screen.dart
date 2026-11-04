import 'package:flutter/material.dart';

import '../../data/facility_repository.dart';
import '../../domain/category.dart';
import '../../domain/ranking.dart';
import '../../l10n/app_localizations.dart';
import '../format.dart';
import '../scope.dart';
import '../widgets.dart';
import 'detail_screen.dart';
import 'emergency_screen.dart';
import 'home_screen.dart';
import 'map_screen.dart';

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

    void openDetail(RankedFacility item) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(facilityId: item.facility.id)));

    return Scaffold(
      appBar: AppBar(
        title: Text(groupTitle(l, widget.group)),
        actions: [
          TextButton.icon(
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
                  _Banner(text: l.listCallFirstBanner),
                  const SizedBox(height: 12),
                  if (items.isEmpty) _Empty(),
                  for (final item in items) ...[
                    FacilityCard(
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
                    const SizedBox(height: 14),
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
  const _Banner({required this.text});
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
          Icon(Icons.phone_rounded, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w600),
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
