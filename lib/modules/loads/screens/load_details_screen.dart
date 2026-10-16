import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import 'package:lorry_link/design_system/design_system.dart';

import '../../auth/cubit/session_cubit.dart';
import '../../profile/models/profile_model.dart';
import '../cubit/load_details_cubit.dart';
import '../models/load_model.dart';
import '../models/load_screen_models.dart';
import '../../bookings/widgets/truck_picker.dart';

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
        listener: (ctx, state) {
          if (state.error != null) showNotice(ctx, state.error!);
          if (state.notice != null) showNotice(ctx, state.notice!);
        },
        builder: (context, state) => ResourceView<LoadDetailsModel>(
          state: state,
          retry: () => context.read<LoadDetailsCubit>().load(id),
          builder: (model) {
            final profile = context.read<SessionCubit>().state.profile;
            if (profile == null) {
              return const AppEmptyState(
                'Preparing load details',
                'Your account details are still loading. Pull down to try again.',
                icon: Icons.person_outline,
              );
            }
            return _LoadDetailsContent(
              id: id,
              model: model,
              isOwner: profile.id == model.load.shipperId,
              isDriver: profile.role == UserRole.driver,
              busy: state.busy,
            );
          },
        ),
      ),
    ),
  );
}

class _LoadDetailsContent extends StatelessWidget {
  const _LoadDetailsContent({
    required this.id,
    required this.model,
    required this.isOwner,
    required this.isDriver,
    required this.busy,
  });

  final String id;
  final LoadDetailsModel model;
  final bool isOwner, isDriver, busy;

