import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/exceptions/app_exception.dart';

class ResourceState<T> extends Equatable {
  const ResourceState({
    this.data,
    this.loading = false,
    this.busy = false,
    this.error,
    this.notice,
  });
  final T? data;
  final bool loading, busy;
  final String? error, notice;
  @override
  List<Object?> get props => [data, loading, busy, error, notice];
}

abstract class ResourceCubit<T> extends Cubit<ResourceState<T>> {
  ResourceCubit() : super(ResourceState<T>());
  int _generation = 0;
  Future<void> fetch(Future<T> Function() operation) async {
    if (isClosed || state.busy) return;
    final generation = ++_generation;
    emit(ResourceState(data: state.data, loading: true));
    try {
      final data = await operation();
      if (!isClosed && generation == _generation) {
        emit(ResourceState(data: data));
      }
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(
          ResourceState(
            data: state.data,
            error: AppException.from(error).message,
          ),
        );
      }
    }
  }

  Future<bool> act(Future<void> Function() operation, {String? notice}) async {
    if (isClosed || state.busy) return false;
    ++_generation;
    emit(ResourceState(data: state.data, busy: true));
    try {
      await operation();
      if (!isClosed) emit(ResourceState(data: state.data, notice: notice));
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          ResourceState(
            data: state.data,
            error: AppException.from(error).message,
          ),
        );
      }
      return false;
    }
  }
}
