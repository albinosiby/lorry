import 'package:flutter/foundation.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../../utils/exceptions/app_exception.dart';
import '../../vehicles/repositories/vehicle_repository_interface.dart';
import '../models/driver_document_model.dart';
import '../models/driver_documents_screen_model.dart';
import '../repositories/driver_documents_repository_interface.dart';

class DriverDocumentsCubit extends ResourceCubit<DriverDocumentsScreenModel> {
  DriverDocumentsCubit(this.repository, this.vehicles);
  final IDriverDocumentsRepository repository;
  final IVehicleRepository vehicles;

  Future<void> load() => fetch(
    () async => DriverDocumentsScreenModel(
      documents: await repository.list(),
      vehicles: await vehicles.list(),
    ),
  );

  Future<bool> upload(DriverDocumentDraft draft) async {
    if (isClosed || state.busy) return false;
    emit(ResourceState(data: state.data, busy: true));
    try {
      var document = await repository.upload(draft);
      if (document.vehicleId == null && draft.vehicleId != null) {
        document = document.copyWith(vehicleId: draft.vehicleId);
      }
      final current = state.data;
      List<DriverDocumentModel> documents;
      try {
        // Register responses can be incomplete on older deployments. Fetch the
        // canonical list while the upload is still busy, instead of calling
        // [load], which deliberately ignores busy refreshes.
        final rawRefreshed = await repository.list();
        final refreshed = rawRefreshed.map((item) {
          if (item.id == document.id &&
              item.vehicleId == null &&
              draft.vehicleId != null) {
            return item.copyWith(vehicleId: draft.vehicleId);
          }
          return item;
        }).toList();
        // A just-committed row can occasionally be absent from a follow-up
        // RPC response for a moment. Do not make a successful upload vanish
        // from the truck screen in that case.
        documents = refreshed.any((item) => item.id == document.id)
            ? refreshed
            : [document, ...refreshed];
      } catch (_) {
        documents = [
          document,
          ...?current?.documents.where((item) => item.id != document.id),
        ];
      }
      final next = DriverDocumentsScreenModel(
        documents: documents,
        vehicles: current?.vehicles ?? await vehicles.list(),
      );
      debugPrint('[DRIVER_DOC_CUBIT] Successfully registered document. Emitting state with ${next.documents.length} documents.');
      if (!isClosed) {
        emit(ResourceState(data: next, notice: 'Document added.'));
      }
      return true;
    } catch (error, stack) {
      debugPrint('[DRIVER_DOC_CUBIT_ERROR] Upload failed: $error');
      debugPrint('[DRIVER_DOC_CUBIT_ERROR] Stack: $stack');
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

  Future<Uri?> viewUrl(DriverDocumentModel document) async {
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
