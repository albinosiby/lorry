import 'package:lorry_link/core/state/resource_cubit.dart';
import '../models/auth_models.dart';
import '../repositories/auth_repository_interface.dart';

class AuthFormCubit extends ResourceCubit<bool> {
  AuthFormCubit(this.repository);
  final IAuthRepository repository;
  Future<bool> signIn(SignInModel model) => act(() => repository.signIn(model));
  Future<bool> signUp(SignUpModel model) => act(
    () async {
      final signedIn = await repository.signUp(model);
      if (!isClosed) emit(ResourceState(data: signedIn, busy: true));
    },
    notice:
        'Account created. Check your email to confirm your address, then sign in.',
  );
  Future<bool> google() => act(repository.google);
  Future<bool> reset(PasswordResetModel model) => act(
    () => repository.resetPassword(model),
    notice:
        'If an account exists, a reset link is on its way. Check your inbox.',
  );
  Future<bool> updatePassword(String password) => act(
    () => repository.updatePassword(password),
    notice: 'Your password has been updated.',
  );
}
