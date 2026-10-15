import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../../utils/services/location_service.dart';
import '../../../utils/exceptions/app_exception.dart';
import '../models/nearby_service_model.dart';
import '../models/nearby_services_screen_model.dart';
import '../repositories/nearby_services_repository_interface.dart';

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

  Future<void> retryCategory(NearbyServiceType category) async {
    final model = state.data;
    if (model == null ||
        !model.location.available ||
        state.busy ||
        model.loadingCategories.contains(category)) {
      return;
    }
    final generation = _searchGeneration;
    void update({
      List<NearbyServiceModel>? items,
      String? error,
      int? radius,
      required bool loading,
    }) {
      if (isClosed || generation != _searchGeneration) return;
      final current = state.data!;
      final pending = {...current.loadingCategories};
      loading ? pending.add(category) : pending.remove(category);
      final errors = {...current.categoryErrors}..remove(category);
      if (error != null) errors[category] = error;
      emit(
        ResourceState(
          busy: pending.isNotEmpty,
          data: NearbyServicesScreenModel(
            location: current.location,
            radiusKm: 50,
            locationLabel: current.locationLabel,
            query: current.query,
            type: current.type,
            loadingCategories: pending,
            categoryErrors: errors,
            categoryRadii: {...current.categoryRadii, category: ?radius},
            services: items == null
                ? current.services
                : [
                    ...current.services.where((item) => item.type != category),
                    ...items,
                  ],
          ),
        ),
      );
    }

    update(loading: true);
    try {
      for (final radius in [10, 25, 50]) {
        if (isClosed || generation != _searchGeneration) return;
        final items =
            (await repository
                    .search(
                      latitude: model.location.latitude!,
                      longitude: model.location.longitude!,
                      radiusKm: radius,
                      type: category,
                      query: model.query,
                    )
                    .timeout(const Duration(seconds: 60)))
                .where((item) => item.type == category)
                .toList()
              ..sort(
                (a, b) => (a.distanceKm ?? double.infinity).compareTo(
                  b.distanceKm ?? double.infinity,
                ),
              );
        final done = items.length >= 3 || radius == 50;
        update(items: items, radius: radius, loading: !done);
        if (done) break;
      }
    } catch (error) {
      update(error: AppException.from(error).message, loading: false);
    }
  }

  /// Two concurrent categories avoid flooding public providers. Each category
  /// publishes its own result and can fail without hiding successful rows.
  Future<void> discoverSections({
    String query = '',
    NearbyServiceType? type,
  }) async {
    final generation = ++_searchGeneration;
    emit(
      ResourceState(data: state.data, busy: true, loading: state.data == null),
    );
    try {
      final location = await locationService.current().timeout(
        const Duration(seconds: 25),
      );
      if (isClosed || generation != _searchGeneration) return;
      final label = await resolveLocationLabel?.call(location) ?? '';
      if (isClosed || generation != _searchGeneration) return;
      final categories = type == null
          ? NearbyServiceType.values.toList()
          : [type];
      final pending = location.available
          ? categories.toSet()
          : <NearbyServiceType>{};
      final errors = <NearbyServiceType, String>{};
      final radii = <NearbyServiceType, int>{};
      final results = <NearbyServiceType, List<NearbyServiceModel>>{};
      void publish() {
        if (isClosed || generation != _searchGeneration) return;
        emit(
          ResourceState(
            busy: pending.isNotEmpty,
            data: NearbyServicesScreenModel(
              location: location,
              locationLabel: label,
              radiusKm: 50,
              query: query,
              type: type,
              services: results.values.expand((items) => items).toList(),
              loadingCategories: Set.of(pending),
              categoryErrors: Map.of(errors),
              categoryRadii: Map.of(radii),
            ),
          ),
        );
      }

      publish();
      if (!location.available) return;
      var index = 0;
      Future<void> worker() async {
        while (index < categories.length &&
            !isClosed &&
            generation == _searchGeneration) {
          final category = categories[index++];
          try {
            var items = <NearbyServiceModel>[];
            for (final radius in [10, 25, 50]) {
              if (isClosed || generation != _searchGeneration) return;
              radii[category] = radius;
              items = await repository
                  .search(
                    latitude: location.latitude!,
                    longitude: location.longitude!,
                    radiusKm: radius,
                    type: category,
                    query: query,
                  )
                  .timeout(const Duration(seconds: 60));
              items = items.where((item) => item.type == category).toList()
                ..sort(
                  (a, b) => (a.distanceKm ?? double.infinity).compareTo(
                    b.distanceKm ?? double.infinity,
                  ),
                );
              results[category] = items;
              publish();
              if (items.length >= 3) break;
            }
          } catch (error) {
            errors[category] = AppException.from(error).message;
          }
          pending.remove(category);
          publish();
        }
      }

      await Future.wait([worker(), worker()]);
    } catch (error) {
      if (!isClosed && generation == _searchGeneration) {
        emit(
          ResourceState(
            data: state.data,
            error: AppException.from(error).message,
          ),
        );
      }
    }
  }

  Future<void> locateAndSearch({
    int radiusKm = 10,
    NearbyServiceType? type,
    String query = '',
  }) async {
    final generation = ++_searchGeneration;
    NearbyServicesScreenModel? current = state.data;
    emit(ResourceState(data: current, busy: true, loading: current == null));
    try {
      final location = await locationService.current().timeout(
        const Duration(seconds: 25),
      );
      if (isClosed || generation != _searchGeneration) return;
      final label = await resolveLocationLabel?.call(location) ?? '';
      if (isClosed || generation != _searchGeneration) return;
      current = NearbyServicesScreenModel(
        location: location,
        radiusKm: radiusKm,
        type: type,
        query: query,
        services: const [],
        locationLabel: label,
      );
      emit(ResourceState(data: current, busy: location.available));
      if (!location.available) return;
      final services = await repository
          .search(
            latitude: location.latitude!,
            longitude: location.longitude!,
            radiusKm: radiusKm,
            type: type,
            query: query,
          )
          .timeout(const Duration(seconds: 60));
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
            radiusKm: radiusKm,
            type: type,
            query: query,
            services: services,
            locationLabel: label,
          ),
        ),
      );
    } catch (error) {
      if (!isClosed && generation == _searchGeneration) {
        emit(
          ResourceState(data: current, error: AppException.from(error).message),
        );
      }
    }
  }

  Future<void> openSettings() =>
      state.data?.location.status ==
          DeviceLocationStatus.permissionDeniedForever
      ? locationService.openAppSettings()
      : locationService.openSettings();
}
