import '../../../utils/services/supabase_service.dart';
import '../models/profile_model.dart';
import 'profile_repository_interface.dart';

class ProfileRepository implements IProfileRepository {
  ProfileRepository(this.service);
  final SupabaseService service;
  @override
  Future<ProfileModel> save({
    required String name,
    required String phone,
    UserRole? role,
  }) async => ProfileModel.fromJson(
    await service.call('profile.save', {
      'name': name.trim(),
      'phone': phone.trim(),
      'role': role?.name,
    }),
  );
}
