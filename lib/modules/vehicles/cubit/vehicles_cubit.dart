import 'package:lorry_link/core/state/resource_cubit.dart';
import '../models/vehicle_model.dart';
import '../repositories/vehicle_repository_interface.dart';

class VehiclesCubit extends ResourceCubit<List<VehicleModel>> {
  VehiclesCubit(this.repository);
  final IVehicleRepository repository;
  Future<void> load() => fetch(repository.list);
  Future<bool> save(VehicleDraft draft) => act(() async {
    await repository.save(draft);
    await load();
  }, notice: 'Truck saved.');
}
