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

/// 긴급 연락처. 확인 근거는 data/research/emergency-numbers.md.
final emergencyContacts = <EmergencyContact>[
  EmergencyContact('1600-9582', (l) => l.emergencyHomeless, (l) => l.emergencyHomelessSub),
  EmergencyContact('129', (l) => l.emergencyWelfare, (l) => l.emergencyWelfareSub),
  EmergencyContact('109', (l) => l.emergencySuicide, (l) => l.emergencySuicideSub),
  EmergencyContact('120', (l) => l.emergencyDasan, (l) => l.emergencyDasanSub),
  EmergencyContact('112', (l) => l.emergencyPolice, (l) => l.emergencyPoliceSub),
  EmergencyContact('119', (l) => l.emergencyFire, (l) => l.emergencyFireSub),
];

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final launcher = AppScope.of(context).launcher;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.emergencyTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: emergencyContacts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final c = emergencyContacts[i];
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
