import '../../../utils/services/supabase_service.dart';
import '../models/customer_truck_model.dart';
import 'customer_trucks_repository_interface.dart';

class CustomerTrucksRepository implements ICustomerTrucksRepository {
  CustomerTrucksRepository(this.service);
  final SupabaseService service;

  @override
  Future<List<CustomerTruckModel>> list({
    String query = '',
    String? loadId,
    String? vehicleType,
    double? minCapacityTonnes,
    double? latitude,
    double? longitude,
    double radiusKm = 50,
    String sort = 'nearest',
  }) async =>
      (await service.callCustomer('customer.trucks.list', {
                'query': query.trim(),
                'load_id': loadId,
                'vehicle_type': vehicleType,
                'min_capacity_tonnes': minCapacityTonnes,
                'latitude': latitude,
                'longitude': longitude,
                'radius_km': radiusKm,
                'sort': sort,
              })
              as List)
          .map(
            (row) =>
                CustomerTruckModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();

  @override
  Future<void> invite({
    required String availabilityId,
    required String loadId,
  }) => service.callCustomer('customer.truck.invite', {
    'availability_id': availabilityId,
    'load_id': loadId,
  });
}
