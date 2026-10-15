import '../../../utils/services/location_service.dart';
import 'nearby_service_model.dart';

class NearbyServicesScreenModel {
  const NearbyServicesScreenModel({
    required this.location,
    required this.radiusKm,
    required this.services,
    this.type,
    this.query = '',
  });
  final DeviceLocation location;
  final int radiusKm;
  final NearbyServiceType? type;
  final String query;
  final List<NearbyServiceModel> services;
}
