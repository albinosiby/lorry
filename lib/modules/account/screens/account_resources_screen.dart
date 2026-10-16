import 'package:lorry_link/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lorry_link/design_system/design_system.dart';
import '../models/terms_content.dart';

enum AccountResource { legal, support }

class AccountResourcesScreen extends StatelessWidget {
  const AccountResourcesScreen({super.key, required this.resource});
  final AccountResource resource;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: LocalizedText(_title)),
    body: PageBody(
      narrow: true,
      child: switch (resource) {
        AccountResource.legal => _legal(context),
        AccountResource.support => _support(context),
      },
    ),
  );

  String get _title => switch (resource) {
    AccountResource.legal => 'Terms & Conditions',
    AccountResource.support => 'Support',
  };

  Widget _legal(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageHeading(
        'LORRY LINK',
        'Terms & Conditions',
        'Please read these terms before using your customer or driver account.',
      ),
      for (final section in TermsContent.sections)
        _PolicyCard(title: section.title, text: section.text),
    ],
  );

  Widget _support(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageHeading(
        'We are here to help',
        'Support',
        'For a trip problem, include the booking route and current status so the team can help quickly.',
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.email_outlined),
          title: const LocalizedText('Email support'),
          subtitle: const LocalizedText('support@lorrylink.app'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () =>
              launchUrl(Uri(scheme: 'mailto', path: 'support@lorrylink.app')),
        ),
      ),
      const Card(
        child: ListTile(
          leading: Icon(Icons.emergency_outlined),
          title: LocalizedText('Emergency during an active trip'),
          subtitle: LocalizedText(
            'Contact local emergency services first, then report the issue to support.',
          ),
        ),
      ),
    ],
  );
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.title, required this.text});
  final String title, text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          LocalizedText(text),
        ],
      ),
    ),
  );
}
