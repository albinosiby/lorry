import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lorry_link/design_system/design_system.dart';

enum AccountResource { legal, support }

class AccountResourcesScreen extends StatelessWidget {
  const AccountResourcesScreen({super.key, required this.resource});
  final AccountResource resource;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_title)),
    body: PageBody(
      narrow: true,
      child: switch (resource) {
        AccountResource.legal => _legal(context),
        AccountResource.support => _support(context),
      },
    ),
  );

  String get _title => switch (resource) {
    AccountResource.legal => 'Terms & privacy',
    AccountResource.support => 'Support',
  };

  Widget _legal(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageHeading(
        'Clear and practical',
        'Terms & privacy',
        'Using LORRY LINK means coordinating a transport booking directly with another verified account.',
      ),
      _PolicyCard(
        title: 'Booking terms',
        text:
            'A booking is assigned only after the customer accepts a driver request or the driver accepts a customer invitation. Confirm cargo, price, and timing before starting a trip.',
      ),
      _PolicyCard(
        title: 'Location privacy',
        text:
            'Driver location is collected only for an in-transit booking. The assigned customer and driver can see the latest shared location; it is not a public driver tracker.',
      ),
      _PolicyCard(
        title: 'Verification data',
        text:
            'Identity documents are stored in a private file area for verification. They are not shown to other customers or drivers.',
      ),
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
          title: const Text('Email support'),
          subtitle: const Text('support@lorrylink.app'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () =>
              launchUrl(Uri(scheme: 'mailto', path: 'support@lorrylink.app')),
        ),
      ),
      const Card(
        child: ListTile(
          leading: Icon(Icons.emergency_outlined),
          title: Text('Emergency during an active trip'),
          subtitle: Text(
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
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(text),
        ],
      ),
    ),
  );
}
