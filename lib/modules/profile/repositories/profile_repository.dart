import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/services/supabase_service.dart';
import '../models/profile_model.dart';
import 'profile_repository_interface.dart';

class ProfileRepository implements IProfileRepository {
  ProfileRepository(this.service);
  final SupabaseService service;
  @override
  Future<String> uploadPhoto(Uint8List bytes) async {
    final userId = service.client.auth.currentUser?.id;
    debugPrint('[PROFILE_PHOTO_UPLOAD] Starting photo upload for user: $userId (${bytes.lengthInBytes} bytes)');
    if (userId == null) {
      debugPrint('[PROFILE_PHOTO_UPLOAD_ERROR] User is not signed in.');
      throw StateError('Please sign in to upload a photo.');
    }
    final path = '$userId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    debugPrint('[PROFILE_PHOTO_UPLOAD] Storage path: $path');
    try {
      await service.guard(
        () => service.client.storage
            .from('profile-photos')
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            ),
      );
      final publicUrl =
          service.client.storage.from('profile-photos').getPublicUrl(path);
      debugPrint('[PROFILE_PHOTO_UPLOAD] Upload SUCCESS ✅ URL: $publicUrl');
      return publicUrl;
    } catch (e, stack) {
      debugPrint('[PROFILE_PHOTO_UPLOAD_FAIL] Error: $e');
      debugPrint('[PROFILE_PHOTO_UPLOAD_FAIL] Stack: $stack');
      rethrow;
    }
  }

  @override
  Future<ProfileModel> save({
    required String name,
    required String phone,
    UserRole? role,
    String? address,
    String? companyName,
    String? photoPath,
  }) async {
    final saved = await service.call('profile.save', {
      'name': name.trim(),
      'phone': phone.trim(),
      'role': role?.name,
    });
    final details = await service.callNext('profile.details.save', {
      'phone': phone.trim(),
      'address': address?.trim(),
      'company_name': companyName?.trim(),
      'photo_path': photoPath?.trim(),
    });
    return ProfileModel.fromJson({
      ...Map<String, dynamic>.from(saved),
      ...Map<String, dynamic>.from(details),
    });
  }
}
