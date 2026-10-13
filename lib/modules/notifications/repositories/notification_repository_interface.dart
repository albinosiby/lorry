import '../models/notification_model.dart';

abstract interface class INotificationRepository {
  Future<List<NotificationModel>> list({int offset = 0});
  Future<void> markRead([String? id]);
}
