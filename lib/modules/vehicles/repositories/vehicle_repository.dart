import '../../../utils/services/supabase_service.dart';
import '../models/vehicle_model.dart';
import 'vehicle_repository_interface.dart';

class VehicleRepository implements IVehicleRepository {
  VehicleRepository(this.service);
  final SupabaseService service;
  @override
  Future<List<VehicleModel>> list() async =>
      (await service.callNext('vehicles.list') as List)
          .map((row) => VehicleModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
  @override
  Future<VehicleModel> save(VehicleDraft draft) async => VehicleModel.fromJson(
    Map<String, dynamic>.from(
      await service.callNext('vehicles.save', draft.toJson()),
    ),
  );
}
