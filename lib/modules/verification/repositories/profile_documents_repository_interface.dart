import '../models/profile_document_model.dart';

abstract interface class IProfileDocumentsRepository {
  Future<List<ProfileDocumentModel>> list();
  Future<ProfileDocumentModel> upload(ProfileDocumentDraft draft);
  Future<void> remove(ProfileDocumentModel document);
  Future<Uri?> viewUrl(ProfileDocumentModel document);
}
