import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../auth/cubit/session_cubit.dart';
import '../../loads/models/load_model.dart';
import '../../loads/widgets/load_card.dart';
import '../cubit/booking_details_cubit.dart';
import '../models/booking_screen_models.dart';

class BookingDetailsScreen extends StatelessWidget {
  const BookingDetailsScreen({super.key, required this.id});
  final String id;
  Future<void> change(
    BuildContext context,
    String status,
    String title,
    String message,
  ) async {
    if (!await confirmAction(context, title, message)) return;
    if (!context.mounted) return;
    final c = context.read<BookingDetailsCubit>();
    final ok = await c.transition(id, status);
    if (ok) await c.load(id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Booking details')),
    body: PageBody(
      narrow: true,
      onRefresh: () => context.read<BookingDetailsCubit>().load(id),
      child: BlocConsumer<BookingDetailsCubit, ResourceState<BookingDetailsModel>>(
        listener: (ctx, s) {
          if (s.error != null) showNotice(ctx, s.error!);
          if (s.notice != null) showNotice(ctx, s.notice!);
        },
        builder: (context, state) => ResourceView<BookingDetailsModel>(
          state: state,
          retry: () => context.read<BookingDetailsCubit>().load(id),
          builder: (m) {
            final b = m.booking;
            final shipper =
                context.read<SessionCubit>().state.profile!.id ==
                b.load.shipperId;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'YOUR SHIPMENT',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    StatusBadge(
                      b.deliveryReportedAt != null && b.status == 'in_transit'
                          ? 'Delivery reported'
                          : statusLabel(b.status),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RouteSummary(b.load.pickup, b.load.destination),
                        const Divider(),
                        Text(
                          b.load.priceLabel,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        InfoRow(
                          Icons.inventory_2_outlined,
                          'Cargo',
                          b.load.cargo,
                        ),
                        InfoRow(
                          Icons.local_shipping_outlined,
                          'Vehicle',
                          b.load.vehicle,
                        ),
                        InfoRow(
                          Icons.calendar_today_outlined,
                          'Pickup',
                          b.load.dateLabel,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  shipper ? 'Your transporter' : 'Your shipper',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                InfoRow(Icons.person_outline, 'Name', b.otherName),
                if (b.otherPhone.isNotEmpty)
                  SelectableText(
                    'Phone: ${b.otherPhone}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  )
                else
                  const Text(
                    'Contact details appear after acceptance, when provided.',
                    style: TextStyle(fontSize: 12),
                  ),
                if (b.otherPhone.isNotEmpty)
                  TextButton.icon(
                    onPressed: state.busy
                        ? null
                        : () => context.read<BookingDetailsCubit>().callContact(
                            b.otherPhone,
                          ),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call contact'),
                  ),
                if (b.reason != null)
                  InfoRow(Icons.info_outline, 'Update', b.reason!),
                const SizedBox(height: 24),
                if (state.busy) const LinearProgressIndicator(),
                if (shipper && b.status == 'requested') ...[
                  AppButton(
                    label: 'Accept booking',
                    icon: Icons.check,
                    busy: state.busy,
                    onPressed: () => change(
                      context,
                      'accepted',
                      'Accept this driver?',
                      'This assigns the load to ${b.driverName}. Other pending requests will be declined.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: state.busy
                        ? null
                        : () => change(
                            context,
                            'declined',
                            'Decline request?',
                            'The driver will be notified of your decision.',
                          ),
                    child: const Text('Decline request'),
                  ),
                ],
                if (!shipper && b.canStart)
                  AppButton(
                    label: 'Start trip',
                    icon: Icons.local_shipping_outlined,
                    busy: state.busy,
                    onPressed: () => change(
                      context,
                      'in_transit',
                      'Start this trip?',
                      'Confirm that the goods have been picked up and the shipment is underway.',
                    ),
                  ),
                if (!shipper && b.canReport)
                  AppButton(
                    label: 'Report delivery',
                    icon: Icons.task_alt,
                    busy: state.busy,
                    onPressed: () => change(
                      context,
                      'delivery_reported',
                      'Goods delivered?',
                      'The shipper will be asked to confirm receipt.',
                    ),
                  ),
                if (shipper && b.canComplete)
                  AppButton(
                    label: 'Confirm delivery',
                    icon: Icons.verified_outlined,
                    busy: state.busy,
                    onPressed: () => change(
                      context,
                      'completed',
                      'Confirm delivery?',
                      'Confirm you received the shipment. This completes the booking.',
                    ),
                  ),
                if (!shipper && b.canComplete)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'Delivery reported. Waiting for the shipper to confirm receipt.',
                      ),
                    ),
                  ),
                if (shipper && b.status == 'in_transit' && !b.canComplete)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'Your shipment is on the road. Delivery confirmation becomes available when the driver reports arrival.',
                      ),
                    ),
                  ),
                if (b.canCancel && (!shipper || b.status == 'accepted'))
                  TextButton(
                    onPressed: state.busy
                        ? null
                        : () async {
                            final reason = await cancellationReason(context);
                            if (reason != null && context.mounted) {
                              final c = context.read<BookingDetailsCubit>();
                              if (await c.transition(
                                id,
                                'cancelled',
                                reason: reason,
                              )) {
                                await c.load(id);
                              }
                            }
                          },
                    child: Text(
                      b.status == 'requested'
                          ? 'Withdraw request'
                          : 'Cancel booking',
                    ),
                  ),
                const SizedBox(height: 28),
                Text(
                  'Shipment timeline',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...b.events.map(
                  (event) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 17,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: const Icon(Icons.check, size: 17),
                    ),
                    title: Text(statusLabel(event.status)),
                    subtitle: Text(
                      '${DateFormat('d MMM, h:mm a').format(event.at.toLocal())}${event.note.isEmpty ? '' : '\n${event.note}'}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Status is updated by the shipment parties. This is not GPS tracking.',
                  style: TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
