import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../../utils/exceptions/app_exception.dart';
import '../../../utils/services/location_service.dart';
import '../models/nearby_service_model.dart';
import '../models/nearby_services_screen_model.dart';
import '../repositories/nearby_services_repository_interface.dart';

/// Owns the one provider request made for a nearby-services page visit.
///
/// Google Places charges per request. The page therefore fetches the combined
/// nearby result once when it opens, keeps it in this state, and applies search
/// and category changes locally. A fresh provider request is made only when the
/// driver explicitly taps **Near me**.
class NearbyServicesCubit extends ResourceCubit<NearbyServicesScreenModel> {
  NearbyServicesCubit(
    this.repository,
    this.locationService, {
    this.resolveLocationLabel,
  });

  final INearbyServicesRepository repository;
  final ILocationService locationService;
  final Future<String> Function(DeviceLocation)? resolveLocationLabel;
  int _searchGeneration = 0;

  /// Loads all supported categories in one provider call.
  ///
  /// [query] and [type] describe local UI filters only; they are intentionally
  /// not passed to the provider so filter taps and typing never create Google
  /// Places requests.
  Future<void> loadNearby({String query = '', NearbyServiceType? type}) async {
    final generation = ++_searchGeneration;
    final previous = state.data;
    emit(ResourceState(data: previous, busy: true, loading: previous == null));

    try {
      final location = await locationService.current().timeout(
        const Duration(seconds: 25),
      );
      if (isClosed || generation != _searchGeneration) return;

      final label = resolveLocationLabel == null
          ? ''
          : await resolveLocationLabel!(location);
      if (isClosed || generation != _searchGeneration) return;

      if (!location.available) {
        emit(
          ResourceState(
            data: NearbyServicesScreenModel(
              location: location,
              locationLabel: label,
              radiusKm: 50,
              query: query,
              type: type,
              services: const [],
            ),
          ),
        );
        return;
      }

      // `type: null` makes the Edge Function make one combined Google Places
      // request (or one OSM fallback request), rather than one request per row.
      final services = List<NearbyServiceModel>.of(
        await repository
            .search(
              latitude: location.latitude!,
              longitude: location.longitude!,
              radiusKm: 50,
            )
            .timeout(const Duration(seconds: 60)),
      );
      if (isClosed || generation != _searchGeneration) return;
      services.sort(
        (a, b) => (a.distanceKm ?? double.infinity).compareTo(
          b.distanceKm ?? double.infinity,
        ),
      );
      emit(
        ResourceState(
          data: NearbyServicesScreenModel(
            location: location,
            locationLabel: label,
            radiusKm: 50,
            query: query,
            type: type,
            services: services,
            categoryRadii: {
              for (final category in NearbyServiceType.values) category: 50,
            },
          ),
        ),
      );
    } catch (error) {
      if (!isClosed && generation == _searchGeneration) {
        emit(
          ResourceState(
            data: previous,
            error: AppException.from(error).message,
          ),
        );
      }
    }
  }

  /// Applies filter controls to the cached response without any network call.
  void updateFilters({String? query, NearbyServiceType? type}) {
    final current = state.data;
    if (current == null || state.busy) return;
    emit(
      ResourceState(
        data: NearbyServicesScreenModel(
          location: current.location,
          locationLabel: current.locationLabel,
          radiusKm: current.radiusKm,
          query: query ?? current.query,
          type: type,
          services: current.services,
          categoryRadii: current.categoryRadii,
        ),
      ),
    );
  }

  /// Clear public entry point for the explicit Near me action.
  Future<void> refreshNearMe() => loadNearby();

  Future<void> openSettings() =>
      state.data?.location.status ==
          DeviceLocationStatus.permissionDeniedForever
      ? locationService.openAppSettings()
      : locationService.openSettings();
}
