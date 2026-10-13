import '../models/profile_model.dart';

abstract interface class IProfileRepository {
  Future<ProfileModel> save({
    required String name,
    required String phone,
    UserRole? role,
  });
}
