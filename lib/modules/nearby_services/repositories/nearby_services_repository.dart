import '../../../utils/services/supabase_service.dart';
import '../models/nearby_service_model.dart';
import 'nearby_services_repository_interface.dart';

class NearbyServicesRepository implements INearbyServicesRepository {
  NearbyServicesRepository(this.service);
  final SupabaseService service;

  @override
  Future<List<NearbyServiceModel>> search({
    required double latitude,
    required double longitude,
    required int radiusKm,
    NearbyServiceType? type,
    String? query,
    bool expand = false,
  }) async {
    final data = await service.invokeFunction('nearby-services', {
      'latitude': latitude,
      'longitude': longitude,
      'radius_km': radiusKm,
      'type': type?.apiValue,
      'query': query?.trim().isEmpty ?? true ? null : query!.trim(),
      'expand': expand,
    });
    final rows = data is List ? data : (data['services'] as List? ?? const []);
    return rows
        .map(
          (row) => NearbyServiceModel.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }
}
