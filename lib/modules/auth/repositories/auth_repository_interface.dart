import '../models/auth_models.dart';
import '../../profile/models/profile_model.dart';

enum SessionEvent { changed, recovery }

abstract interface class IAuthRepository {
  Stream<SessionEvent> get events;
  bool get signedIn;
  String get email;
  String get suggestedName;
  UserRole get suggestedRole;
  Future<void> signIn(SignInModel model);
  Future<bool> signUp(SignUpModel model);
  Future<void> google();
  Future<void> resetPassword(PasswordResetModel model);
  Future<void> updatePassword(String password);
  Future<void> signOut();
  Future<ProfileModel?> profile();
}
