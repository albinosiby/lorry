import '../../vehicles/models/vehicle_model.dart';
import 'truck_availability_model.dart';

class AvailabilityScreenModel {
  const AvailabilityScreenModel({required this.posts, required this.vehicles});
  final List<TruckAvailabilityModel> posts;
  final List<VehicleModel> vehicles;
}
