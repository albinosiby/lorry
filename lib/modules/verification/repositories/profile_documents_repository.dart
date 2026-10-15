import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/services/supabase_service.dart';
import '../models/profile_document_model.dart';
import 'profile_documents_repository_interface.dart';

class ProfileDocumentsRepository implements IProfileDocumentsRepository {
  ProfileDocumentsRepository(this.service);
  final SupabaseService service;

  @override
  Future<List<ProfileDocumentModel>> list() async =>
      (await service.callCustomer('profile.documents.list') as List)
          .map(
            (row) =>
                ProfileDocumentModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();

  @override
  Future<ProfileDocumentModel> upload(ProfileDocumentDraft draft) async {
    final userId = service.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Please sign in to upload a document.');
    }
    final extension = draft.filename.split('.').last.toLowerCase();
    final path =
        '$userId/${draft.type}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final previous = await list();
    await service.guard(
      () => service.client.storage
          .from('profile-documents')
          .uploadBinary(
            path,
            draft.bytes,
            fileOptions: FileOptions(contentType: draft.contentType),
          ),
    );
    final result = await service.callCustomer('profile.documents.register', {
      'document_type': draft.type,
      'storage_path': path,
    });
    final oldPaths = previous
        .map((document) => document.storagePath)
        .whereType<String>()
        .where((oldPath) => oldPath != path)
        .toList();
    if (oldPaths.isNotEmpty) {
      await service.guard(
        () => service.client.storage.from('profile-documents').remove(oldPaths),
      );
    }
    return ProfileDocumentModel.fromJson(Map<String, dynamic>.from(result));
  }

  @override
  Future<void> remove(ProfileDocumentModel document) async {
    await service.callCustomer('profile.documents.remove', {'id': document.id});
    final path = document.storagePath;
    if (path != null && path.isNotEmpty) {
      await service.guard(
        () => service.client.storage.from('profile-documents').remove([path]),
      );
    }
  }

  @override
  Future<Uri?> viewUrl(ProfileDocumentModel document) async {
    final path = document.storagePath;
    if (path == null || path.isEmpty) return null;

    final url = await service.guard(
      () => service.client.storage
          .from('profile-documents')
          .createSignedUrl(path, 60),
    );
    return Uri.tryParse(url);
  }
}
