import 'package:url_launcher/url_launcher.dart';

/// Opens the pickup point in Google Maps. Coordinates are preferred because
/// city names alone can lead a driver to the wrong collection point.
class MapNavigationService {
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
    return launchUrl(uri, mode: LaunchMode.externalApplication);
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
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
