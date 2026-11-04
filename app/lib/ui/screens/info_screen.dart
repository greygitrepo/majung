import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../format.dart';
import '../scope.dart';
import '../widgets.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scope = AppScope.of(context);
    final dataset = scope.controller.dataset;
    final theme = Theme.of(context);

    Widget section(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(title, style: theme.textTheme.titleLarge)),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.info)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          section(l.appTitle, [Text(l.infoAbout, style: theme.textTheme.bodyLarge)]),
          section(l.infoPrivacy, [
            Text(l.infoPrivacyBody, style: theme.textTheme.bodyLarge),
            if (scope.config.privacyPolicyUrl != null)
              TextButton(
                onPressed: () => scope.launcher.openWeb(scope.config.privacyPolicyUrl!),
                child: Text(l.infoPrivacy),
              ),
          ]),
          section(l.infoSources, [
            if (dataset != null)
              Text(l.infoDataVersion(dateText(dataset.version.toLocal())), style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            for (final s in dataset?.sources ?? const [])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  [s.provider, s.name, s.license].whereType<String>().join(' · '),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            Text(l.infoMapCredit, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 10),
            Text(l.infoFontCredit, style: theme.textTheme.bodyMedium),
          ]),
          if (scope.config.reportEmail != null)
            section(l.infoContact, [
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await scope.launcher.email(scope.config.reportEmail!, subject: '[마중 문의]', body: '');
                  if (!ok && context.mounted) showSnack(context, l.launchFailed);
                },
                icon: const Icon(Icons.mail_outline),
                label: Text(scope.config.reportEmail!),
              ),
            ]),
        ],
      ),
    );
  }
}
