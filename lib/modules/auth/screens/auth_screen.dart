import '../../../config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../profile/models/profile_model.dart';
import '../cubit/auth_form_cubit.dart';
import '../cubit/session_cubit.dart';
import '../models/auth_models.dart';

enum AuthScreenMode { signIn, signUp, forgot, reset }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.mode});
  final AuthScreenMode mode;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  UserRole role = UserRole.shipper;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  bool get signup => widget.mode == AuthScreenMode.signUp;
  bool get reset => widget.mode == AuthScreenMode.reset;
  bool get forgot => widget.mode == AuthScreenMode.forgot;
  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final cubit = context.read<AuthFormCubit>();
    final session = context.read<SessionCubit>();
    if (signup) {
      final ok = await cubit.signUp(
        SignUpModel(name.text, email.text, password.text, role),
      );
      if (ok) await session.refresh();
    } else if (forgot) {
      await cubit.reset(PasswordResetModel(email.text));
    } else if (reset) {
      if (await cubit.updatePassword(password.text)) {
        await session.recoveryFinished();
      }
    } else {
      if (await cubit.signIn(SignInModel(email.text, password.text))) {
        await session.refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: reset
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/welcome'),
            ),
    ),
    body: PageBody(
      narrow: true,
      child: BlocConsumer<AuthFormCubit, ResourceState<bool>>(
        listener: (context, state) {
          if (state.error != null) showNotice(context, state.error!);
          if (state.notice != null) showNotice(context, state.notice!);
        },
        builder: (context, state) => Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Brand(),
              const SizedBox(height: 36),
              PageHeading(
                'Your journey starts here',
                signup
                    ? 'Let’s get you moving.'
                    : forgot
                    ? 'Forgot your password?'
                    : reset
                    ? 'A fresh start.'
                    : 'Welcome back.',
                signup
                    ? 'Create your account to connect with the road.'
                    : forgot
                    ? 'We’ll send a link to help you get back in.'
                    : reset
                    ? 'Choose a new password for your account.'
                    : 'Sign in and pick up where you left off.',
              ),
              if (signup)
                AppTextField(
                  controller: name,
                  label: 'Full name',
                  validator: Validators.name,
                  maxLength: 80,
                ),
              if (!reset)
                AppTextField(
                  controller: email,
                  label: 'Email address',
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
              if (!forgot)
                AppTextField(
                  controller: password,
                  label: reset ? 'New password' : 'Password',
                  password: true,
                  validator: signup || reset
                      ? Validators.password
                      : Validators.required,
                ),
              if (signup || reset)
                AppTextField(
                  controller: confirmation,
                  label: 'Confirm password',
                  password: true,
                  validator: (v) =>
                      v != password.text ? 'Passwords must match.' : null,
                ),
              if (signup) ...[
                const Text(
                  'I’m here to',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: UserRole.values
                      .map(
                        (r) => ChoiceChip(
                          label: Text(
                            r == UserRole.shipper ? 'Ship goods' : 'Find loads',
                          ),
                          avatar: Icon(
                            r == UserRole.shipper
                                ? Icons.inventory_2_outlined
                                : Icons.local_shipping_outlined,
                            size: 18,
                          ),
                          selected: role == r,
                          onSelected: (_) => setState(() => role = r),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
              ],
              if (!signup && !forgot && !reset)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go('/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                ),
              AppButton(
                label: signup
                    ? 'Create account'
                    : forgot
                    ? 'Send reset link'
                    : reset
                    ? 'Update password'
                    : 'Sign in',
                busy: state.busy,
                onPressed: submit,
              ),
              if (!forgot && !reset && AppConfig.googleEnabled) ...[
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('or', style: TextStyle(fontSize: 12)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: state.busy
                      ? null
                      : () => context.read<AuthFormCubit>().google(),
                  icon: const Icon(Icons.g_mobiledata, size: 27),
                  label: const Text('Continue with Google'),
                ),
                const SizedBox(height: 20),
              ],
              if (!forgot && !reset) ...[
                TextButton(
                  onPressed: () => context.go(signup ? '/sign-in' : '/sign-up'),
                  child: Text(
                    signup
                        ? 'Already registered? Sign in'
                        : 'New to LORRY LINK? Create account',
                  ),
                ),
              ],
              if (forgot)
                TextButton(
                  onPressed: () => context.go('/sign-in'),
                  child: const Text('Back to sign in'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