  LoadModel get load => model.load;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _LoadHero(load: load),
      const SizedBox(height: 14),
      _PrimaryActions(
        id: id,
        load: load,
        isOwner: isOwner,
        isDriver: isDriver,
        busy: busy,
      ),
      const SizedBox(height: 14),
      _LoadSnapshot(load: load),
      const SizedBox(height: 14),
      _CompactSection(
        title: 'Route & unloading plan',
        icon: Icons.route_outlined,
        child: _RoutePlan(load: load),
      ),
      const SizedBox(height: 14),
      _CompactSection(
        title: 'Instructions & contact',
        icon: Icons.notes_outlined,
        child: _InstructionsAndContact(
          ownerName: model.ownerName,
          ownerPhone: model.ownerPhone,
          specialNote: load.specialNote,
          busy: busy,
        ),
      ),
      const SizedBox(height: 20),
      Text(
        load.hasPickupCoordinates || load.hasDestinationCoordinates
            ? 'Exact location pins are saved with this load.'
            : 'Location pins have not been added to this load.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _LoadHero extends StatelessWidget {
  const _LoadHero({required this.load});

  final LoadModel load;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
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
                'LOAD LISTING',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withValues(alpha: .78),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            StatusBadge(statusLabel(load.displayStatus)),
          ],
        ),
        const SizedBox(height: 16),
        _HeroRoutePoint(label: 'PICKUP', place: load.pickupLabel),
        Padding(
          padding: const EdgeInsets.only(left: 6, top: 5, bottom: 5),
          child: Container(
            width: 1.5,
            height: 18,
            color: Theme.of(
              context,
            ).colorScheme.onPrimary.withValues(alpha: .38),
          ),
        ),
        _HeroRoutePoint(label: 'DROP', place: load.destinationLabel),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onPrimary.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.currency_rupee_outlined,
                    size: 19,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      load.priceLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                load.pickupScheduleLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withValues(alpha: .82),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HeroRoutePoint extends StatelessWidget {
  const _HeroRoutePoint({required this.label, required this.place});
  final String label, place;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        label == 'PICKUP'
            ? Icons.radio_button_checked
            : Icons.location_on_outlined,
        color: label == 'PICKUP'
            ? const Color(0xFF9FE1BF)
            : const Color(0xFFFFC48B),
        size: 17,
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withValues(alpha: .76),
                fontWeight: FontWeight.w800,
                letterSpacing: .9,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              place,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.id,
    required this.load,
    required this.isOwner,
    required this.isDriver,
    required this.busy,
  });

  final String id;
  final LoadModel load;
  final bool isOwner, isDriver, busy;

  @override
  Widget build(BuildContext context) {
    if (isOwner) return _ownerActions(context);
    if (isDriver) return _driverActions(context);
    return const SizedBox.shrink();
  }

  Widget _ownerActions(BuildContext context) => _ActionCard(
    icon: load.status == 'in_transit'
        ? Icons.location_searching_outlined
        : Icons.manage_accounts_outlined,
    title: load.deliveryReportedAt != null
        ? 'Delivery reported'
        : load.status == 'in_transit'
        ? 'Trip in progress'
        : 'Manage this load',
    message: load.deliveryReportedAt != null
        ? 'The driver reported delivery. Open the booking to confirm receipt.'
        : load.status == 'in_transit'
        ? 'The driver has started the trip. You can see the latest shared location.'
        : 'Review driver requests or update this open listing.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: 'View booking requests',
          icon: Icons.people_outline,
          busy: busy,
          onPressed: () async {
            await context.push('/loads/$id/requests');
            if (context.mounted) context.read<LoadDetailsCubit>().load(id);
          },
        ),
        if (load.bookingId != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/bookings/${load.bookingId}'),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('View assigned booking'),
          ),
        ],
        if (load.status == 'in_transit' &&
            load.deliveryReportedAt == null &&
            load.bookingId != null) ...[
          const SizedBox(height: 8),
          AppButton(
            label: 'Track booking',
            icon: Icons.location_searching_outlined,
            busy: busy,
            onPressed: () => context.push('/tracking/${load.bookingId}'),
          ),
        ],
        if (load.status == 'open') ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await context.push('/loads/$id/edit');
              if (context.mounted) context.read<LoadDetailsCubit>().load(id);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit listing'),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    if (!await confirmAction(
                          context,
                          'Cancel this listing?',
                          'Pending requests will be cancelled and drivers will be notified.',
                          confirm: 'Cancel listing',
                        ) ||
                        !context.mounted) {
                      return;
                    }
                    final cubit = context.read<LoadDetailsCubit>();
                    if (await cubit.cancel(id)) await cubit.load(id);
                  },
            child: const Text('Cancel listing'),
          ),
        ],
      ],
    ),
  );

  Widget _driverActions(BuildContext context) => _ActionCard(
    icon: load.bookingId != null
        ? Icons.receipt_long_outlined
        : Icons.handshake_outlined,
    title: load.bookingId != null
        ? 'Your booking'
        : 'Ready to carry this load?',
    message: load.bookingId != null
        ? 'Open your booking for trip status, contact and next steps.'
        : load.status == 'open'
        ? 'Send a request. The customer must accept before this booking is confirmed.'
        : 'This load is no longer available for new requests.',
    child: load.bookingId != null
        ? AppButton(
            label: 'View your booking',
            icon: Icons.receipt_long_outlined,
            onPressed: () => context.push('/bookings/${load.bookingId}'),
          )
        : AppButton(
            label: load.status == 'open'
                ? 'Request booking'
                : 'Load unavailable',
            icon: Icons.handshake_outlined,
            busy: busy,
            onPressed: load.status != 'open'
                ? null
                : () async {
                    if (!await confirmAction(
                          context,
                          'Request this load?',
                          'Send a booking request for ${load.pickupLabel} to ${load.destinationLabel}. The customer will review your request.',
                          confirm: 'Send request',
                        ) ||
                        !context.mounted) {
                      return;
                    }
                    final cubit = context.read<LoadDetailsCubit>();
                    try {
                      final trucks = await cubit.matchingTrucks(load);
                      if (!context.mounted) return;
                      final truck = await chooseBookingTruck(context, trucks);
                      if (truck == null || !context.mounted) return;
                      if (await cubit.request(id, vehicleId: truck.id) &&
                          context.mounted) {
                        await context.push(
                          '/bookings/${cubit.requestedBookingId}',
                        );
                        if (context.mounted) cubit.load(id);
                      }
                    } catch (_) {
                      if (context.mounted) {
                        showNotice(
                          context,
                          'Could not load your trucks. Please try again.',
                        );
                      }
                    }
                  },
          ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.child,
  });

  final IconData icon;
  final String title, message;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _LoadSnapshot extends StatelessWidget {
  const _LoadSnapshot({required this.load});
  final LoadModel load;

  @override
  Widget build(BuildContext context) => _CompactSection(
    title: 'Load snapshot',
    icon: Icons.inventory_2_outlined,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _FactTile(
              width: width,
              icon: Icons.inventory_2_outlined,
              label: 'CARGO',
              value: load.cargo,
            ),
            _FactTile(
              width: width,
              icon: Icons.scale_outlined,
              label: 'WEIGHT',
              value: load.weightLabel,
            ),
            _FactTile(
              width: width,
              icon: Icons.local_shipping_outlined,
              label: 'BODY TYPE',
              value: load.vehicle,
            ),
            _FactTile(
              width: width,
              icon: Icons.straighten_outlined,
              label: 'TRUCK LENGTH',
              value: load.vehicleLengthLabel,
            ),
          ],
        );
      },
    ),
  );
}

