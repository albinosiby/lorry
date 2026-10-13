import '../../../utils/services/supabase_service.dart';
import '../models/notification_model.dart';
import 'notification_repository_interface.dart';

class NotificationRepository implements INotificationRepository {
  NotificationRepository(this.service);
  final SupabaseService service;
  @override
  Future<List<NotificationModel>> list({int offset = 0}) async =>
      (await service.call('notifications.list', {'offset': offset}) as List)
          .map((j) => NotificationModel.fromJson(j))
          .toList();
  @override
  Future<void> markRead([String? id]) async {
    await service.call('notifications.read', {'id': id});
  }
}
