import '../models/driver_document_model.dart';

abstract interface class IDriverDocumentsRepository {
  Future<List<DriverDocumentModel>> list();
  Future<DriverDocumentModel> upload(DriverDocumentDraft draft);
  Future<Uri?> viewUrl(DriverDocumentModel document);
}
