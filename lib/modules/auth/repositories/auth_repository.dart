import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/app_config.dart';
import '../../../utils/services/supabase_service.dart';
import '../../profile/models/profile_model.dart';
import '../models/auth_models.dart';
import 'auth_repository_interface.dart';

class AuthRepository implements IAuthRepository {
  AuthRepository(this.service);
  final SupabaseService service;
  @override
  Stream<SessionEvent> get events => service.client.auth.onAuthStateChange.map(
    (event) => event.event == AuthChangeEvent.passwordRecovery
        ? SessionEvent.recovery
        : SessionEvent.changed,
  );
  @override
  bool get signedIn => service.client.auth.currentSession != null;
  @override
  String get email => service.client.auth.currentUser?.email ?? '';
  @override
  String get suggestedName =>
      (service.client.auth.currentUser?.userMetadata?['name'] ??
              service.client.auth.currentUser?.userMetadata?['full_name'] ??
              '')
          as String;
  @override
  UserRole get suggestedRole =>
      service.client.auth.currentUser?.userMetadata?['preferred_role'] ==
          'driver'
      ? UserRole.driver
      : UserRole.shipper;
  @override
  Future<void> signIn(SignInModel m) => service.guard(() async {
    await service.client.auth.signInWithPassword(
      email: m.email.trim(),
      password: m.password,
    );
  });
  @override
  Future<bool> signUp(SignUpModel m) => service.guard(() async {
    final response = await service.client.auth.signUp(
      email: m.email.trim(),
      password: m.password,
      emailRedirectTo: AppConfig.redirectUrl,
      data: {'name': m.name, 'preferred_role': m.role.name},
    );
    return response.session != null;
  });
  @override
  Future<void> google() => service.guard(() async {
    await service.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.redirectUrl,
    );
  });
  @override
  Future<void> resetPassword(PasswordResetModel m) => service.guard(
    () => service.client.auth.resetPasswordForEmail(
      m.email.trim(),
      redirectTo: AppConfig.redirectUrl,
    ),
  );
  @override
  Future<void> updatePassword(String password) => service.guard(() async {
    await service.client.auth.updateUser(UserAttributes(password: password));
  });
  @override
  Future<void> signOut() => service.guard(() => service.client.auth.signOut());
  @override
  Future<ProfileModel?> profile() async {
    final json = await service.call('profile.get');
    return json == null
        ? null
        : ProfileModel.fromJson(Map<String, dynamic>.from(json));
  }
}
