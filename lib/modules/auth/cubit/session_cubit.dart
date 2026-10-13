import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../utils/exceptions/app_exception.dart';
import '../models/auth_models.dart';
import '../repositories/auth_repository_interface.dart';

class SessionCubit extends Cubit<SessionModel> {
  SessionCubit(this.repository)
    : super(const SessionModel(SessionStatus.loading)) {
    _subscription = repository.events.listen(
      (event) {
        if (event == SessionEvent.recovery) {
          _recovery = true;
          ++_generation;
          emit(SessionModel(SessionStatus.recovery, profile: state.profile));
        } else {
          refresh();
        }
      },
      onError: (Object e) {
        emit(
          SessionModel(
            SessionStatus.failure,
            error: AppException.from(e).message,
          ),
        );
      },
    );
  }
  final IAuthRepository repository;
  StreamSubscription<SessionEvent>? _subscription;
  bool _recovery = false;
  int _generation = 0;
  Future<void> refresh() async {
    final version = ++_generation;
    if (!repository.signedIn) {
      _recovery = false;
      emit(const SessionModel(SessionStatus.signedOut));
      return;
    }
    if (_recovery) {
      emit(SessionModel(SessionStatus.recovery, profile: state.profile));
      return;
    }
    try {
      final p = await repository.profile();
      if (!isClosed && version == _generation) {
        emit(
          SessionModel(
            p == null ? SessionStatus.setup : SessionStatus.ready,
            profile: p,
          ),
        );
      }
    } catch (e) {
      if (!isClosed && version == _generation) {
        emit(
          SessionModel(
            SessionStatus.failure,
            error: AppException.from(e).message,
          ),
        );
      }
    }
  }

  Future<void> recoveryFinished() async {
    _recovery = false;
    await refresh();
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
