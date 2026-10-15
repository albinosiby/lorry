import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../../utils/services/location_service.dart';
import '../../vehicles/repositories/vehicle_repository_interface.dart';
import '../models/availability_screen_model.dart';
import '../models/truck_availability_model.dart';
import '../repositories/availability_repository_interface.dart';

class AvailabilityCubit extends ResourceCubit<AvailabilityScreenModel> {
  AvailabilityCubit(this.repository, this.vehicles, this.locationService);
  final IAvailabilityRepository repository;
  final IVehicleRepository vehicles;
  final ILocationService locationService;
  Future<void> load() => fetch(
    () async => AvailabilityScreenModel(
      posts: await repository.list(),
      vehicles: await vehicles.list(),
    ),
  );
  Future<bool> save(AvailabilityDraft draft) => act(() async {
    await repository.save(draft);
    await load();
  }, notice: 'Truck availability is live.');
  Future<bool> closePost(String id) => act(() async {
    await repository.close(id);
    await load();
  }, notice: 'Availability post closed.');

  Future<DeviceLocation> currentLocation() => locationService.current();
}
