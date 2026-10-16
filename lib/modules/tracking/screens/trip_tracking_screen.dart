import 'package:lorry_link/l10n/app_localizations.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:lorry_link/config/app_config.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import 'package:lorry_link/design_system/design_system.dart';
import '../../../di/injection.dart';
import '../../bookings/widgets/trip_directions.dart';
import '../../auth/cubit/session_cubit.dart';
import '../../bookings/models/booking_model.dart';
import '../../bookings/repositories/booking_repository_interface.dart';
import '../../loads/widgets/load_card.dart';
import '../../loads/models/load_model.dart';
import '../cubit/trip_tracking_cubit.dart';
import '../models/trip_location_model.dart';

class TripTrackingScreen extends StatefulWidget {
  const TripTrackingScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen> {
  Timer? refreshTimer;
  BookingModel? booking;
  bool loadingBooking = false;
  final mapController = MapController();
  bool get trackingFinished =>
      booking?.deliveryReportedAt != null ||
      ['completed', 'cancelled', 'declined'].contains(booking?.status);

  @override
  void initState() {
    super.initState();
    // Auto-update every 2 minutes as requested
    refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        context.read<TripTrackingCubit>().load(widget.bookingId);
        _loadBookingDetails();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookingDetails();
    });
  }

  Future<void> _loadBookingDetails() async {
    setState(() => loadingBooking = true);
    try {
      final b = await di<IBookingRepository>().get(widget.bookingId);
      if (mounted) setState(() => booking = b);
    } catch (_) {
      // Fallback silently if offline or restricted
    } finally {
      if (mounted) setState(() => loadingBooking = false);
    }
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDriver =
        booking != null &&
        booking!.driverId == context.read<SessionCubit>().state.profile?.id;

    return Scaffold(
      body: BlocConsumer<TripTrackingCubit, ResourceState<TripLocationModel?>>(
        listener: (context, state) {
          if (state.error != null) showNotice(context, state.error!);
          if (state.notice != null) showNotice(context, state.notice!);
        },
        builder: (context, state) {
          final location = state.data;
          final point = location != null
              ? LatLng(location.latitude, location.longitude)
              : (booking?.load.pickupLatitude != null &&
                        booking?.load.pickupLongitude != null
                    ? LatLng(
                        booking!.load.pickupLatitude!,
                        booking!.load.pickupLongitude!,
                      )
                    : const LatLng(10.1632, 76.6413));

          return Stack(
            children: [
              // 1. Full-Screen Interactive Map
              Positioned.fill(
                child: AppConfig.hasMapTiles
                    ? FlutterMap(
                        key: ValueKey('${point.latitude}:${point.longitude}'),
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter: point,
                          initialZoom: location != null ? 14 : 11,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: AppConfig.mapTileUrl,
                            userAgentPackageName:
                                AppConfig.androidApplicationId,
                          ),
                          // Truck Live Position Marker
                          if (location != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: point,
                                  width: 60,
                                  height: 60,
                                  child: _TruckMapPin(),
                                ),
                              ],
                            ),
                          // Pickup & Destination Markers
                          if (booking != null) ...[
                            MarkerLayer(
                              markers: [
                                if (booking!.load.pickupLatitude != null &&
                                    booking!.load.pickupLongitude != null)
                                  Marker(
                                    point: LatLng(
                                      booking!.load.pickupLatitude!,
                                      booking!.load.pickupLongitude!,
                                    ),
                                    width: 38,
                                    height: 38,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Color(0xFF2E7D32),
                                      size: 32,
                                    ),
                                  ),
                                if (booking!.load.destinationLatitude != null &&
                                    booking!.load.destinationLongitude != null)
                                  Marker(
                                    point: LatLng(
                                      booking!.load.destinationLatitude!,
                                      booking!.load.destinationLongitude!,
                                    ),
                                    width: 38,
                                    height: 38,
                                    child: const Icon(
                                      Icons.flag_rounded,
                                      color: Color(0xFFC62828),
                                      size: 32,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      )
                    : Container(
                        color: isDark
                            ? const Color(0xFF101B15)
                            : const Color(0xFFE8F0EC),
                        child: const Center(
                          child: LocalizedText(
                            'Map tiles not configured for this build. Live coordinates remain active.',
                          ),
                        ),
                      ),
              ),

              // OpenStreetMap attribution badge
              Positioned(
                right: 8,
                bottom: 230,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: LocalizedText(
                      '© OpenStreetMap',
                      style: TextStyle(fontSize: 10, color: Colors.black87),
                    ),
                  ),
                ),
              ),

              // 2. Floating Top Header
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    // Back Button
                    _FloatingGlassButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => context.pop(),
                    ),
                    const SizedBox(width: 10),

                    // Status Pill
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (isDark ? const Color(0xFF12281E) : Colors.white)
                                  .withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(
                              0xFF2E7D32,
                            ).withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2E7D32),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LocalizedText(
                                trackingFinished
                                    ? 'TRIP FINISHED · LAST SHARED LOCATION'
                                    : booking?.status == 'accepted'
                                    ? 'TRIP NOT STARTED · PICKUP LOCATION'
                                    : location != null
                                    ? (!location.locationEnabled
                                          ? 'LOCATION OFF · LAST KNOWN POINT'
                                          : location.stale
                                          ? 'LOCATION UPDATE OVERDUE'
                                          : 'GPS UPDATES EVERY 2 MIN')
                                    : 'WAITING FOR DRIVER LOCATION',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: Color(0xFF2E7D32),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Manual Refresh Button
                    _FloatingGlassButton(
                      icon: Icons.refresh_rounded,
                      busy: state.loading || state.busy,
                      onTap: () {
                        context.read<TripTrackingCubit>().load(
                          widget.bookingId,
                        );
                        _loadBookingDetails();
                      },
                    ),
                  ],
                ),
              ),

              // 3. Floating Bottom Info Card
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 14,
                child: _buildBottomTrackingCard(
                  context,
                  location: location,
                  booking: booking,
                  isDriver: isDriver,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomTrackingCard(
    BuildContext context, {
    required TripLocationModel? location,
    required BookingModel? booking,
    required bool isDriver,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF13261D) : Colors.white).withValues(
          alpha: 0.96,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: Color(0xFF2E7D32),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalizedText(
                      booking?.load.cargo ?? 'Active Freight Cargo',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    LocalizedText(
                      booking != null
                          ? '${localize(context, booking.load.vehicle)} · Driver: ${booking.driverName}'
                          : 'Live In-Transit Shipment',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              StatusBadge(statusLabel(booking?.displayStatus ?? 'accepted')),
            ],
          ),

          if (booking != null) ...[
            const SizedBox(height: 12),
            RouteSummary(booking.load.pickup, booking.load.destination),
            if (booking.itemsCollected) const LocalizedText('Item collected'),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // GPS Coordinates & Auto-Update Details
          if (location != null) ...[
            Row(
              children: [
                const Icon(
                  Icons.gps_fixed_rounded,
                  size: 16,
                  color: Color(0xFF2E7D32),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: LocalizedText(
                    '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                LocalizedText(
                  'Updated ${DateFormat('h:mm a').format(location.recordedAt.toLocal())}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LocalizedText(
              trackingFinished
                  ? 'Location sharing ended. This is the last shared trip point.'
                  : booking?.status == 'accepted'
                  ? 'Collection location recorded. Live updates begin when the trip starts.'
                  : !location.locationEnabled
                  ? 'Location is off. The map shows the last shared point.'
                  : location.stale
                  ? 'No recent update. Showing the last shared point; the driver may be offline.'
                  : 'GPS updates every 2 minutes during the active trip.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ] else ...[
            Row(
              children: [
                const Icon(
                  Icons.location_searching_outlined,
                  size: 16,
                  color: Color(0xFFEF6C00),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: LocalizedText(
                    trackingFinished
                        ? 'No location was recorded for this completed trip.'
                        : booking?.status == 'accepted'
                        ? 'Trip has not started. Pickup and destination are shown on the map.'
                        : 'Waiting for the first live GPS broadcast from driver...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Driver Actions / Direction Button
          if (isDriver && booking != null && !trackingFinished) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.directions_outlined, size: 20),
              label: const LocalizedText(
                'View directions',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              onPressed: () => openTripDirections(context, booking),
            ),
          ],
          if (!isDriver && booking != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.call_outlined),
              label: const LocalizedText('Call driver'),
              onPressed: booking.otherPhone.isEmpty
                  ? null
                  : () async {
                      try {
                        await di<IBookingRepository>().callContact(
                          booking.otherPhone,
                        );
                      } catch (_) {
                        if (context.mounted) {
                          showNotice(
                            context,
                            'Could not open the phone dialler.',
                          );
                        }
                      }
                    },
            ),
          ],
        ],
      ),
    );
  }
}

class _FloatingGlassButton extends StatelessWidget {
  const _FloatingGlassButton({
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: busy ? null : onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF12281E) : Colors.white).withValues(
              alpha: 0.94,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
          ),
        ),
      ),
    );
  }
}

class _TruckMapPin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2E7D32).withValues(alpha: 0.22),
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF2E7D32),
            boxShadow: [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}
