import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../bookings/repositories/booking_repository_interface.dart';
import '../models/load_screen_models.dart';
import '../repositories/load_repository_interface.dart';
import '../../vehicles/repositories/vehicle_repository_interface.dart';
import '../../vehicles/models/vehicle_model.dart';
import '../models/load_model.dart';

class LoadDetailsCubit extends ResourceCubit<LoadDetailsModel> {
  LoadDetailsCubit(this.repository, this.bookings, {this.vehicles});
  final IVehicleRepository? vehicles;
  Future<List<VehicleModel>> matchingTrucks(LoadModel load) async =>
      (await vehicles?.list() ?? <VehicleModel>[])
          .where(
            (v) =>
                v.capacityTonnes >= load.weightTonnes &&
                v.lengthFt >= (load.requiredVehicleLengthFt ?? 0) &&
                (v.vehicleType.toLowerCase() == load.vehicle.toLowerCase() ||
                    v.bodyType.toLowerCase() == load.vehicle.toLowerCase()),
          )
          .toList();
  final ILoadRepository repository;
  final IBookingRepository bookings;
  Future<bool> callContact(String phone) =>
      act(() => repository.callContact(phone));
  Future<void> load(String id) => fetch(() => repository.get(id));
  Future<bool> cancel(String id) =>
      act(() => repository.cancel(id), notice: 'Load cancelled.');
  String? requestedBookingId;
  Future<bool> request(String id, {String? vehicleId}) => act(() async {
    requestedBookingId = await bookings.request(id, vehicleId: vehicleId);
  }, notice: 'Booking requested.');
}
