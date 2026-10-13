import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../auth/cubit/session_cubit.dart';
import '../../profile/models/profile_model.dart';
import '../cubit/load_details_cubit.dart';
import '../models/load_model.dart';
import '../models/load_screen_models.dart';
import '../widgets/load_card.dart';

class LoadDetailsScreen extends StatelessWidget {
  const LoadDetailsScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Load details')),
    body: PageBody(
      narrow: true,
      onRefresh: () => context.read<LoadDetailsCubit>().load(id),
      child: BlocConsumer<LoadDetailsCubit, ResourceState<LoadDetailsModel>>(
        listener: (ctx, s) {
          if (s.error != null) showNotice(ctx, s.error!);
          if (s.notice != null) showNotice(ctx, s.notice!);
        },
        builder: (context, state) => ResourceView<LoadDetailsModel>(
          state: state,
          retry: () => context.read<LoadDetailsCubit>().load(id),
          builder: (m) {
            final l = m.load;
            final profile = context.read<SessionCubit>().state.profile!;
            final owner = profile.id == l.shipperId;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'THE NEXT MILE',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    StatusBadge(statusLabel(l.status)),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RouteSummary(l.pickup, l.destination),
                        const Divider(),
                        Text(
                          l.priceLabel,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const Text(
                          'Expected freight price',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Shipment details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                InfoRow(Icons.inventory_2_outlined, 'Cargo', l.cargo),
                InfoRow(Icons.local_shipping_outlined, 'Vehicle', l.vehicle),
                InfoRow(
                  Icons.calendar_today_outlined,
                  'Pickup date',
                  l.dateLabel,
                ),
                if (m.ownerName.isNotEmpty)
                  InfoRow(Icons.person_outline, 'Posted by', m.ownerName),
                if (m.ownerPhone.isNotEmpty)
                  InfoRow(Icons.phone_outlined, 'Contact phone', m.ownerPhone),
                const SizedBox(height: 24),
                if (m.ownerPhone.isNotEmpty)
                  TextButton.icon(
                    onPressed: state.busy
                        ? null
                        : () => context.read<LoadDetailsCubit>().callContact(
                            m.ownerPhone,
                          ),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call shipper'),
                  ),
                if (owner) ...[
                  AppButton(
                    label: 'View booking requests',
                    icon: Icons.people_outline,
                    onPressed: () async {
                      await context.push('/loads/$id/requests');
                      if (context.mounted) {
                        context.read<LoadDetailsCubit>().load(id);
                      }
                    },
                  ),
                  if (l.bookingId != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context.push('/bookings/${l.bookingId}'),
                      child: const Text('View assigned booking'),
                    ),
                  ],
                  if (l.status == 'open') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await context.push('/loads/$id/edit');
                        if (context.mounted) {
                          context.read<LoadDetailsCubit>().load(id);
                        }
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit listing'),
                    ),
                    TextButton(
                      onPressed: state.busy
                          ? null
                          : () async {
                              if (await confirmAction(
                                    context,
                                    'Cancel this listing?',
                                    'Pending requests will be cancelled and drivers will be notified.',
                                    confirm: 'Cancel listing',
                                  ) &&
                                  context.mounted) {
                                final c = context.read<LoadDetailsCubit>();
                                if (await c.cancel(id)) await c.load(id);
                              }
                            },
                      child: const Text('Cancel listing'),
                    ),
                  ],
                ] else if (profile.role == UserRole.driver) ...[
                  if (l.bookingId != null)
                    AppButton(
                      label: 'View your booking',
                      onPressed: () => context.push('/bookings/${l.bookingId}'),
                    )
                  else
                    AppButton(
                      label: l.status == 'open'
                          ? 'Request booking'
                          : 'Load unavailable',
                      icon: Icons.handshake_outlined,
                      busy: state.busy,
                      onPressed: l.status != 'open'
                          ? null
                          : () async {
                              if (await confirmAction(
                                    context,
                                    'Request this load?',
                                    'Send a booking request for ${l.pickupLabel} to ${l.destinationLabel}. The shipper will review your request.',
                                    confirm: 'Send request',
                                  ) &&
                                  context.mounted) {
                                final c = context.read<LoadDetailsCubit>();
                                if (await c.request(id) && context.mounted) {
                                  await context.push(
                                    '/bookings/${c.requestedBookingId}',
                                  );
                                  if (context.mounted) c.load(id);
                                }
                              }
                            },
                    ),
                  const SizedBox(height: 14),
                  const Text(
                    'Submitting a request does not confirm the booking. Wait for the shipper’s acceptance.',
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );
}
