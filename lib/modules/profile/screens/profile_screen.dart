import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../auth/cubit/session_cubit.dart';
import '../cubit/profile_cubit.dart';
import '../models/profile_screen_model.dart';
import '../models/profile_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.setup = false});
  final bool setup;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), phone = TextEditingController();
  UserRole role = UserRole.shipper;
  bool populated = false;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  void populate(ProfileScreenModel? model) {
    if (!populated && model != null) {
      name.text = model.profile?.name ?? model.suggestedName;
      phone.text = model.profile?.phone ?? '';
      role = model.profile?.role ?? model.suggestedRole;
      populated = true;
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final session = context.read<SessionCubit>();
    if (await context.read<ProfileCubit>().save(
      name.text,
      phone.text,
      widget.setup ? role : null,
    )) {
      await session.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = PageBody(
      narrow: true,
      child: BlocConsumer<ProfileCubit, ResourceState<ProfileScreenModel>>(
        listener: (context, state) {
          populate(state.data);
          if (state.error != null) showNotice(context, state.error!);
          if (state.notice != null) showNotice(context, state.notice!);
        },
        builder: (context, state) {
          populate(state.data);
          return ResourceView<ProfileScreenModel>(
            state: state,
            retry: () => context.read<ProfileCubit>().load(),
            builder: (model) => Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeading(
                    'Your account',
                    widget.setup ? 'Make it yours.' : 'Your profile',
                    widget.setup
                        ? 'Choose how you’ll use LORRY LINK. Your primary role stays fixed.'
                        : 'Keep your details up to date for smoother coordination.',
                  ),
                  Center(
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Text(
                        name.text.isEmpty ? 'L' : name.text[0].toUpperCase(),
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    controller: name,
                    label: 'Full name',
                    validator: Validators.name,
                    maxLength: 80,
                  ),
                  AppTextField(
                    controller: phone,
                    label: 'Phone number',
                    keyboardType: TextInputType.phone,
                    maxLength: 25,
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Phone number is required.';
                      return RegExp(r'^\+?[0-9 ()-]{7,25}$').hasMatch(value)
                          ? null
                          : 'Enter a valid phone number.';
                    },
                  ),
                  InfoRow(Icons.mail_outline, 'Email address', model.email),
                  if (widget.setup) ...[
                    const SizedBox(height: 16),
                    ...UserRole.values.map(
                      (r) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Icon(
                            r == UserRole.shipper
                                ? Icons.inventory_2_outlined
                                : Icons.local_shipping_outlined,
                          ),
                          title: Text(r.label),
                          subtitle: Text(
                            r == UserRole.shipper
                                ? 'Post loads and choose a driver'
                                : 'Find loads and manage trips',
                          ),
                          trailing: Icon(
                            role == r
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          onTap: () => setState(() => role = r),
                        ),
                      ),
                    ),
                  ] else
                    InfoRow(
                      Icons.badge_outlined,
                      'Primary role',
                      model.profile?.role.label ?? '',
                    ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: widget.setup ? 'Start my journey' : 'Save changes',
                    busy: state.busy,
                    onPressed: save,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: state.busy
                        ? null
                        : () async {
                            if (await confirmAction(
                                  context,
                                  'Sign out?',
                                  'You can sign back in at any time.',
                                  confirm: 'Sign out',
                                ) &&
                                context.mounted) {
                              await context.read<ProfileCubit>().signOut();
                            }
                          },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                  const Divider(),
                  const Text(
                    'LORRY LINK · Version 1.0.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return widget.setup
        ? Scaffold(
            appBar: AppBar(title: const Brand()),
            body: body,
          )
        : body;
  }
}
