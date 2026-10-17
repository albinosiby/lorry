import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:lorry_link/l10n/app_localizations.dart';
import '../../auth/cubit/session_cubit.dart';
import '../cubit/support_cubit.dart';
import '../models/support_request.dart';
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
        AccountResource.support => const _SupportForm(),
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
}

class _SupportForm extends StatefulWidget {
  const _SupportForm();

  @override
  State<_SupportForm> createState() => _SupportFormState();
}

class _SupportFormState extends State<_SupportForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _issue = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Name is account data; email remains editable because the profile does
    // not store the authentication email.
    _name.text = context.read<SessionCubit>().state.profile?.name ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _issue.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final profile = context.read<SessionCubit>().state.profile;
    await context.read<SupportCubit>().submit(
      SupportRequest(
        name: _name.text,
        email: _email.text,
        issue: _issue.text,
        userId: profile?.id ?? 'unknown',
        userRole: profile?.role.name ?? 'unknown',
        phone: profile?.phone ?? '',
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<SupportCubit, ResourceState<void>>(
    listener: (context, state) {
      if (state.error != null) showNotice(context, state.error!);
      if (state.notice != null) {
        _name.clear();
        _email.clear();
        _issue.clear();
        showNotice(context, state.notice!);
      }
    },
    builder: (context, state) => Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeading(
            'We are here to help',
            'Support',
            'Tell us what happened and our support team will contact you by email.',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _name,
                    label: 'Name',
                    hint: 'Your full name',
                    validator: Validators.name,
                    textCapitalization: TextCapitalization.words,
                  ),
                  AppTextField(
                    controller: _email,
                    label: 'Email address',
                    hint: 'you@example.com',
                    validator: Validators.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  AppTextField(
                    controller: _issue,
                    label: 'Describe the issue',
                    hint:
                        'Include the booking route or current trip status when relevant.',
                    validator: Validators.required,
                    lines: 5,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 4),
                  AppButton(
                    label: 'Send support request',
                    icon: Icons.send_outlined,
                    busy: state.busy,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
      ),
    ),
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
