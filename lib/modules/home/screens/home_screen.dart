import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../../config/routes/routes.dart';
import '../../auth/cubit/session_cubit.dart';
import '../../bookings/cubit/booking_details_cubit.dart';
import '../../bookings/models/booking_model.dart';
import '../../bookings/models/booking_screen_models.dart';
import '../../profile/models/profile_model.dart';
import '../../loads/models/load_model.dart';
import '../../loads/widgets/load_card.dart';
import '../../../utils/services/location_service.dart';
import '../../../utils/services/map_navigation_service.dart';
import '../cubit/home_cubit.dart';
import '../models/home_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static double _calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // math.pi / 180
    final a =
        0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R * asin... R = 6371 km
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<SessionCubit>().state.profile;
    if (profile == null) {
      return const PageBody(child: Center(child: CircularProgressIndicator()));
    }
    final shipper = profile.role == UserRole.shipper;

    return BlocListener<
      BookingDetailsCubit,
      ResourceState<BookingDetailsModel>
    >(
      listener: (context, state) {
        final message = state.error ?? state.notice;
        if (message != null) showNotice(context, message);
      },
      child: PageBody(
        onRefresh: () =>
            context.read<HomeCubit>().load(includeDriverTools: !shipper),
        child: BlocBuilder<HomeCubit, ResourceState<HomeModel>>(
          builder: (context, state) {
            final unread = state.data?.unread ?? 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Personalized Header & Quick Actions
                _buildHeader(context, profile, unread, shipper),
                const SizedBox(height: 18),

                // 2. Driver Location Status Strip (for Transporters/Drivers)
                if (!shipper) ...[
                  _driverLocationCard(
                    context,
                    state.data?.driverLocation,
                    checking: state.data == null || state.busy,
                  ),
                  const SizedBox(height: 18),
                ],

                // 3. Premium Hero Feature Banner
                const SizedBox(height: 22),

                // 4. Quick Services / Tools Row
                _buildQuickTools(context, shipper),
                const SizedBox(height: 24),

                // 5. Reactive Home Content (Stats, Urgent Cards, Loads)
                ResourceView<HomeModel>(
                  state: state,
                  retry: () => context.read<HomeCubit>().load(
                    includeDriverTools: !shipper,
                  ),
                  builder: (m) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Operations Metrics
                      _buildStatsGrid(context, m, shipper),

                      // 1. Current Ongoing Trip (Driver)
                      if (!shipper && m.ongoingTrips.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildDriverOngoingTripsSection(context, m.ongoingTrips),
                      ],

                      // 2. Urgent: Accepted Trips (Driver)
                      if (!shipper && m.acceptedTrips.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildAcceptedTripsSection(context, m.acceptedTrips),
                      ],

                      // 3. Live Shipment In Transit (Customer / Shipper)
                      if (shipper && m.ongoingTrips.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildCustomerLiveTransitSection(context, m.ongoingTrips),
                      ],

                      // 4. Urgent: Pending Requests Banner
                      if (m.pending > 0) ...[
                        const SizedBox(height: 18),
                        _buildPendingRequestsCard(context, m.pending, shipper),
                      ],

                      // Active / Marketplace Loads Section
                      const SizedBox(height: 28),
                      _buildLoadsSection(context, m, shipper),

                      const SizedBox(height: 24),
                      _buildLiveFooter(context),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── 1. Header & Profile Bar ───────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    ProfileModel profile,
    int unread,
    bool shipper,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final firstName = profile.name.trim().split(' ').first;
    final hasPhoto = profile.photoPath?.startsWith('http') == true;
    final initial = profile.name.trim().isEmpty
        ? 'U'
        : profile.name.trim()[0].toUpperCase();

    return Row(
      children: [
        // Avatar with role indicator ring
        InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => context.push(Routes.profile),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2A5E4A), const Color(0xFF193F35)]
                        : [const Color(0xFF193F35), const Color(0xFF336C59)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.green.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: hasPhoto
                      ? Image.network(
                          profile.photoPath!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: shipper ? AppTheme.orange : const Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Greeting and Name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_timeGreeting()}, $firstName 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (shipper ? AppTheme.orange : AppTheme.green)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      shipper ? 'CARGO SHIPPER' : 'FLEET DRIVER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: shipper ? AppTheme.orange : AppTheme.green,
                      ),
                    ),
                  ),
                  if (profile.companyName != null &&
                      profile.companyName!.trim().isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '· ${profile.companyName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Notifications Button with Unread Badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton.filledTonal(
              icon: const Icon(Icons.notifications_outlined, size: 22),
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(12),
              ),
              onPressed: () => context.push(Routes.notifications),
            ),
            if (unread > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.orange,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.orange.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ─── 2. Driver Location Status ─────────────────────────────────────────────

  Widget _driverLocationCard(
    BuildContext context,
    DeviceLocation? location, {
    required bool checking,
  }) {
    final available = location?.available == true;
    final status = location?.status;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final message = switch (status) {
      DeviceLocationStatus.serviceDisabled =>
        'GPS is disabled. Turn it on for nearby matching.',
      DeviceLocationStatus.permissionDenied =>
        'Location permission required for driver tools.',
      DeviceLocationStatus.permissionDeniedForever =>
        'Location blocked. Enable in phone settings.',
      _ =>
        checking
            ? 'Pinpointing your truck position…'
            : 'Location telemetry currently offline.',
    };

    final bgAccent = available
        ? (isDark ? const Color(0xFF163327) : const Color(0xFFE8F5E9))
        : (isDark ? const Color(0xFF332616) : const Color(0xFFFFF8E1));
    final borderAccent = available
        ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
        : const Color(0xFFF57F17).withValues(alpha: 0.35);

    return Container(
      decoration: BoxDecoration(
        color: bgAccent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderAccent),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color:
                  (available
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE65100))
                      .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              available ? Icons.radar_rounded : Icons.location_off_rounded,
              size: 20,
              color: available
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFE65100),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: available
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE65100),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      available ? 'LIVE GPS ACTIVE' : 'LOCATION REQUIRED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: available
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  available
                      ? 'Lat ${location!.latitude!.toStringAsFixed(4)}, Lon ${location.longitude!.toStringAsFixed(4)}'
                      : message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              minimumSize: const Size(60, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: checking
                ? null
                : () {
                    if (status == DeviceLocationStatus.serviceDisabled ||
                        status ==
                            DeviceLocationStatus.permissionDeniedForever) {
                      context.read<HomeCubit>().openLocationSettings(status);
                    } else {
                      context.read<HomeCubit>().requestDriverLocation();
                    }
                  },
            child: checking
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    available
                        ? 'Refresh'
                        : status == DeviceLocationStatus.permissionDeniedForever
                        ? 'Settings'
                        : 'Enable',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── 3. Hero Feature Banner ────────────────────────────────────────────────

  // ─── 4. Quick Services / Tools Bar ─────────────────────────────────────────

  Widget _buildQuickTools(BuildContext context, bool shipper) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tools = shipper
        ? [
            (
              icon: Icons.add_box_outlined,
              label: 'Post Load',
              color: AppTheme.green,
              onTap: () => context.go(Routes.postLoad),
            ),
            (
              icon: Icons.local_shipping_outlined,
              label: 'Find Trucks',
              color: AppTheme.orange,
              onTap: () => context.push(Routes.availableTrucks),
            ),
            (
              icon: Icons.inventory_2_outlined,
              label: 'My Loads',
              color: const Color(0xFF1E88E5),
              onTap: () => context.go(Routes.myLoads),
            ),
          ]
        : [
            (
              icon: Icons.search_rounded,
              label: 'Find Loads',
              color: AppTheme.green,
              onTap: () => context.go(Routes.findLoads),
            ),
            (
              icon: Icons.alt_route_rounded,
              label: 'My Trips',
              color: AppTheme.orange,
              onTap: () => context.go(Routes.trips),
            ),
            (
              icon: Icons.local_gas_station_outlined,
              label: 'Services',
              color: const Color(0xFF1E88E5),
              onTap: () => context.push(Routes.nearbyServices),
            ),
            (
              icon: Icons.local_shipping_outlined,
              label: 'Vehicles',
              color: const Color(0xFF7B1FA2),
              onTap: () => context.push(Routes.vehicles),
            ),
          ];

    return Row(
      children: tools.map((tool) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: tool.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF172821)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.6,
                          ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tool.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(tool.icon, color: tool.color, size: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tool.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── 5. Operations Metrics (Stats Grid) ───────────────────────────────────

  Widget _buildStatsGrid(BuildContext context, HomeModel m, bool shipper) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = (c.maxWidth - 24) / 3;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _statCard(
              context,
              value: '${m.open}',
              label: shipper ? 'Open Loads' : 'Available',
              icon: Icons.inventory_2_outlined,
              tint: AppTheme.green,
              width: width,
              onTap: () =>
                  context.go(shipper ? Routes.myLoads : Routes.findLoads),
            ),
            _statCard(
              context,
              value: '${m.active}',
              label: 'On The Road',
              icon: Icons.alt_route_rounded,
              tint: AppTheme.orange,
              width: width,
              onTap: () => context.go(shipper ? Routes.myLoads : Routes.trips),
            ),
            _statCard(
              context,
              value: '${m.completed}',
              label: 'Delivered',
              icon: Icons.task_alt_rounded,
              tint: const Color(0xFF00897B),
              width: width,
              onTap: () => context.go(shipper ? Routes.myLoads : Routes.trips),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(
    BuildContext context, {
    required String value,
    required String label,
    required IconData icon,
    required Color tint,
    required double width,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF172821)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: tint),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── 6. Urgent Cards (Pending Requests & Accepted Trips) ───────────────────

  Widget _buildPendingRequestsCard(
    BuildContext context,
    int pending,
    bool shipper,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.go(shipper ? Routes.myLoads : Routes.trips),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF3B2712), const Color(0xFF2B1C0B)]
                : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFF97316).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pending_actions_rounded,
                color: Color(0xFFEA580C),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '$pending ${shipper ? 'Incoming Requests' : 'Pending Approvals'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ACTION REQUIRED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    shipper
                        ? 'Drivers have requested to transport your freight. Review bids.'
                        : 'Your bids have been submitted. Track customer responses.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFFEA580C),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ─── 6b. Ongoing Trips & Live In-Transit ──────────────────────────────────

  Widget _buildDriverOngoingTripsSection(
    BuildContext context,
    List<BookingModel> ongoingTrips,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'CURRENT ONGOING TRIP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...ongoingTrips.map((trip) => _driverOngoingTripCard(context, trip)),
      ],
    );
  }

  Widget _driverOngoingTripCard(BuildContext context, BookingModel trip) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final priceValue = trip.load.price;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13251D) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1565C0).withValues(alpha: 0.45),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  size: 20,
                  color: Color(0xFF1565C0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.load.vehicle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      trip.load.cargo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (priceValue != null && priceValue > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '₹${priceValue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const StatusBadge('In transit'),
            ],
          ),
          const SizedBox(height: 14),
          RouteSummary(trip.load.pickup, trip.load.destination),
          const SizedBox(height: 16),

          // Action Buttons: View Directions & Report Delivery
          Row(
            children: [
              // 1. View Directions (Google Maps to Destination)
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.directions_outlined, size: 20),
                  label: const Text(
                    'View Directions',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () => _openDestinationInGoogleMaps(context, trip),
                ),
              ),
              const SizedBox(width: 10),

              // 2. Report Delivery (Opens Delivery Summary to record amount)
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.task_alt_rounded, size: 20),
                  label: const Text(
                    'Report Delivery',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () => _showDeliverySummaryDialog(context, trip),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerLiveTransitSection(
    BuildContext context,
    List<BookingModel> ongoingTrips,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'LIVE SHIPMENT IN TRANSIT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...ongoingTrips.map((trip) => _customerLiveTransitCard(context, trip)),
      ],
    );
  }

  Widget _customerLiveTransitCard(BuildContext context, BookingModel trip) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13251D) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.45),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.radar_rounded,
                  size: 20,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.load.cargo,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${trip.load.vehicle} · Driver: ${trip.driverName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const StatusBadge('In transit'),
            ],
          ),
          const SizedBox(height: 14),
          RouteSummary(trip.load.pickup, trip.load.destination),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.location_searching_rounded, size: 20),
            label: const Text(
              'Track Load Location',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            onPressed: () => context.push('${Routes.tracking}/${trip.id}'),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedTripsSection(
    BuildContext context,
    List<BookingModel> acceptedTrips,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'READY TO DISPATCH',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...acceptedTrips.map((trip) => _acceptedTripCard(context, trip)),
      ],
    );
  }

  Widget _acceptedTripCard(BuildContext context, BookingModel trip) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF172821) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  size: 20,
                  color: AppTheme.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.load.vehicle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      trip.load.cargo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const StatusBadge('Accepted'),
            ],
          ),
          const SizedBox(height: 16),
          RouteSummary(trip.load.pickup, trip.load.destination),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: const Text(
              'Start Trip & Broadcast GPS',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            onPressed: () => _startAcceptedTrip(context, trip.id),
          ),
        ],
      ),
    );
  }

  // ─── 7. Marketplace & Recent Loads Section ────────────────────────────────

  Widget _buildLoadsSection(BuildContext context, HomeModel m, bool shipper) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final driverLoc = m.driverLocation;
    final hasDriverLocation =
        !shipper &&
        driverLoc?.available == true &&
        driverLoc?.latitude != null &&
        driverLoc?.longitude != null;

    final double? driverLat = hasDriverLocation ? driverLoc!.latitude : null;
    final double? driverLng = hasDriverLocation ? driverLoc!.longitude : null;

    double? getDistanceToLoad(LoadModel load) {
      if (driverLat == null || driverLng == null) return null;
      if (load.pickupLatitude == null || load.pickupLongitude == null) {
        return null;
      }
      return _calculateDistanceKm(
        driverLat,
        driverLng,
        load.pickupLatitude!,
        load.pickupLongitude!,
      );
    }

    final loads = List<LoadModel>.from(m.loads);
    if (!shipper && hasDriverLocation) {
      loads.sort((a, b) {
        final distA = getDistanceToLoad(a);
        final distB = getDistanceToLoad(b);
        if (distA != null && distB != null) return distA.compareTo(distB);
        if (distA != null) return -1;
        if (distB != null) return 1;
        return 0;
      });
    }

    final nearestDistance = hasDriverLocation && loads.isNotEmpty
        ? getDistanceToLoad(loads.first)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          shipper
                              ? 'Your Active Shipments'
                              : 'Loads Near Your Location',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!shipper && hasDriverLocation) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2E7D32,
                            ).withValues(alpha: isDark ? 0.22 : 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(
                                0xFF2E7D32,
                              ).withValues(alpha: isDark ? 0.45 : 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2E7D32),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                nearestDistance != null
                                    ? 'Nearest: ${nearestDistance < 1 ? '< 1 km' : '${nearestDistance.toStringAsFixed(1)} km'}'
                                    : 'GPS Sorted',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    shipper
                        ? 'Recent load postings and incoming vehicle offers'
                        : (hasDriverLocation
                              ? 'Prioritized by proximity to your current truck position'
                              : 'Available freight • Turn on GPS above to sort loads closest to you'),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () =>
                  context.go(shipper ? Routes.myLoads : Routes.findLoads),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text(
                'View all',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (loads.isEmpty)
          AppEmptyState(
            shipper
                ? 'Your first load starts here'
                : 'No loads found right now',
            shipper
                ? 'Publish a load to connect with available truck owners.'
                : 'Check back soon or adjust your search filter criteria.',
            icon: Icons.local_shipping_outlined,
            action: FilledButton.icon(
              onPressed: () =>
                  context.go(shipper ? Routes.postLoad : Routes.findLoads),
              icon: Icon(shipper ? Icons.add : Icons.refresh_rounded),
              label: Text(shipper ? 'Post New Load' : 'Explore Loads'),
            ),
          )
        else
          LoadGrid(
            loads: loads.take(6).toList(),
            showRequests: shipper,
            distanceResolver: shipper ? null : getDistanceToLoad,
            onViewPickupOnMap: shipper
                ? null
                : (load) => _openPickupInGoogleMaps(context, load),
            onTap: (l) async {
              await context.push('/loads/${l.id}');
              if (context.mounted) {
                context.read<HomeCubit>().load(includeDriverTools: !shipper);
              }
            },
          ),
      ],
    );
  }

  // ─── 8. Footer & Status Indicator ──────────────────────────────────────────

  Widget _buildLiveFooter(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Pull to refresh • Live status syncing every 45s',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Logic Actions & Dialogs ───────────────────────────────────────────────

  Future<void> _startAcceptedTrip(
    BuildContext context,
    String bookingId,
  ) async {
    final booking = context.read<BookingDetailsCubit>();
    final location = await booking.requestLocationForTrip();
    if (location == null || !context.mounted) return;
    if (!await confirmAction(
      context,
      'Start trip and share location?',
      'Your GPS position is ready. Starting the trip will broadcast the first truck waypoint to your customer.',
      confirm: 'Start trip',
    )) {
      return;
    }
    if (!context.mounted ||
        !await booking.startTripWithLocation(bookingId, location)) {
      return;
    }
    if (!context.mounted) return;
    context.read<HomeCubit>().load(includeDriverTools: true);
    showNotice(
      context,
      'Trip started! Navigation and delivery reporting are ready below.',
    );
  }

  Future<void> _openPickupInGoogleMaps(
    BuildContext context,
    LoadModel load,
  ) async {
    final opened = await MapNavigationService().openPickup(
      pickupLabel: load.pickup,
      latitude: load.pickupLatitude,
      longitude: load.pickupLongitude,
    );
    if (context.mounted && !opened) {
      showNotice(context, 'Could not open Google Maps.');
    }
  }

  Future<void> _openDestinationInGoogleMaps(
    BuildContext context,
    BookingModel trip,
  ) async {
    final opened = await MapNavigationService().openDestination(
      destinationLabel: trip.load.destination,
      latitude: trip.load.destinationLatitude,
      longitude: trip.load.destinationLongitude,
    );
    if (context.mounted && !opened) {
      showNotice(context, 'Could not open Google Maps.');
    }
  }

  Future<void> _showDeliverySummaryDialog(
    BuildContext context,
    BookingModel trip,
  ) async {
    final expectedPrice = trip.load.price ?? 0;
    final collected = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DeliverySummarySheet(
        trip: trip,
        defaultAmount: expectedPrice > 0 ? expectedPrice : null,
      ),
    );
    if (collected == null || !context.mounted) return;
    final ok = await context
        .read<BookingDetailsCubit>()
        .reportDeliveryWithCollection(trip.id, collected);
    if (ok && context.mounted) {
      context.read<HomeCubit>().load(includeDriverTools: true);
      showNotice(
        context,
        'Delivery reported! ₹${collected.toStringAsFixed(0)} added to Finance tracker.',
      );
    }
  }
}

