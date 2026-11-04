import 'package:flutter/material.dart';

import '../../domain/region.dart';
import '../../l10n/app_localizations.dart';
import '../../services/location_service.dart';
import '../scope.dart';

Future<void> showOriginPicker(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const OriginPicker(),
    );

/// 위치 권한은 여기서 "지금 내 위치 쓰기"를 누를 때만 요청한다(앱 시작 시 요청하지 않음).
/// 권한이 없어도 시·도 → 시·군·구를 골라 전국 어디서나 쓸 수 있다.
class OriginPicker extends StatefulWidget {
  const OriginPicker({super.key});

  @override
  State<OriginPicker> createState() => _OriginPickerState();
}

class _OriginPickerState extends State<OriginPicker> {
  String? _sido;

  @override
  void initState() {
    super.initState();
    // 이미 고른 지역이 있으면 그 시·도의 시·군·구부터 보여 준다.
    _sido = AppScope.read(context).controller.origin.region?.sido;
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scope = AppScope.of(context);
    final c = scope.controller;
    final theme = Theme.of(context);
    final failure = c.lastLocationFailure;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.pickerTitle, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('use-gps'),
              onPressed: c.locating
                  ? null
                  : () async {
                      final navigator = Navigator.of(context);
                      if (await c.useGps()) navigator.pop();
                    },
              icon: c.locating
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
                  : const Icon(Icons.my_location, size: 28),
              label: Text(c.locating ? l.pickerLocating : l.pickerUseGps),
            ),
            const SizedBox(height: 8),
            Text(l.pickerGpsWhy, style: theme.textTheme.bodyMedium),
            if (failure != null) ...[
              const SizedBox(height: 12),
              Text(
                switch (failure) {
                  LocationFailure.denied => l.locDenied,
                  LocationFailure.deniedForever => l.locDeniedForever,
                  LocationFailure.serviceOff => l.locServiceOff,
                  LocationFailure.error => l.locError,
                },
                key: const Key('location-failure'),
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w700),
              ),
              if (failure == LocationFailure.deniedForever)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(onPressed: c.location.openSettings, child: Text(l.openSettings)),
                ),
            ],
            const SizedBox(height: 24),
            Text(l.pickerOr, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (c.regions.isEmpty)
              Text(l.pickerNoRegions, style: theme.textTheme.bodyLarge)
            else if (_sido == null)
              for (final sido in c.regions.sidos) ...[
                OutlinedButton(
                  key: Key('sido-$sido'),
                  onPressed: () => setState(() => _sido = sido),
                  child: Text(sido),
                ),
                const SizedBox(height: 10),
              ]
            else ...[
              Text(l.pickerSigungu(_sido!), style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('sido-back'),
                onPressed: () => setState(() => _sido = null),
                icon: const Icon(Icons.arrow_back),
                label: Text(l.pickerBack),
              ),
              const SizedBox(height: 8),
              for (final Region r in c.regions.inSido(_sido!)) ...[
                OutlinedButton(
                  key: Key('region-${r.code}'),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await c.useRegion(r);
                    navigator.pop();
                  },
                  child: Text(r.sigungu),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
