import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../scope.dart';
import '../widgets.dart';

class EmergencyContact {
  const EmergencyContact(this.number, this.title, this.subtitle);
  final String number;
  final String Function(L10n) title;
  final String Function(L10n) subtitle;
}

/// 확인 근거: data/research/verify-meal-shelter-20261104.md §4 (2026-11-04).
/// 서울 밖에는 24시간 노숙인 위기 전화를 찾지 못해 129 가 전국 기본값이다.
final _homelessSeoul = EmergencyContact('1600-9582', (l) => l.emergencyHomeless, (l) => l.emergencyHomelessSub);
final _welfare = EmergencyContact('129', (l) => l.emergencyWelfare, (l) => l.emergencyWelfareSub);
final _suicide = EmergencyContact('109', (l) => l.emergencySuicide, (l) => l.emergencySuicideSub);
final _mental = EmergencyContact('1577-0199', (l) => l.emergencyMental, (l) => l.emergencyMentalSub);
final _seoul120 = EmergencyContact('02-120', (l) => l.emergencyDasan, (l) => l.emergencyDasanSub);
final _gyeonggi120 = EmergencyContact('031-120', (l) => l.emergencyGyeonggi, (l) => l.emergencyGyeonggiSub);
final _police = EmergencyContact('112', (l) => l.emergencyPolice, (l) => l.emergencyPoliceSub);
final _fire = EmergencyContact('119', (l) => l.emergencyFire, (l) => l.emergencyFireSub);

/// 지역(시도)에 맞는 긴급 연락처. 지역 번호를 먼저, 전국 공통 번호는 어디서나.
List<EmergencyContact> emergencyContactsFor(String? sido) => [
      if (sido == '서울') _homelessSeoul,
      _welfare,
      _suicide,
      _mental,
      if (sido == '서울') _seoul120,
      if (sido == '경기') _gyeonggi120,
      _police,
      _fire,
    ];

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scope = AppScope.of(context);
    final launcher = scope.launcher;
    final sido = scope.controller.currentSido;
    final contacts = emergencyContactsFor(sido);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.emergencyTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: contacts.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Text(
              sido == null ? l.emergencyRegionUnknown : l.emergencyRegion(sido),
              style: theme.textTheme.bodyLarge,
            );
          }
          final c = contacts[i - 1];
          return Card(
            child: InkWell(
              key: Key('call-${c.number}'),
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final ok = await launcher.dial(c.number);
                if (!ok && context.mounted) showSnack(context, l.launchFailed);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primary,
                      child: Icon(Icons.call, color: theme.colorScheme.onPrimary, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title(l), style: theme.textTheme.titleLarge),
                          Text(c.number,
                              style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary)),
                          Text(c.subtitle(l), style: theme.textTheme.bodyLarge),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
