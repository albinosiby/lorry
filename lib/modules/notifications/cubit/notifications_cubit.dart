import 'package:lorry_link/core/state/resource_cubit.dart';
import '../models/notifications_screen_model.dart';
import '../repositories/notification_repository_interface.dart';

class NotificationsCubit extends ResourceCubit<NotificationsScreenModel> {
  NotificationsCubit(this.repository);
  final INotificationRepository repository;
  Future<void> load() => fetch(() async {
    final rows = await repository.list();
    return NotificationsScreenModel(rows, rows.length == 20);
  });
  Future<void> more() async {
    final prev = state.data;
    if (prev == null || !prev.hasMore || state.loading) return;
    await fetch(() async {
      final rows = await repository.list(offset: prev.items.length);
      return NotificationsScreenModel([
        ...prev.items,
        ...rows,
      ], rows.length == 20);
    });
  }

  Future<bool> read([String? id]) => act(() => repository.markRead(id));
}
