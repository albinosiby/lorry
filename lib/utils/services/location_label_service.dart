import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'location_service.dart';

class LocationLabelService {
  Future<String> describe(DeviceLocation location) async {
    if (!location.available) return '';
    if (!kIsWeb &&
        [
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      try {
        final places = await Geocoding().placemarkFromCoordinates(
          location.latitude!,
          location.longitude!,
        ).timeout(const Duration(seconds: 4));
        if (places.isNotEmpty) {
          final p = places.first;
          final name = [
            p.subLocality,
            p.locality,
            p.administrativeArea,
          ].whereType<String>().where((s) => s.isNotEmpty).toSet().join(', ');
          if (name.isNotEmpty) return name;
        }
      } catch (_) {
        /* Coordinates remain a usable location label. */
      }
    }
    return '${location.latitude!.toStringAsFixed(4)}, ${location.longitude!.toStringAsFixed(4)}';
  }
}
