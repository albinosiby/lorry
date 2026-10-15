import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../loads/repositories/load_repository_interface.dart';
import '../../../utils/services/location_service.dart';
import '../models/customer_trucks_screen_model.dart';
import '../repositories/customer_trucks_repository_interface.dart';

class CustomerTrucksCubit extends ResourceCubit<CustomerTrucksScreenModel> {
  CustomerTrucksCubit(this.repository, this.loads, this.locationService);
  final ICustomerTrucksRepository repository;
  final ILoadRepository loads;
  final ILocationService locationService;
  String _query = '', _sort = 'nearest';
  String? _loadId, _vehicleType;
  double? _minCapacityTonnes, _latitude, _longitude;
  double _radiusKm = 50;

  Future<void> load({
    String? query,
    String? loadId,
    String? vehicleType,
    double? minCapacityTonnes,
    double? latitude,
    double? longitude,
    double? radiusKm,
    String? sort,
    bool clearLoad = false,
    bool clearVehicleType = false,
    bool clearMinCapacity = false,
    bool clearLocation = false,
  }) async {
    _query = query ?? _query;
    _loadId = clearLoad ? null : loadId ?? _loadId;
    _vehicleType = clearVehicleType ? null : vehicleType ?? _vehicleType;
    _minCapacityTonnes = clearMinCapacity
        ? null
        : minCapacityTonnes ?? _minCapacityTonnes;
    if (clearLocation) {
      _latitude = null;
      _longitude = null;
    } else {
      _latitude = latitude ?? _latitude;
      _longitude = longitude ?? _longitude;
    }
    _radiusKm = radiusKm ?? _radiusKm;
    _sort = sort ?? _sort;
    await fetch(() async {
      final trucks = await repository.list(
        query: _query,
        loadId: _loadId,
        vehicleType: _vehicleType,
        minCapacityTonnes: _minCapacityTonnes,
        latitude: _latitude,
        longitude: _longitude,
        radiusKm: _radiusKm,
        sort: _sort,
      );
      final ownLoads = await loads.list(mine: true);
      return CustomerTrucksScreenModel(
        trucks: trucks,
        openLoads: ownLoads.where((load) => load.status == 'open').toList(),
        query: _query,
        sort: _sort,
      );
    });
  }

  Future<DeviceLocation> currentLocation() => locationService.current();

  Future<bool> invite({
    required String availabilityId,
    required String loadId,
  }) => act(() async {
    await repository.invite(availabilityId: availabilityId, loadId: loadId);
  }, notice: 'Truck invitation sent. The driver must accept it.');
}
