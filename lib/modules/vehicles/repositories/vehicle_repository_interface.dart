import '../models/vehicle_model.dart';

abstract interface class IVehicleRepository {
  Future<List<VehicleModel>> list();
  Future<VehicleModel> save(VehicleDraft draft);
}
