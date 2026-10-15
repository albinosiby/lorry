import 'package:geocoding/geocoding.dart';

import '../exceptions/app_exception.dart';

class PlaceSearchResult {
  const PlaceSearchResult({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude, longitude;
}

abstract interface class IPlaceSearchService {
  Future<List<PlaceSearchResult>> search(String query);
}

class PlaceSearchService implements IPlaceSearchService {
  PlaceSearchService({Geocoding? geocoding})
    : _geocoding = geocoding ?? Geocoding();

  final Geocoding _geocoding;

  @override
  Future<List<PlaceSearchResult>> search(String query) async {
    final term = query.trim();
    if (term.length < 2) {
      throw const AppException('Enter at least two characters to search.');
    }
    try {
      final locations = await _geocoding.locationFromAddress('$term, India');
      if (locations.isEmpty) {
        throw const AppException(
          'No matching place was found. Try a fuller name.',
        );
      }
      return locations
          .take(5)
          .toList()
          .asMap()
          .entries
          .map(
            (entry) => PlaceSearchResult(
              label: locations.length == 1
                  ? term
                  : '$term · result ${entry.key + 1}',
              latitude: entry.value.latitude,
              longitude: entry.value.longitude,
            ),
          )
          .toList();
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        'We could not find that place. Check your internet connection and try a more specific name.',
      );
    }
  }
}
