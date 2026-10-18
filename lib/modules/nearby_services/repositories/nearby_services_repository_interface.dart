import '../models/nearby_service_model.dart';

abstract interface class INearbyServicesRepository {
  Future<List<NearbyServiceModel>> search({
    required double latitude,
    required double longitude,
    required int radiusKm,
    NearbyServiceType? type,
    String? query,
    bool expand = false,
  });
}
