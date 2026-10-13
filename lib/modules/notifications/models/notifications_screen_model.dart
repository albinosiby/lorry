import 'notification_model.dart';

class NotificationsScreenModel {
  const NotificationsScreenModel(this.items, this.hasMore);
  final List<NotificationModel> items;
  final bool hasMore;
}
