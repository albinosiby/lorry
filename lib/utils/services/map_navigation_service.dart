import 'package:url_launcher/url_launcher.dart';
import '../../modules/bookings/models/booking_model.dart';

class TripDirectionsPlan {
  const TripDirectionsPlan(this.uri, this.endLabel, this.deferredStops);
  final Uri uri;
  final String endLabel;

  /// Remaining destinations (including final delivery) beyond this section.
  final int deferredStops;
}

/// Opens the pickup point in Google Maps. Coordinates are preferred because
/// city names alone can lead a driver to the wrong collection point.
class MapNavigationService {
  // Mobile-browser fallback supports three waypoints. A section therefore
  // visits up to four destinations, with the fourth as the section endpoint.
  // https://developers.google.com/maps/documentation/urls/get-started
  static const maxWaypoints = 3;

  static String _point(String label, double? latitude, double? longitude) =>
      latitude != null &&
          longitude != null &&
          latitude.isFinite &&
          longitude.isFinite &&
          latitude >= -90 &&
          latitude <= 90 &&
          longitude >= -180 &&
          longitude <= 180
      ? '$latitude,$longitude'
      : label;

  TripDirectionsPlan tripPlan(BookingModel booking) {
    final load = booking.load;
    if (!booking.itemsCollected) {
      return TripDirectionsPlan(
        _directions(
          _point(load.pickup, load.pickupLatitude, load.pickupLongitude),
        ),
        load.pickup,
        0,
      );
    }
    final points = <({String label, String point})>[
      for (var i = 0; i < load.unloadStops.length; i++)
        if (!booking.unloadedStopIndices.contains(i))
          (
            label: load.unloadStops[i].location,
            point: _point(
              load.unloadStops[i].location,
              load.unloadStops[i].latitude,
              load.unloadStops[i].longitude,
            ),
          ),
      (
        label: load.destination,
        point: _point(
          load.destination,
          load.destinationLatitude,
          load.destinationLongitude,
        ),
      ),
    ];
    final section = points.take(maxWaypoints + 1).toList();
    return TripDirectionsPlan(
      _directions(
        section.last.point,
        waypoints: section
            .take(section.length - 1)
            .map((p) => p.point)
            .toList(),
      ),
      section.last.label,
      points.length - section.length,
    );
  }

  static Uri _directions(
    String destination, {
    List<String> waypoints = const [],
  }) => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': destination,
    'travelmode': 'driving',
    if (waypoints.isNotEmpty) 'waypoints': waypoints.join('|'),
  });

  Future<bool> openPlan(TripDirectionsPlan plan) => _open(plan.uri);

  Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<bool> openPickup({
    required String pickupLabel,
    double? latitude,
    double? longitude,
  }) {
    final hasCoordinates = latitude != null && longitude != null;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': hasCoordinates
          ? '${latitude.toString()},${longitude.toString()}'
          : pickupLabel,
      'travelmode': 'driving',
    });
    return _open(uri);
  }

  /// Opens the destination point in Google Maps for turn-by-turn driving directions.
  Future<bool> openDestination({
    required String destinationLabel,
    double? latitude,
    double? longitude,
  }) {
    final hasCoordinates = latitude != null && longitude != null;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': hasCoordinates
          ? '${latitude.toString()},${longitude.toString()}'
          : destinationLabel,
      'travelmode': 'driving',
    });
    return _open(uri);
  }
}
