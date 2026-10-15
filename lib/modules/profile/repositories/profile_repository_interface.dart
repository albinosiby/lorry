import 'dart:typed_data';
import '../models/profile_model.dart';

abstract interface class IProfileRepository {
  Future<ProfileModel> save({
    required String name,
    required String phone,
    UserRole? role,
    String? address,
    String? companyName,
    String? photoPath,
    String? gender,
  });
  Future<String> uploadPhoto(Uint8List bytes);
}