class _DeliverySummarySheet extends StatefulWidget {
  const _DeliverySummarySheet({
    required this.trip,
    this.defaultAmount,
  });

  final BookingModel trip;
  final double? defaultAmount;

  @override
  State<_DeliverySummarySheet> createState() => _DeliverySummarySheetState();
}

class _DeliverySummarySheetState extends State<_DeliverySummarySheet> {
  final form = GlobalKey<FormState>();
  late final amountController = TextEditingController(
    text: widget.defaultAmount == null
        ? ''
        : widget.defaultAmount!.toStringAsFixed(
            widget.defaultAmount!.truncateToDouble() == widget.defaultAmount
                ? 0
                : 2,
          ),
  );

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final trip = widget.trip;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14241D) : cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    color: Color(0xFF2E7D32),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Summary & Finance',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Record freight collection to complete this trip',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Shipment Overview Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1B2D26)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RouteSummary(trip.load.pickup, trip.load.destination),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${trip.load.cargo} · ${trip.load.vehicle}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.defaultAmount != null && widget.defaultAmount! > 0)
                        Text(
                          'Agreed: ₹${widget.defaultAmount!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Amount Field
            AppTextField(
              controller: amountController,
              label: 'Amount Collected (₹) *',
              hint: 'Enter freight money collected',
              prefixText: '₹ ',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final a = double.tryParse(v?.trim() ?? '');
                return a == null || a <= 0
                    ? 'Enter the freight amount collected.'
                    : null;
              },
            ),
            const SizedBox(height: 4),
            Text(
              'This payment will be automatically added as positive income into your Finance tracker.',
              style: TextStyle(
                fontSize: 11.5,
                color: cs.onSurfaceVariant,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text(
                'Confirm Delivery & Save Income',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
              onPressed: () {
                if (!form.currentState!.validate()) return;
                final collectedAmount = double.parse(amountController.text.trim());
                Navigator.pop(context, collectedAmount);
              },
            ),
          ],
        ),
      ),
    );
  }
}
