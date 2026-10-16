import 'package:lorry_link/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lorry_link/config/routes/routes.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import 'package:lorry_link/design_system/design_system.dart';
import '../../loads/models/load_model.dart';
import '../cubit/trips_cubit.dart';
import '../models/booking_model.dart';
import '../models/booking_screen_models.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key, this.loadId, this.requests = false});
  final String? loadId;
  final bool requests;

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  String? status;

  @override
  void initState() {
    super.initState();
    status = widget.requests ? 'requested' : null;
  }

  Future<void> refresh() => context.read<TripsCubit>().load(
    loadId: widget.loadId,
    status: status,
    incoming: widget.requests,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final body = PageBody(
      onRefresh: refresh,
      child: BlocBuilder<TripsCubit, ResourceState<TripsScreenModel>>(
        builder: (context, state) => ResourceView<TripsScreenModel>(
          state: state,
          retry: refresh,
          builder: (model) {
            final activeTransitTrip = model.bookings
                .cast<BookingModel?>()
                .firstWhere((b) => b?.isLiveTrip ?? false, orElse: () => null);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Command Header
                _buildHeader(context, model, activeTransitTrip, isDark),
                const SizedBox(height: 20),

                // Status Filter Chips
                _buildFilterChips(isDark),
                const SizedBox(height: 20),

                // Section Label
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    LocalizedText(
                      widget.requests
                          ? 'Booking Requests (${model.bookings.length})'
                          : 'Trips & Consignments (${model.bookings.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (state.loading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Empty State or Trip Cards
                if (model.bookings.isEmpty)
                  _buildEmptyState(context, isDark)
                else
                  ...model.bookings.map(
                    (b) => _buildTripCard(context, b, isDark),
                  ),

                // Load More
                if (model.hasMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: state.loading
                            ? null
                            : () => context.read<TripsCubit>().more(),
                        icon: const Icon(Icons.expand_more_rounded),
                        label: const LocalizedText('Load More Trips'),
                      ),
                    ),
                  ),

                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
    );

    return widget.requests
        ? Scaffold(
            appBar: AppBar(
              title: const LocalizedText('Booking Requests'),
              centerTitle: false,
              actions: [
                IconButton(
                  tooltip: localize(context, 'Refresh'),
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: refresh,
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: body,
          )
        : body;
  }

  Widget _buildHeader(
    BuildContext context,
    TripsScreenModel model,
    BookingModel? activeTransitTrip,
    bool isDark,
  ) {
    final inTransitCount = model.bookings.where((b) => b.isLiveTrip).length;
    final acceptedCount = model.bookings
        .where((b) => b.status == 'accepted')
        .length;
    final completedCount = model.bookings
        .where((b) => b.status == 'completed')
        .length;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF13362D), const Color(0xFF1C463A)]
              : [const Color(0xFF193F35), const Color(0xFF265A4B)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF193F35).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Stack(
          children: [
            // Watermark icon
            Positioned(
              right: -10,
              bottom: -15,
              child: Icon(
                Icons.route_rounded,
                size: 130,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD5E9A9).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(
                              0xFFD5E9A9,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.requests
                                  ? Icons.assignment_ind_outlined
                                  : Icons.alt_route_rounded,
                              size: 13,
                              color: const Color(0xFFD5E9A9),
                            ),
                            const SizedBox(width: 5),
                            LocalizedText(
                              widget.requests
                                  ? 'CARRIER REQUESTS'
                                  : 'DISPATCH COMMAND',
                              style: const TextStyle(
                                color: Color(0xFFD5E9A9),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!widget.requests)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFD5E9A9),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => context.go(Routes.findLoads),
                          icon: const Icon(Icons.search, size: 16),
                          label: const LocalizedText(
                            'Find Loads',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LocalizedText(
                    widget.requests
                        ? 'Review Requests'
                        : 'Your Journeys & Loads',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LocalizedText(
                    widget.requests
                        ? 'Connect with verified carriers who requested your freight loads.'
                        : 'Track active shipments from initial pickup to destination delivery.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Metrics Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceAround,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildMetricCol(
                          'IN TRANSIT',
                          '$inTransitCount',
                          Icons.local_shipping_outlined,
                          color: inTransitCount > 0
                              ? const Color(0xFFD5E9A9)
                              : Colors.white,
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        _buildMetricCol(
                          'ACCEPTED',
                          '$acceptedCount',
                          Icons.check_circle_outline_rounded,
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        _buildMetricCol(
                          'COMPLETED',
                          '$completedCount',
                          Icons.task_alt_rounded,
                          color: const Color(0xFFD5E9A9),
                        ),
                      ],
                    ),
                  ),

                  // Active Live Dispatch Banner
                  if (activeTransitTrip != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0038A8).withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFD5E9A9).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFD5E9A9),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const LocalizedText(
                                  'ACTIVE CONSIGNMENT IN TRANSIT',
                                  style: TextStyle(
                                    color: Color(0xFFD5E9A9),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                LocalizedText(
                                  '${activeTransitTrip.load.pickupLabel} → ${activeTransitTrip.load.destinationLabel}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD5E9A9),
                              foregroundColor: const Color(0xFF193F35),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => context.push(
                              '${Routes.tracking}/${activeTransitTrip.id}',
                            ),
                            icon: const Icon(Icons.gps_fixed_rounded, size: 14),
                            label: const LocalizedText(
                              'Live GPS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCol(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color ?? const Color(0xFFD5E9A9)),
            const SizedBox(width: 4),
            LocalizedText(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final filters = [
      (null, 'All Trips', Icons.apps_rounded),
      ('in_transit', 'In Transit', Icons.local_shipping_outlined),
      ('accepted', 'Accepted', Icons.check_circle_outline_rounded),
      ('requested', 'Requested', Icons.hourglass_top_rounded),
      ('completed', 'Completed', Icons.task_alt_rounded),
      ('declined', 'Declined', Icons.cancel_outlined),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final isSelected = status == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              showCheckmark: false,
              avatar: Icon(
                f.$3,
                size: 14,
                color: isSelected
                    ? const Color(0xFFD5E9A9)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
              label: LocalizedText(f.$2),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFFD5E9A9)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF193F35),
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF0F4F2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF193F35)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06)),
                ),
              ),
              onSelected: (_) {
                setState(() => status = f.$1);
                refresh();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, BookingModel b, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E2421) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);

    final isInTransit = b.isLiveTrip;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: isInTransit
              ? const Color(0xFF193F35).withValues(alpha: 0.5)
              : borderColor,
          width: isInTransit ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          onTap: () async {
            await context.push('/bookings/${b.id}');
            if (mounted) refresh();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta Bar: Vehicle / Carrier + Status Pill
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Vehicle / Driver Name
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF193F35,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            widget.requests
                                ? Icons.person_outline_rounded
                                : Icons.local_shipping_outlined,
                            size: 15,
                            color: const Color(0xFF193F35),
                          ),
                        ),
                        const SizedBox(width: 8),
                        LocalizedText(
                          widget.requests ? b.driverName : b.load.vehicle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),

                    // Status Badge
                    _buildStatusPill(b),
                  ],
                ),
                const SizedBox(height: 16),

                // Route Visualizer (Origin -> Destination)
                _buildRouteTimeline(context, b.load, isDark),
                const SizedBox(height: 16),

                // Specs & Price Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : const Color(0xFFF3F6F4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      // Cargo & Weight
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 15,
                              color: Color(0xFF193F35),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: LocalizedText(
                                '${localize(context, b.load.weightLabel)} · ${b.load.cargo}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Price Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF193F35,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: LocalizedText(
                          b.load.priceLabel,
                          style: const TextStyle(
                            color: Color(0xFF193F35),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Card Footer Actions
                Row(
                  children: [
                    if (isInTransit) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF193F35),
                            foregroundColor: const Color(0xFFD5E9A9),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () =>
                              context.push('${Routes.tracking}/${b.id}'),
                          icon: const Icon(Icons.gps_fixed_rounded, size: 15),
                          label: const LocalizedText(
                            'Track Live GPS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white24
                                : Colors.black.withValues(alpha: 0.15),
                          ),
                        ),
                        onPressed: () async {
                          await context.push('/bookings/${b.id}');
                          if (mounted) refresh();
                        },
                        icon: const Icon(Icons.article_outlined, size: 15),
                        label: const LocalizedText(
                          'Trip Details',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteTimeline(
    BuildContext context,
    LoadModel load,
    bool isDark,
  ) {
    return Column(
      children: [
        // Pickup row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.18),
                    border: Border.all(
                      color: const Color(0xFF2E7D32),
                      width: 3,
                    ),
                  ),
                ),
                Container(
                  width: 1.5,
                  height: 24,
                  color: isDark
                      ? Colors.white24
                      : Colors.black.withValues(alpha: 0.12),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    load.pickupLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  LocalizedText(
                    'Pickup · ${load.pickupScheduleLabel}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Destination row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.orange.withValues(alpha: 0.2),
                border: Border.all(color: AppTheme.orange, width: 3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    load.destinationLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  LocalizedText(
                    'Drop-off Destination',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusPill(BookingModel b) {
    if (b.deliveryReportedAt != null && b.status == 'in_transit') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.amber.shade700, width: 0.8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.report_gmailerrorred_rounded,
              size: 12,
              color: Colors.amber,
            ),
            SizedBox(width: 4),
            LocalizedText(
              'DELIVERY REPORTED',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    final (color, label, icon) = switch (b.displayStatus) {
      'item_collected' => (
        const Color(0xFF2E7D32),
        'ITEMS COLLECTED',
        Icons.inventory_2_outlined,
      ),
      'delivery_confirmed' => (
        const Color(0xFF455A64),
        'DELIVERY CONFIRMED',
        Icons.task_alt_rounded,
      ),
      'in_transit' => (
        const Color(0xFF00897B),
        'IN TRANSIT 🚚',
        Icons.directions_run_rounded,
      ),
      'accepted' => (
        const Color(0xFF2E7D32),
        'READY / ACCEPTED',
        Icons.check_circle_outline_rounded,
      ),
      'requested' => (
        const Color(0xFF1976D2),
        'REQUEST PENDING',
        Icons.hourglass_top_rounded,
      ),
      'completed' => (
        const Color(0xFF455A64),
        'COMPLETED 🏁',
        Icons.task_alt_rounded,
      ),
      'declined' => (
        const Color(0xFFC62828),
        'DECLINED',
        Icons.cancel_outlined,
      ),
      'cancelled' => (
        const Color(0xFFC62828),
        'CANCELLED',
        Icons.cancel_outlined,
      ),
      _ => (
        Colors.grey.shade700,
        statusLabel(b.status).toUpperCase(),
        Icons.info_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: LocalizedText(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2421) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF193F35).withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.route_outlined,
              size: 36,
              color: Color(0xFF193F35),
            ),
          ),
          const SizedBox(height: 18),
          LocalizedText(
            widget.requests ? 'No booking requests found' : 'No trips found',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          LocalizedText(
            widget.requests
                ? 'Incoming booking requests from drivers will appear here once loads are posted.'
                : 'Browse available freight loads and send your booking requests to start your next journey.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          if (!widget.requests)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF193F35),
                foregroundColor: const Color(0xFFD5E9A9),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => context.go(Routes.findLoads),
              icon: const Icon(Icons.search_rounded),
              label: const LocalizedText(
                'Browse Available Loads',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
