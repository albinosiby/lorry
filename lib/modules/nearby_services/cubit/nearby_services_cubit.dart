import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../../utils/services/location_service.dart';
import '../models/nearby_service_model.dart';
import '../models/nearby_services_screen_model.dart';
import '../repositories/nearby_services_repository_interface.dart';

class NearbyServicesCubit extends ResourceCubit<NearbyServicesScreenModel> {
  NearbyServicesCubit(this.repository, this.locationService);
  final INearbyServicesRepository repository;
  final ILocationService locationService;

  Future<void> locateAndSearch({
    int radiusKm = 10,
    NearbyServiceType? type,
    String query = '',
  }) => fetch(() async {
    final location = await locationService.current();
    if (!location.available) {
      return NearbyServicesScreenModel(
        location: location,
        radiusKm: radiusKm,
        type: type,
        query: query,
        services: const [],
      );
    }
    final services = await repository.search(
      latitude: location.latitude!,
      longitude: location.longitude!,
      radiusKm: radiusKm,
      type: type,
      query: query,
    );
    return NearbyServicesScreenModel(
      location: location,
      radiusKm: radiusKm,
      type: type,
      query: query,
      services: services,
    );
  });

  Future<void> openSettings() => locationService.openSettings();
}
