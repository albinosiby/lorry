import 'package:flutter/material.dart';
import '../widgets/trip_directions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import 'package:lorry_link/design_system/design_system.dart';

import '../../auth/cubit/session_cubit.dart';
import '../../loads/models/load_model.dart';
import '../cubit/booking_details_cubit.dart';
import '../models/booking_model.dart';
import '../models/booking_screen_models.dart';
import '../widgets/truck_picker.dart';
import '../widgets/payment_collection_sheet.dart';

class BookingDetailsScreen extends StatelessWidget {
  const BookingDetailsScreen({super.key, required this.id});

  final String id;

  Future<void> change(
    BuildContext context,
    String status,
    String title,
    String message,
  ) async {
    if (status == 'item_collected') {
      if (!await ensureBookingTruck(context, id) || !context.mounted) return;
      final cubit = context.read<BookingDetailsCubit>();
      final location = await cubit.requestLocationForTrip();
      if (location == null || !context.mounted) return;
      if (!await confirmAction(context, title, message)) return;
      if (await cubit.collectItems(id, location)) await cubit.load(id);
      return;
    }
    if (!await confirmAction(context, title, message)) return;
    if (!context.mounted) return;
    final cubit = context.read<BookingDetailsCubit>();
    if (await cubit.transition(id, status)) await cubit.load(id);
  }

  Future<void> startTrip(BuildContext context) async {
    if (!await ensureBookingTruck(context, id) || !context.mounted) return;
    final cubit = context.read<BookingDetailsCubit>();
    final location = await cubit.requestLocationForTrip();
    if (location == null || !context.mounted) return;
    if (!await confirmAction(
      context,
      'Start trip and share location?',
      'Your GPS location is ready. Starting the trip will share the first truck position with your customer.',
      confirm: 'Start trip',
    )) {
      return;
    }
    if (!context.mounted) return;
    if (!await cubit.startTripWithLocation(id, location) || !context.mounted) {
      return;
    }
    await cubit.load(id);
    if (context.mounted) await context.push('/tracking/$id');
  }

  Future<void> reportDelivery(
    BuildContext context,
    BookingModel booking,
  ) async {
    if (!await confirmAction(
          context,
          'Report delivery?',
          'Confirm all goods have been unloaded. The customer will be asked to confirm receipt. Record any payment separately.',
        ) ||
        !context.mounted) {
      return;
    }
    final cubit = context.read<BookingDetailsCubit>();
    if (await cubit.reportDelivery(id) && context.mounted) {
      await cubit.load(id);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Booking details')),
    body: PageBody(
      narrow: true,
      onRefresh: () => context.read<BookingDetailsCubit>().load(id),
      child: BlocConsumer<BookingDetailsCubit, ResourceState<BookingDetailsModel>>(
        listener: (ctx, state) {
          if (state.error != null) showNotice(ctx, state.error!);
          if (state.notice != null) showNotice(ctx, state.notice!);
        },
        builder: (context, state) => ResourceView<BookingDetailsModel>(
          state: state,
          retry: () => context.read<BookingDetailsCubit>().load(id),
          builder: (model) {
            final booking = model.booking;
            final profile = context.read<SessionCubit>().state.profile;
            if (profile == null) {
              return const AppEmptyState(
                'Preparing your booking',
                'Your account details are still loading. Pull down to try again.',
                icon: Icons.person_outline,
              );
            }
            return _BookingContent(
              booking: booking,
              isCustomer: profile.id == booking.load.shipperId,
              busy: state.busy,
              onChange: (status, title, message) =>
                  change(context, status, title, message),
              onStartTrip: () => startTrip(context),
              onReportDelivery: () => reportDelivery(context, booking),
              onTrack: () => context.push('/tracking/$id'),
              onCall: booking.otherPhone.isEmpty
                  ? null
                  : () => context.read<BookingDetailsCubit>().callContact(
                      booking.otherPhone,
                    ),
              onAcceptInvitation: () async {
                if (!await confirmAction(
                  context,
                  'Accept this invitation?',
                  'You will be assigned to this customer load and can start the trip when ready.',
                )) {
                  return;
                }
                if (!context.mounted) return;
                final cubit = context.read<BookingDetailsCubit>();
                if (await cubit.acceptCustomerInvitation(id)) {
                  await cubit.load(id);
                }
              },
              onCancel: () async {
                final reason = await cancellationReason(context);
                if (reason == null || !context.mounted) return;
                final cubit = context.read<BookingDetailsCubit>();
                if (await cubit.transition(id, 'cancelled', reason: reason)) {
                  await cubit.load(id);
                }
              },
              onReRequest: () async {
                if (!await confirmAction(
                  context,
                  'Request this load again?',
                  'Resubmit your booking request for ${booking.load.pickupLabel} to ${booking.load.destinationLabel}. The customer will review your request.',
                  confirm: 'Send request',
                )) {
                  return;
                }
                if (!context.mounted) return;
                final cubit = context.read<BookingDetailsCubit>();
                final trucks = await cubit.matchingTrucks(booking.load);
                if (!context.mounted) return;
                final truck = await chooseBookingTruck(context, trucks);
                if (truck == null) return;
                if (await cubit.reRequest(
                  booking.load.id,
                  vehicleId: truck.id,
                )) {
                  await cubit.load(id);
                }
              },
            );
          },
        ),
      ),
    ),
  );
}

class _BookingContent extends StatelessWidget {
  const _BookingContent({
    required this.booking,
    required this.isCustomer,
    required this.busy,
    required this.onChange,
    required this.onStartTrip,
    required this.onReportDelivery,
    required this.onTrack,
    required this.onCall,
    required this.onAcceptInvitation,
    required this.onCancel,
    required this.onReRequest,
  });

