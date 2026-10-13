import 'profile_model.dart';

class ProfileScreenModel {
  const ProfileScreenModel(
    this.profile,
    this.email, {
    this.suggestedName = '',
    this.suggestedRole = UserRole.shipper,
  });
  final ProfileModel? profile;
  final String email, suggestedName;
  final UserRole suggestedRole;
}
