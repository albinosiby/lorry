import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../modules/bookings/repositories/booking_repository_interface.dart';
import '../../modules/tracking/repositories/trip_tracking_repository_interface.dart';
import 'location_service.dart';
import 'supabase_service.dart';

/// Owned by the signed-in app rather than a screen. Android's location stream
/// keeps a foreground location service alive while navigation is in use.
class TripLocationSharingService {
  TripLocationSharingService(
    this.service,
    this.bookings,
    this.tracking,
    this.location,
  );
  final SupabaseService service;
  final IBookingRepository bookings;
  final ITripTrackingRepository tracking;
  final ILocationService location;
  Timer? _timer;
  StreamSubscription<Position>? _positions;
  StreamSubscription<ServiceStatus>? _gps;
  String? _user;
  bool _busy = false;
  int _generation = 0;
  final _lastSent = <String, DateTime>{};
  final _enabled = <String, bool>{};

  void start(String user) {
    if (_user == user) return;
    _user = user;
    ++_generation;
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(sync()),
    );
    if (!kIsWeb) {
      _gps ??= Geolocator.getServiceStatusStream().listen((_) {
        _lastSent.clear();
        unawaited(sync());
      }, onError: (Object _) {});
    }
    unawaited(sync());
  }

  Future<void> sync() async {
    final user = _user;
    if (user == null || _busy) return;
    final generation = _generation;
    _busy = true;
    try {
      final active = (await bookings.list(status: 'in_transit'))
          .where((b) => b.driverId == user && b.deliveryReportedAt == null)
          .toList();
      if (generation != _generation) return;
      final ids = active.map((b) => b.id).toSet();
      _lastSent.removeWhere((id, _) => !ids.contains(id));
      _enabled.removeWhere((id, _) => !ids.contains(id));
      if (active.isEmpty) {
        await _positions?.cancel();
        _positions = null;
        return;
      }
      final enabled =
          kIsWeb ||
          (await Geolocator.isLocationServiceEnabled() &&
              [
                LocationPermission.always,
                LocationPermission.whileInUse,
              ].contains(await Geolocator.checkPermission()));
      for (final trip in active) {
        if (_enabled[trip.id] != enabled) {
          await service.client.rpc(
            'trip_location_status',
            params: {'booking_id': trip.id, 'enabled': enabled},
          );
          _enabled[trip.id] = enabled;
        }
      }
      if (!enabled) return;
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          _positions == null) {
        _positions =
            Geolocator.getPositionStream(
              locationSettings: AndroidSettings(
                accuracy: LocationAccuracy.medium,
                distanceFilter: 0,
                intervalDuration: const Duration(minutes: 2),
                foregroundNotificationConfig: const ForegroundNotificationConfig(
                  notificationTitle: 'Trip location sharing active',
                  notificationText:
                      'LORRY LINK shares your trip location every 2 minutes.',
                  enableWakeLock: true,
                ),
              ),
            ).listen(
              (_) {},
              onError: (Object _) {
                _positions?.cancel();
                _positions = null;
              },
            );
      }
      final due = active
          .where(
            (b) =>
                _lastSent[b.id] == null ||
                DateTime.now().difference(_lastSent[b.id]!) >=
                    const Duration(minutes: 2),
          )
          .toList();
      if (due.isEmpty) return;
      final point = await location
          .current(requestPermission: false)
          .timeout(const Duration(seconds: 25));
      if (generation != _generation) return;
      if (!point.available) return;
      for (final trip in due) {
        await tracking.update(
          bookingId: trip.id,
          latitude: point.latitude!,
          longitude: point.longitude!,
        );
        _lastSent[trip.id] = DateTime.now();
      }
    } catch (_) {
      // Network failure must not be reported as GPS being switched off. The
      // customer sees a stale timestamp until connectivity is restored.
    } finally {
      _busy = false;
    }
  }

  Future<void> stop() async {
    ++_generation;
    _user = null;
    _timer?.cancel();
    _timer = null;
    await _positions?.cancel();
    await _gps?.cancel();
    _positions = null;
    _gps = null;
    _lastSent.clear();
    _enabled.clear();
  }
}
