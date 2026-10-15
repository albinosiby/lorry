import '../models/truck_availability_model.dart';

abstract interface class IAvailabilityRepository {
  Future<List<TruckAvailabilityModel>> list({bool mine = true});
  Future<TruckAvailabilityModel> save(AvailabilityDraft draft);
  Future<void> close(String id);
}
