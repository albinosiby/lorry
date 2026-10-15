import '../../../utils/services/location_service.dart';
import 'nearby_service_model.dart';

class NearbyServicesScreenModel {
  const NearbyServicesScreenModel({
    required this.location,
    required this.radiusKm,
    required this.services,
    this.type,
    this.query = '',
    this.locationLabel = '',
    this.loadingCategories = const {},
    this.categoryErrors = const {},
    this.categoryRadii = const {},
  });
  final DeviceLocation location;
  final int radiusKm;
  final NearbyServiceType? type;
  final String query;
  final String locationLabel;
  final List<NearbyServiceModel> services;
  final Set<NearbyServiceType> loadingCategories;
  final Map<NearbyServiceType, String> categoryErrors;
  final Map<NearbyServiceType, int> categoryRadii;
}
