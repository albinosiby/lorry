import '../../../utils/services/supabase_service.dart';
import '../models/truck_availability_model.dart';
import 'availability_repository_interface.dart';

class AvailabilityRepository implements IAvailabilityRepository {
  AvailabilityRepository(this.service);
  final SupabaseService service;
  @override
  Future<List<TruckAvailabilityModel>> list({bool mine = true}) async =>
      (await service.callNext('availability.list', {'mine': mine}) as List)
          .map(
            (row) =>
                TruckAvailabilityModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();
  @override
  Future<TruckAvailabilityModel> save(AvailabilityDraft draft) async =>
      TruckAvailabilityModel.fromJson(
        Map<String, dynamic>.from(
          await service.callNext('availability.save', draft.toJson()),
        ),
      );
  @override
  Future<void> close(String id) async {
    await service.callNext('availability.close', {'id': id});
  }
}
