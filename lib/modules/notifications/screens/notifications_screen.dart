import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import '../cubit/notifications_cubit.dart';
import '../models/notifications_screen_model.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Updates')),
    body: PageBody(
      narrow: true,
      onRefresh: () => context.read<NotificationsCubit>().load(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeading(
            'Stay in the loop',
            'Your updates',
            'Booking decisions and shipment progress, all together.',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                final c = context.read<NotificationsCubit>();
                if (await c.read()) c.load();
              },
              child: const Text('Mark all as read'),
            ),
          ),
          BlocConsumer<
            NotificationsCubit,
            ResourceState<NotificationsScreenModel>
          >(
            listener: (context, state) {
              if (state.error != null) showNotice(context, state.error!);
            },
            builder: (context, state) => ResourceView<NotificationsScreenModel>(
              state: state,
              retry: () => context.read<NotificationsCubit>().load(),
              builder: (model) => Column(
                children: [
                  if (model.items.isEmpty)
                    const AppEmptyState(
                      'You’re all caught up',
                      'New requests, decisions, and trip updates will appear here.',
                      icon: Icons.notifications_none,
                    ),
                  ...model.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Badge(
                            isLabelVisible: item.readAt == null,
                            child: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              child: const Icon(Icons.notifications_none),
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: item.readAt == null
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            '${item.body}\n${DateFormat('d MMM, h:mm a').format(item.createdAt.toLocal())}',
                          ),
                          isThreeLine: true,
                          onTap: () async {
                            final c = context.read<NotificationsCubit>();
                            await c.read(item.id);
                            if (context.mounted) {
                              if (item.bookingId != null) {
                                await context.push(
                                  '/bookings/${item.bookingId}',
                                );
                              } else if (item.loadId != null) {
                                await context.push('/loads/${item.loadId}');
                              }
                            }
                            if (!c.isClosed) c.load();
                          },
                        ),
                      ),
                    ),
                  ),
                  if (model.hasMore)
                    OutlinedButton(
                      onPressed: state.loading
                          ? null
                          : () => context.read<NotificationsCubit>().more(),
                      child: const Text('Load more'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
