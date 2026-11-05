import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../domain/category.dart';
import '../../l10n/app_localizations.dart';
import '../format.dart';
import '../scope.dart';
import '../widgets.dart';
import 'emergency_screen.dart';
import 'info_screen.dart';
import 'list_screen.dart';
import 'origin_picker.dart';
import 'saved_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final c = AppScope.of(context).controller;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppMark(),
            const SizedBox(width: 10),
            Flexible(child: Text(l.appTitle)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l.info,
            iconSize: 26,
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InfoScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !c.ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Semantics(header: true, child: Text(l.homeGreeting, style: Theme.of(context).textTheme.headlineLarge)),
                const SizedBox(height: 4),
                Text(
                  l.homeGreetingSub,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                const OriginBar(),
                const SizedBox(height: 20),
                // 자주 가는 곳은 카테고리를 거치지 않고 바로 (decisions #20).
                const HomeSavedSection(),
                for (final group in CategoryGroup.enabled) ...[
                  BigCategoryButton(
                    key: Key('group-${group.name}'),
                    group: group,
                    icon: groupIcon(group),
                    title: groupTitle(l, group),
                    subtitle: groupSubtitle(l, group),
                    footnote: c.origin.point == null
                        ? l.homeNeedOrigin
                        : l.openCount(c.openCount(group), c.ranked(group).length),
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListScreen(group: group))),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
      bottomNavigationBar: EmergencyBar(
        showHint: true,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmergencyScreen())),
      ),
    );
  }
}

/// 지금 어디 기준으로 거리를 계산하는지 + 바꾸기.
class OriginBar extends StatelessWidget {
  const OriginBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final c = AppScope.of(context).controller;
    final scheme = Theme.of(context).colorScheme;
    final text = switch (c.origin.kind) {
      OriginKind.none => l.originNone,
      OriginKind.gps => l.originGps,
      OriginKind.region => l.originRegion(c.origin.region!.label),
    };
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const Key('origin-bar'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => showOriginPicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          // 글자를 크게 키워도 좁아지지 않게 설명과 버튼을 위아래로 둔다.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place_rounded, color: scheme.primary, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSecondaryContainer),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.origin.kind == OriginKind.none ? l.originSet : l.originChange,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? scheme.primary
                            : const Color(0xFF9A4524),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
