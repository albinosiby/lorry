import 'package:lorry_link/l10n/app_localizations.dart';
import '../../../config/app_config.dart';
import '../../../config/routes/routes.dart';
import '../../settings/widgets/language_picker.dart';
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
  const AuthScreen({super.key, required this.mode, this.initialRole});
  final AuthScreenMode mode;
  final UserRole? initialRole;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final terms = GlobalKey<FormFieldState<bool>>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  late UserRole role;

  @override
  void initState() {
    super.initState();
    role = widget.initialRole ?? UserRole.shipper;
  }

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
              onPressed: () =>
                  context.go(signup ? '/role-selection' : '/welcome'),
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
              if (!forgot && !reset) ...[
                const SizedBox(height: 16),
                const LanguagePicker(),
              ],
              const SizedBox(height: 36),
              PageHeading(
                signup
                    ? (role == UserRole.shipper
                          ? 'CUSTOMER SIGN UP'
                          : 'DRIVER SIGN UP')
                    : 'Your journey starts here',
                signup
                    ? (role == UserRole.shipper
                          ? 'Get a truck for your load.'
                          : 'Get load for your truck.')
                    : forgot
                    ? 'Forgot your password?'
                    : reset
                    ? 'A fresh start.'
                    : 'Welcome back.',
                signup
                    ? (role == UserRole.shipper
                          ? 'Create your account to connect with verified trucks and ship easily.'
                          : 'Create your account to find high-paying freight and start hauling.')
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

              if (!signup && !forgot && !reset)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go('/forgot-password'),
                    child: const LocalizedText('Forgot password?'),
                  ),
                ),
              if (!forgot && !reset) ...[
                FormField<bool>(
                  key: terms,
                  initialValue: false,
                  validator: (value) => value == true
                      ? null
                      : 'Please agree to the Terms & Conditions to continue.',
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: field.value ?? false,
                            semanticLabel: localize(
                              context,
                              'Agree to Terms & Conditions',
                            ),
                            onChanged: state.busy
                                ? null
                                : (value) {
                                    field.didChange(value ?? false);
                                    if (field.hasError) field.validate();
                                  },
                          ),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const LocalizedText('I agree to the'),
                                TextButton(
                                  onPressed: () => context.push(Routes.legal),
                                  child: const LocalizedText(
                                    'Terms & Conditions',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (field.hasError)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 12),
                          child: LocalizedText(
                            field.errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
                      child: LocalizedText(
                        'or',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: state.busy
                      ? null
                      : () {
                          if (terms.currentState?.validate() != true) return;
                          context.read<AuthFormCubit>().google();
                        },
                  icon: const Icon(Icons.g_mobiledata, size: 27),
                  label: const LocalizedText('Continue with Google'),
                ),
                const SizedBox(height: 20),
              ],
              if (!forgot && !reset) ...[
                TextButton(
                  onPressed: () => context.go(signup ? '/sign-in' : '/sign-up'),
                  child: LocalizedText(
                    signup
                        ? 'Already registered? Sign in'
                        : 'New to LORRY LINK? Create account',
                  ),
                ),
              ],
              if (forgot)
                TextButton(
                  onPressed: () => context.go('/sign-in'),
                  child: const LocalizedText('Back to sign in'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