class _FactTile extends StatelessWidget {
  const _FactTile({
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
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: .7,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
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

class _CompactSection extends StatelessWidget {
  const _CompactSection({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _RoutePlan extends StatelessWidget {
  const _RoutePlan({required this.load});
  final LoadModel load;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _RouteLine(
        label: 'PICKUP',
        value: load.pickupLabel,
        icon: Icons.trip_origin,
        color: AppTheme.green,
      ),
      for (var index = 0; index < load.unloadStops.length; index++) ...[
        _Connector(color: Theme.of(context).colorScheme.outlineVariant),
        _RouteLine(
          label: 'UNLOAD STOP ${index + 1}',
          value:
              '${placeLabel(load.unloadStops[index].location)}${load.unloadStops[index].unloadTonnes == null ? '' : ' · ${_tonnes(load.unloadStops[index].unloadTonnes!)}'}',
          icon: Icons.inventory_2_outlined,
          color: Theme.of(context).colorScheme.tertiary,
        ),
      ],
      _Connector(color: Theme.of(context).colorScheme.outlineVariant),
      _RouteLine(
        label: 'FINAL DROP',
        value: load.destinationLabel,
        icon: Icons.location_on_outlined,
        color: AppTheme.orange,
      ),
    ],
  );
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: .8,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Connector extends StatelessWidget {
  const _Connector({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8, top: 3, bottom: 3),
    child: Container(width: 1.5, height: 15, color: color),
  );
}

class _InstructionsAndContact extends StatelessWidget {
  const _InstructionsAndContact({
    required this.ownerName,
    required this.ownerPhone,
    required this.specialNote,
    required this.busy,
  });

  final String ownerName, ownerPhone, specialNote;
  final bool busy;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (specialNote.trim().isNotEmpty) ...[
        _InfoBlock(
          icon: Icons.notes_outlined,
          label: 'SPECIAL INSTRUCTIONS',
          value: specialNote,
        ),
        const SizedBox(height: 14),
      ],
      if (ownerName.isNotEmpty || ownerPhone.isNotEmpty)
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.person_outline,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ownerName.isEmpty ? 'Customer details pending' : ownerName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (ownerPhone.isNotEmpty)
                    Text(
                      ownerPhone,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (ownerPhone.isNotEmpty)
              IconButton.filledTonal(
                tooltip: 'Call customer',
                onPressed: busy
                    ? null
                    : () => context.read<LoadDetailsCubit>().callContact(
                        ownerPhone,
                      ),
                icon: const Icon(Icons.call_outlined),
              ),
          ],
        )
      else if (specialNote.trim().isEmpty)
        Text(
          'No special instructions or customer contact details are available yet.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
    ],
  );
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: .8,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    ],
  );
}

String _tonnes(double value) =>
    '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)} t';
