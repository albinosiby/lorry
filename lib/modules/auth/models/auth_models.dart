import 'package:equatable/equatable.dart';
import '../../profile/models/profile_model.dart';

class SignInModel {
  const SignInModel(this.email, this.password);
  final String email, password;
}

class SignUpModel {
  const SignUpModel(this.name, this.email, this.password, this.role);
  final String name, email, password;
  final UserRole role;
}

class PasswordResetModel {
  const PasswordResetModel(this.email);
  final String email;
}

enum SessionStatus { loading, signedOut, setup, ready, recovery, failure }

class SessionModel extends Equatable {
  const SessionModel(this.status, {this.profile, this.error});
  final SessionStatus status;
  final ProfileModel? profile;
  final String? error;
  @override
  List<Object?> get props => [status, profile, error];
}
