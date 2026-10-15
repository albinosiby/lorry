import '../models/customer_truck_model.dart';

abstract interface class ICustomerTrucksRepository {
  Future<List<CustomerTruckModel>> list({
    String query = '',
    String? loadId,
    String? vehicleType,
    double? minCapacityTonnes,
    double? latitude,
    double? longitude,
    double radiusKm = 50,
    String sort = 'nearest',
  });
  Future<void> invite({required String availabilityId, required String loadId});
}
