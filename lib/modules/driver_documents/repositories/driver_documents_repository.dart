import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/services/supabase_service.dart';
import '../models/driver_document_model.dart';
import 'driver_documents_repository_interface.dart';

class DriverDocumentsRepository implements IDriverDocumentsRepository {
  DriverDocumentsRepository(this.service);
  final SupabaseService service;
  static const _maxDocumentBytes = 8 * 1024 * 1024;

  @override
  Future<List<DriverDocumentModel>> list() async =>
      (await service.callNext('documents.list') as List)
          .map(
            (row) =>
                DriverDocumentModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();

  @override
  Future<DriverDocumentModel> upload(DriverDocumentDraft draft) async {
    final userId = service.client.auth.currentUser?.id;
    debugPrint('[TRUCK_DOC_UPLOAD] ─── Upload Process Started ───');
    debugPrint('[TRUCK_DOC_UPLOAD] Document Type: ${draft.type.databaseValue}');
    debugPrint('[TRUCK_DOC_UPLOAD] Filename: ${draft.filename}, MIME: ${draft.contentType}, Bytes: ${draft.bytes.lengthInBytes}');
    debugPrint('[TRUCK_DOC_UPLOAD] Current User ID: $userId');
    debugPrint('[TRUCK_DOC_UPLOAD] Vehicle ID: ${draft.vehicleId}');

    if (userId == null) {
      debugPrint('[TRUCK_DOC_UPLOAD_ERROR] User not authenticated!');
      throw StateError('Please sign in to upload a document.');
    }
    if (draft.bytes.isEmpty) {
      debugPrint('[TRUCK_DOC_UPLOAD_ERROR] Picked bytes are empty.');
      throw StateError('The selected image is empty. Please capture it again.');
    }
    if (draft.bytes.lengthInBytes > _maxDocumentBytes) {
      debugPrint('[TRUCK_DOC_UPLOAD_ERROR] File size exceeds 8MB limit.');
      throw StateError(
        'This document is larger than 8 MB. Please use a clearer, smaller image.',
      );
    }
    final extension = switch (draft.contentType) {
      'application/pdf' => 'pdf',
      'image/png' => 'png',
      _ => 'jpg',
    };
    final path =
        '$userId/${draft.type.databaseValue}_${DateTime.now().microsecondsSinceEpoch}.$extension';
    debugPrint('[TRUCK_DOC_UPLOAD] Target Supabase Storage Path: $path');

    try {
      debugPrint('[TRUCK_DOC_UPLOAD] Uploading binary to bucket "driver-documents"...');
      await service.guard(
        () => service.client.storage
            .from('driver-documents')
            .uploadBinary(
              path,
              draft.bytes,
              fileOptions: FileOptions(
                contentType: draft.contentType,
                upsert: true,
              ),
            ),
      );
      debugPrint('[TRUCK_DOC_UPLOAD] Supabase Storage Binary Upload: SUCCESS ✅');
    } catch (e, stack) {
      debugPrint('[TRUCK_DOC_UPLOAD_FAIL] Storage Binary Upload FAILED: $e');
      debugPrint('[TRUCK_DOC_UPLOAD_FAIL] Stack: $stack');
      rethrow;
    }

    try {
      debugPrint('[TRUCK_DOC_UPLOAD] Calling RPC "documents.register"...');
      final result = await service.callNext('documents.register', {
        'document_type': draft.type.databaseValue,
        'storage_path': path,
        'vehicle_id': draft.vehicleId,
        'expires_on': draft.expiresOn?.toIso8601String().split('T').first,
      });
      debugPrint('[TRUCK_DOC_UPLOAD] RPC "documents.register": SUCCESS ✅ Result: $result');
      return DriverDocumentModel.fromJson(Map<String, dynamic>.from(result));
    } catch (e, stack) {
      debugPrint('[TRUCK_DOC_UPLOAD_FAIL] RPC "documents.register" FAILED: $e');
      debugPrint('[TRUCK_DOC_UPLOAD_FAIL] Stack: $stack');
      rethrow;
    }
  }

  @override
  Future<Uri?> viewUrl(DriverDocumentModel document) async {
    final path = document.storagePath;
    if (path == null || path.isEmpty) return null;
    final url = await service.guard(
      () => service.client.storage
          .from('driver-documents')
          .createSignedUrl(path, 60),
    );
    return Uri.tryParse(url);
  }
}
