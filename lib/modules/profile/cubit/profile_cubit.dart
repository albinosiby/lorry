import 'dart:typed_data';
import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../auth/repositories/auth_repository_interface.dart';
import '../models/profile_model.dart';
import '../models/profile_screen_model.dart';
import '../repositories/profile_repository_interface.dart';

class ProfileCubit extends ResourceCubit<ProfileScreenModel> {
  ProfileCubit(this.repository, this.auth);
  final IProfileRepository repository;
  final IAuthRepository auth;
  Future<void> load() => fetch(
    () async => ProfileScreenModel(
      await auth.profile(),
      auth.email,
      suggestedName: auth.suggestedName,
      suggestedRole: auth.suggestedRole,
    ),
  );
  Future<bool> save(
    String name,
    String phone,
    UserRole? role, {
    String? address,
    String? companyName,
    String? photoPath,
  }) => act(() async {
    await repository.save(
      name: name,
      phone: phone,
      role: role,
      address: address,
      companyName: companyName,
      photoPath: photoPath,
    );
  }, notice: 'Profile saved.');
  Future<bool> signOut() => act(auth.signOut);
  Future<String?> uploadPhoto(Uint8List bytes) async {
    String? path;
    final ok = await act(() async {
      path = await repository.uploadPhoto(bytes);
    }, notice: 'Profile photo uploaded. Save your profile to apply it.');
    return ok ? path : null;
  }
}
