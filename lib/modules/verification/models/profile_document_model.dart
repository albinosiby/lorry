import 'dart:typed_data';
import 'package:equatable/equatable.dart';

class ProfileDocumentModel extends Equatable {
  const ProfileDocumentModel({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    this.storagePath,
    this.rejectionReason,
  });

  final String id, type, status;
  final DateTime createdAt;
  final String? storagePath;
  final String? rejectionReason;

  factory ProfileDocumentModel.fromJson(Map<String, dynamic> json) =>
      ProfileDocumentModel(
        id: json['id'].toString(),
        type: json['document_type']?.toString() ?? 'identity',
        status: json['status']?.toString() ?? 'submitted',
        createdAt: DateTime.parse(json['created_at'].toString()),
        storagePath: json['storage_path']?.toString(),
        rejectionReason: json['rejection_reason']?.toString(),
      );

  @override
  List<Object?> get props => [
    id,
    type,
    status,
    createdAt,
    storagePath,
    rejectionReason,
  ];
}

class ProfileDocumentDraft {
  const ProfileDocumentDraft({
    required this.bytes,
    required this.filename,
    required this.contentType,
    required this.type,
  });

  final Uint8List bytes;
  final String filename, contentType, type;
}
