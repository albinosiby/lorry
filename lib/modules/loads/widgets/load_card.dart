import 'package:flutter/material.dart';
import 'package:lorry_link/design_system/design_system.dart';
import '../models/load_model.dart';

class LoadCard extends StatelessWidget {
  const LoadCard(
    this.load, {
    super.key,
    required this.onTap,
    this.showRequests = false,
    this.onTrackBooking,
    this.onViewPickupOnMap,
    this.distanceKm,
  });

  final LoadModel load;
  final VoidCallback onTap;
  final bool showRequests;
  final VoidCallback? onTrackBooking;
  final VoidCallback? onViewPickupOnMap;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2421) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta Row: Vehicle Type, Date, Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Vehicle tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF193F35).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF193F35).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_shipping_outlined,
                            size: 13,
                            color: Color(0xFF193F35),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            load.vehicle,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF193F35),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Date & Status
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (distanceKm != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32).withValues(
                                alpha: isDark ? 0.22 : 0.1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF2E7D32).withValues(
                                  alpha: isDark ? 0.5 : 0.25,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.near_me_rounded,
                                  size: 11,
                                  color: Color(0xFF2E7D32),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  distanceKm! < 1
                                      ? '< 1 km away'
                                      : '${distanceKm!.toStringAsFixed(1)} km away',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          load.dateLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(statusLabel(load.displayStatus)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Route Segment (Origin -> Destination)
                _buildRouteRow(context, isDark),
                const SizedBox(height: 14),

                // Cargo & Specifications Box
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : const Color(0xFFF3F6F4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 15,
                        color: Color(0xFF193F35),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          load.cargo,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Weight chip
                      Text(
                        load.weightLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF193F35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Spec Chips Row
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _detailChip(
                      context,
                      Icons.straighten_outlined,
                      load.vehicleLengthLabel,
                      isDark,
                    ),
                    if (load.unloadStops.isNotEmpty)
                      _detailChip(
                        context,
                        Icons.alt_route_rounded,
                        '${load.unloadStops.length} drops',
                        isDark,
                      ),
                    if (showRequests && load.requestCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${load.requestCount} requests',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.orange,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Bottom Action & Freight Rate Row
                Row(
                  children: [
                    // Freight Rate
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FREIGHT OFFER',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            load.priceLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF193F35),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Primary View / Apply Button
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onViewPickupOnMap != null) ...[
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'View on map',
                            icon: const Icon(Icons.map_outlined, size: 18),
                            onPressed: onViewPickupOnMap,
                          ),
                          const SizedBox(width: 4),
                        ],
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF193F35),
                            foregroundColor: const Color(0xFFD5E9A9),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: onTap,
                          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                          label: const Text(
                            'View Load',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // In-transit tracking action
                if (load.status == 'in_transit') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_shipping_outlined,
                          size: 16,
                          color: Color(0xFF00897B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            load.deliveryReportedAt == null
                                ? 'Shipment in transit'
                                : 'Delivery reported',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Color(0xFF00897B),
                            ),
                          ),
                        ),
                        if (onTrackBooking != null)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                            ),
                            onPressed: onTrackBooking,
                            icon: const Icon(
                              Icons.location_searching_outlined,
                              size: 14,
                            ),
                            label: const Text(
                              'Track',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteRow(BuildContext context, bool isDark) {
    return Row(
      children: [
        // Origin
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'PICKUP',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E7D32),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                load.pickupLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Route Connector Arrow
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),

        // Destination
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.orange,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'DESTINATION',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.orange,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                load.destinationLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailChip(
    BuildContext context,
    IconData icon,
    String value,
    bool isDark,
  ) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFF3F6F4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isDark ? const Color(0xFFD5E9A9) : const Color(0xFF193F35),
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      );
}

class RouteSummary extends StatelessWidget {
  const RouteSummary(this.pickup, this.destination, {super.key});
  final String pickup, destination;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _point(context, pickup, true),
      Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 1.5,
            height: 18,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      _point(context, destination, false),
    ],
  );

  Widget _point(BuildContext context, String title, bool origin) => Row(
    children: [
      Icon(
        origin ? Icons.radio_button_checked : Icons.location_on_outlined,
        size: 15,
        color: origin ? const Color(0xFF2E7D32) : AppTheme.orange,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          placeLabel(title),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    ],
  );
}

class LoadGrid extends StatelessWidget {
  const LoadGrid({
    super.key,
    required this.loads,
    required this.onTap,
    this.showRequests = false,
    this.onTrackBooking,
    this.onViewPickupOnMap,
    this.distanceResolver,
  });

  final List<LoadModel> loads;
  final void Function(LoadModel) onTap;
  final bool showRequests;
  final void Function(LoadModel load)? onTrackBooking;
  final void Function(LoadModel load)? onViewPickupOnMap;
  final double? Function(LoadModel load)? distanceResolver;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = c.maxWidth >= 900
          ? 3
          : c.maxWidth >= 600
          ? 2
          : 1;
      final width = (c.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: loads
            .map(
              (l) => SizedBox(
                width: width,
                child: LoadCard(
                  l,
                  onTap: () => onTap(l),
                  showRequests: showRequests,
                  distanceKm: distanceResolver?.call(l),
                  onTrackBooking: onTrackBooking == null || l.bookingId == null
                      ? null
                      : () => onTrackBooking!(l),
                  onViewPickupOnMap: onViewPickupOnMap == null
                      ? null
                      : () => onViewPickupOnMap!(l),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}
