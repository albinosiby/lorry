import 'package:equatable/equatable.dart';

class NotificationModel extends Equatable {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.bookingId,
    this.loadId,
    this.readAt,
  });
  final String id, title, body;
  final String? bookingId, loadId;
  final DateTime createdAt;
  final DateTime? readAt;
  factory NotificationModel.fromJson(Map<String, dynamic> j) =>
      NotificationModel(
        id: j['id'],
        title: j['title'],
        body: j['body'],
        createdAt: DateTime.parse(j['created_at']),
        bookingId: j['booking_id'],
        loadId: j['load_id'],
        readAt: DateTime.tryParse(j['read_at'] ?? ''),
      );
  @override
  List<Object?> get props => [id, readAt];
}