  final BookingModel booking;
  final bool isCustomer, busy;
  final void Function(String status, String title, String message) onChange;
  final VoidCallback onStartTrip,
      onReportDelivery,
      onTrack,
      onAcceptInvitation,
      onCancel,
      onReRequest;
  final VoidCallback? onCall;

  LoadModel get load => booking.load;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageHeading(
        'BOOKING ${booking.id.substring(0, booking.id.length.clamp(0, 8)).toUpperCase()}',
        _title,
        _subtitle,
      ),
      const SizedBox(height: 16),
      if (booking.itemsCollected)
        const ListTile(
          leading: Icon(Icons.inventory_2_outlined),
          title: Text('Item collected'),
        ),
      _StatusHero(booking: booking, isCustomer: isCustomer),
      const SizedBox(height: 16),
      _NextStepCard(
        booking: booking,
        isCustomer: isCustomer,
        busy: busy,
        onChange: onChange,
        onStartTrip: onStartTrip,
        onReportDelivery: onReportDelivery,
        onTrack: onTrack,
        onAcceptInvitation: onAcceptInvitation,
        onCancel: onCancel,
        onReRequest: onReRequest,
      ),
      const SizedBox(height: 12),
      _WorkflowSummary(booking: booking, isCustomer: isCustomer, busy: busy),
      const SizedBox(height: 16),
      _SectionCard(
        title: 'Journey',
        icon: Icons.route_outlined,
        child: Column(
          children: [
            _JourneyPoint(
              label: 'PICKUP',
              place: load.pickupLabel,
              icon: Icons.trip_origin,
              color: AppTheme.green,
            ),
            for (var index = 0; index < load.unloadStops.length; index++) ...[
              _JourneyLine(color: Theme.of(context).colorScheme.outlineVariant),
              _JourneyPoint(
                label: 'UNLOAD STOP ${index + 1}',
                place: placeLabel(load.unloadStops[index].location),
                icon: Icons.inventory_2_outlined,
                color: Theme.of(context).colorScheme.tertiary,
                detail: load.unloadStops[index].unloadTonnes == null
                    ? null
                    : '${_tonnes(load.unloadStops[index].unloadTonnes!)} to unload',
              ),
            ],
            _JourneyLine(color: Theme.of(context).colorScheme.outlineVariant),
            _JourneyPoint(
              label: 'FINAL DROP',
              place: load.destinationLabel,
              icon: Icons.location_on_outlined,
              color: AppTheme.orange,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _SectionCard(
        title: 'Load requirements',
        icon: Icons.inventory_2_outlined,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DetailTile(
                  width: tileWidth,
                  icon: Icons.inventory_2_outlined,
                  label: 'CARGO',
                  value: load.cargo,
                ),
                _DetailTile(
                  width: tileWidth,
                  icon: Icons.scale_outlined,
                  label: 'WEIGHT',
                  value: load.weightLabel,
                ),
                _DetailTile(
                  width: tileWidth,
                  icon: Icons.local_shipping_outlined,
                  label: 'VEHICLE',
                  value: load.vehicle,
                ),
                _DetailTile(
                  width: tileWidth,
                  icon: Icons.straighten_outlined,
                  label: 'LENGTH',
                  value: load.vehicleLengthLabel,
                ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      _SectionCard(
        title: 'Pickup & payment',
        icon: Icons.payments_outlined,
        child: Column(
          children: [
            InfoRow(
              Icons.schedule_outlined,
              'Pickup',
              load.pickupScheduleLabel,
            ),
            InfoRow(Icons.currency_rupee_outlined, 'Freight', load.priceLabel),
            if (load.specialNote.trim().isNotEmpty)
              InfoRow(Icons.notes_outlined, 'Special note', load.specialNote),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _SectionCard(
        title: isCustomer ? 'Assigned driver' : 'Customer',
        icon: Icons.person_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    isCustomer
                        ? Icons.local_shipping_outlined
                        : Icons.person_outline,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    booking.otherName.isEmpty
                        ? 'Contact details pending'
                        : booking.otherName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onCall != null)
                  IconButton.filledTonal(
                    tooltip: 'Call contact',
                    onPressed: busy ? null : onCall,
                    icon: const Icon(Icons.call_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              booking.otherPhone.isEmpty
                  ? 'This customer has not added a contact number yet.'
                  : booking.otherPhone,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (booking.otherPhone.isNotEmpty) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: busy ? null : onCall,
                icon: const Icon(Icons.call_outlined),
                label: const Text('Call contact'),
              ),
            ],
          ],
        ),
      ),
      if (booking.reason?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 16),
        _UpdateNote(note: booking.reason!),
      ],
      const SizedBox(height: 24),
      Text('Booking timeline', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      _Timeline(events: booking.events),
      const SizedBox(height: 16),
      Text(
        booking.status == 'in_transit'
            ? 'Live location is shared while the driver keeps location access enabled.'
            : 'Booking updates are shared with both parties here.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    ],
  );

  String get _title => switch (booking.status) {
    'requested' when isCustomer => 'Review driver request',
    'requested' when booking.source == 'customer_invitation' =>
      'Customer invitation',
    'requested' => 'Request sent',
    'accepted' when isCustomer => 'Driver is ready',
    'accepted' => 'Ready to start the trip',
    'in_transit' when booking.deliveryReportedAt != null => 'Delivery reported',
    'in_transit' => 'Shipment is on the road',
    'completed' => 'Booking completed',
    'cancelled' => 'Booking cancelled',
    'declined' => 'Request declined',
    _ => 'Booking update',
  };

  String get _subtitle => switch (booking.status) {
    'requested' when isCustomer => 'Choose whether to assign this load.',
    'requested' => 'We will update you when the customer responds.',
    'accepted' when isCustomer =>
      'The driver can now start and share live location.',
    'accepted' => 'Turn on location when you start the journey.',
    'in_transit' when booking.deliveryReportedAt != null =>
      'Waiting for customer delivery confirmation.',
    'in_transit' => 'Follow the trip progress and delivery updates.',
    'completed' => 'This shipment has been successfully closed.',
    'cancelled' => 'This booking is no longer active.',
    'declined' => 'This request was not assigned.',
    _ => 'Review the latest booking details.',
  };
}

class _WorkflowSummary extends StatelessWidget {
  const _WorkflowSummary({
    required this.booking,
    required this.isCustomer,
    required this.busy,
  });
  final BookingModel booking;
  final bool isCustomer, busy;
  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'Truck, delivery & payment',
    icon: Icons.fact_check_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Stage: ${statusLabel(booking.displayStatus)}'),
        Text(
          booking.vehicle == null
              ? (booking.status == 'requested' || booking.status == 'accepted'
                    ? 'Truck selection required'
                    : 'Truck details not recorded for this booking')
              : '${booking.vehicle!.registrationNumber} · ${booking.vehicle!.vehicleType} · ${booking.vehicle!.capacityTonnes} t',
        ),
        if (!isCustomer &&
            booking.vehicleId == null &&
            (booking.status == 'requested' || booking.status == 'accepted'))
          OutlinedButton(
            onPressed: busy
                ? null
                : () => ensureBookingTruck(context, booking.id),
            child: const Text('Select assigned truck'),
          ),
        const Divider(),
        Text('Payment: ${booking.paymentLabel}'),
        Text(
          'Agreed freight: ${booking.freight == null ? 'Not set' : '₹${booking.freight!.toStringAsFixed(2)}'}',
        ),
        Text('Collected: ₹${booking.amountCollected.toStringAsFixed(2)}'),
        if (booking.balance != null)
          Text('Balance: ₹${booking.balance!.toStringAsFixed(2)}'),
        if (!isCustomer && booking.canRecordPayment)
          FilledButton.icon(
            onPressed: busy
                ? null
                : () => collectBookingPayment(context, booking),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Record payment collected'),
          ),
        if (booking.deliveryIssue != null)
          Text(
            'Delivery issue: ${booking.deliveryIssue}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (isCustomer && booking.deliveryPendingConfirmation)
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    final reason = await cancellationReason(
                      context,
                      title: 'Report delivery issue',
                      fieldLabel: 'Describe the issue',
                      confirmLabel: 'Report issue',
                    );
                    if (reason != null && context.mounted) {
                      await context.read<BookingDetailsCubit>().reportIssue(
                        booking.id,
                        reason,
                      );
                    }
                  },
            child: const Text('Report delivery issue'),
          ),
        if (!isCustomer &&
            booking.isLiveTrip &&
            booking.load.unloadStops.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'At each stop, mark Unloaded here. Reopen directions to skip completed stops.',
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : () => openTripDirections(context, booking),
            icon: const Icon(Icons.directions_outlined),
            label: const Text('Navigate delivery route'),
          ),
        ],
        for (var i = 0; i < booking.load.unloadStops.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              booking.unloadedStopIndices.contains(i)
                  ? Icons.check_circle_outline
                  : Icons.inventory_2_outlined,
            ),
            title: Text(
              'Stop ${i + 1}: ${booking.load.unloadStops[i].location}',
            ),
            subtitle: Text(
              booking.unloadedStopIndices.contains(i)
                  ? 'Unloaded'
                  : 'Unloading pending',
            ),
            trailing:
                !isCustomer &&
                    booking.isLiveTrip &&
                    !booking.unloadedStopIndices.contains(i)
                ? TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (await confirmAction(
                                  context,
                                  'Confirm unloading?',
                                  'Confirm goods for this stop have been unloaded.',
                                ) &&
                                context.mounted) {
                              await context
                                  .read<BookingDetailsCubit>()
                                  .markStopUnloaded(booking.id, i);
                            }
                          },
                    child: const Text('Unloaded'),
                  )
                : null,
          ),
      ],
    ),
  );
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.booking, required this.isCustomer});
  final BookingModel booking;
  final bool isCustomer;

  @override
  Widget build(BuildContext context) {
    final status = statusLabel(booking.displayStatus);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SHIPMENT STATUS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: .78),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: StatusBadge(status),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            booking.load.pickupLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 18,
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withValues(alpha: .72),
                ),
                const SizedBox(width: 8),
                Text(
                  '${booking.load.weightLabel} · ${booking.load.vehicle}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: .78),
                  ),
                ),
              ],
            ),
          ),
          Text(
            booking.load.destinationLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Divider(
            color: Theme.of(
              context,
            ).colorScheme.onPrimary.withValues(alpha: .2),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.currency_rupee_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  booking.load.priceLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                isCustomer ? 'Customer load' : 'Driver booking',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withValues(alpha: .78),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _JourneyPoint extends StatelessWidget {
  const _JourneyPoint({
    required this.label,
    required this.place,
    required this.icon,
    required this.color,
    this.detail,
  });
  final String label, place;
  final IconData icon;
  final Color color;
  final String? detail;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 19),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: .9,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(place, style: Theme.of(context).textTheme.titleSmall),
            if (detail != null)
              Text(
                detail!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _JourneyLine extends StatelessWidget {
  const _JourneyLine({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 9, top: 4, bottom: 4),
    child: Container(width: 1.5, height: 18, color: color),
  );
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });
  final double width;
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: .8,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _UpdateNote extends StatelessWidget {
  const _UpdateNote({required this.note});
  final String note;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            note,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ],
    ),
  );
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({
    required this.booking,
    required this.isCustomer,
    required this.busy,
    required this.onChange,
    required this.onStartTrip,
    required this.onReportDelivery,
    required this.onTrack,
    required this.onAcceptInvitation,
    required this.onCancel,
    required this.onReRequest,
  });
  final BookingModel booking;
  final bool isCustomer, busy;
  final void Function(String status, String title, String message) onChange;
  final VoidCallback onStartTrip,
      onReportDelivery,
      onTrack,
      onAcceptInvitation,
      onCancel,
      onReRequest;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Next step',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          if (busy) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 16),
          ..._actions(context),
          if (booking.canCancel &&
              (!isCustomer || booking.status == 'accepted')) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: busy ? null : onCancel,
              child: Text(
                booking.status == 'requested'
                    ? 'Withdraw request'
                    : 'Cancel booking',
              ),
            ),
          ],
        ],
      ),
    ),
  );

  IconData get _icon => switch (booking.status) {
    'requested' => Icons.pending_actions_outlined,
    'accepted' => Icons.local_shipping_outlined,
    'in_transit' => Icons.location_searching_outlined,
    'completed' => Icons.verified_outlined,
    'cancelled' || 'declined' =>
      booking.load.status == 'open' && !isCustomer
          ? Icons.replay_outlined
          : Icons.cancel_outlined,
    _ => Icons.info_outline,
  };

  String get _message {
    if (isCustomer && booking.status == 'requested') {
      return 'Review this request and choose a driver for your shipment.';
    }
    if (!isCustomer &&
        booking.status == 'requested' &&
        booking.source == 'customer_invitation') {
      return 'Accept this invitation to take the customer’s load.';
    }
    if (booking.status == 'accepted' && !isCustomer) {
      if (booking.canCollect) {
        return 'Go to the pickup point, then confirm Item collected before starting the trip.';
      }
      return 'When the truck is ready, start the trip and share your live location.';
    }
    if (booking.status == 'accepted') {
      return 'The driver will start the trip when the truck leaves pickup.';
    }
    if (booking.status == 'in_transit' && booking.deliveryReportedAt == null) {
      return isCustomer
          ? 'The truck is on the road. You can follow its latest shared location.'
          : 'Keep location sharing active and report delivery once the goods arrive.';
    }
    if (booking.status == 'in_transit') {
      return isCustomer
          ? 'The driver has reported delivery. Confirm after receiving the goods.'
          : 'Delivery is reported. Waiting for the customer to confirm receipt.';
    }
    if (!isCustomer &&
        (booking.status == 'cancelled' || booking.status == 'declined')) {
      return booking.load.status == 'open'
          ? 'You previously cancelled or withdrew this request. The load is still open if you wish to request it again.'
          : 'This request was cancelled and the load is no longer open.';
    }
    return booking.status == 'completed'
        ? 'No further action is needed for this booking.'
        : 'No further action is available for this booking.';
  }

  List<Widget> _actions(BuildContext context) {
    if (isCustomer && booking.status == 'accepted') {
      return [
        OutlinedButton.icon(
          onPressed: onTrack,
          icon: const Icon(Icons.location_searching_outlined),
          label: const Text('Track truck location'),
        ),
      ];
    }
    if (isCustomer && booking.status == 'requested') {
      return [
        AppButton(
          label: 'Accept booking',
          icon: Icons.check,
          busy: busy,
          onPressed: () => onChange(
            'accepted',
            'Accept this driver?',
            'This assigns the load to ${booking.driverName}. Other pending requests will be declined.',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => onChange(
                  'declined',
                  'Decline request?',
                  'The driver will be notified of your decision.',
                ),
          child: const Text('Decline request'),
        ),
      ];
    }
    if (!isCustomer &&
        booking.status == 'requested' &&
        booking.source == 'customer_invitation') {
      return [
        AppButton(
          label: 'Accept truck invitation',
          icon: Icons.check,
          busy: busy,
          onPressed: busy ? null : onAcceptInvitation,
        ),
      ];
    }
    if (!isCustomer && booking.canCollect) {
      return [
        AppButton(
          label: 'Item collected',
          busy: busy,
          onPressed: () => onChange(
            'item_collected',
            'Items collected?',
            'Confirm the goods have been picked up. The customer will be notified.',
          ),
        ),
      ];
    }
    if (!isCustomer && booking.canStart) {
      return [
        AppButton(
          label: 'Start trip',
          icon: Icons.local_shipping_outlined,
          busy: busy,
          onPressed: onStartTrip,
        ),
      ];
    }
    if (booking.status == 'in_transit') {
      return [
        if (booking.isLiveTrip)
          OutlinedButton.icon(
            onPressed: onTrack,
            icon: const Icon(Icons.location_searching_outlined),
            label: Text(
              isCustomer ? 'Track truck location' : 'Share trip location',
            ),
          ),
        if (!isCustomer && booking.canReport) ...[
          const SizedBox(height: 10),
          AppButton(
            label: 'Report delivery',
            icon: Icons.task_alt,
            busy: busy,
            onPressed: busy ? null : onReportDelivery,
          ),
        ],
        if (isCustomer && booking.canComplete) ...[
          const SizedBox(height: 10),
          AppButton(
            label: 'Confirm delivery',
            icon: Icons.verified_outlined,
            busy: busy,
            onPressed: () => onChange(
              'completed',
              'Confirm delivery?',
              'Confirm you received the shipment. This completes the booking.',
            ),
          ),
        ],
      ];
    }
    if (!isCustomer &&
        (booking.status == 'cancelled' || booking.status == 'declined') &&
        booking.load.status == 'open') {
      return [
        AppButton(
          label: 'Request again',
          icon: Icons.replay_outlined,
          busy: busy,
          onPressed: onReRequest,
        ),
      ];
    }
    return const [];
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});
  final List<BookingEvent> events;
  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Text('No booking updates have been recorded yet.');
    }
    return Column(
      children: List.generate(events.length, (index) {
        final event = events[index];
        final last = index == events.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 34,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Icon(
                        _eventIcon(event.status),
                        size: 16,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    if (!last)
                      Expanded(
                        child: Container(
                          width: 1.5,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: last ? 0 : 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel(event.status),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat(
                          'd MMM yyyy, h:mm a',
                        ).format(event.at.toLocal()),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (event.note.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.note,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  IconData _eventIcon(String status) => switch (status) {
    'requested' => Icons.send_outlined,
    'accepted' => Icons.check_circle_outline,
    'in_transit' => Icons.local_shipping_outlined,
    'delivery_reported' => Icons.task_alt,
    'completed' => Icons.verified_outlined,
    'cancelled' || 'declined' => Icons.cancel_outlined,
    _ => Icons.info_outline,
  };
}

String _tonnes(double value) =>
    '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)} t';
