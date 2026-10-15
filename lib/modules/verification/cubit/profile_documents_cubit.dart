import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../../utils/exceptions/app_exception.dart';
import '../models/profile_document_model.dart';
import '../repositories/profile_documents_repository_interface.dart';

class ProfileDocumentsCubit extends ResourceCubit<List<ProfileDocumentModel>> {
  ProfileDocumentsCubit(this.repository);
  final IProfileDocumentsRepository repository;

  Future<void> load() => fetch(repository.list);

  Future<bool> upload(ProfileDocumentDraft draft) async {
    if (isClosed || state.busy) return false;
    emit(ResourceState(data: state.data, busy: true));

    try {
      final document = await repository.upload(draft);
      if (!isClosed) {
        emit(
          ResourceState(
            data: [document],
            notice: 'Identity document submitted for verification.',
          ),
        );
      }
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

  Future<bool> remove(ProfileDocumentModel document) async {
    if (isClosed || state.busy) return false;
    emit(ResourceState(data: state.data, busy: true));

    try {
      await repository.remove(document);
      if (!isClosed) {
        emit(
          const ResourceState(data: [], notice: 'Identity document removed.'),
        );
      }
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

  Future<Uri?> viewUrl(ProfileDocumentModel document) async {
    try {
      return await repository.viewUrl(document);
    } catch (error) {
      if (!isClosed) {
        emit(
          ResourceState(
            data: state.data,
            error: AppException.from(error).message,
          ),
        );
      }
      return null;
    }
  }
}
