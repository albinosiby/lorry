import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/services/supabase_service.dart';
import '../utils/services/location_service.dart';
import '../utils/services/location_label_service.dart';
import '../utils/services/place_search_service.dart';
import '../utils/services/notification_sync_service.dart';
import '../utils/services/trip_location_sharing_service.dart';
import '../modules/auth/repositories/auth_repository.dart';
import '../modules/auth/repositories/auth_repository_interface.dart';
import '../modules/auth/cubit/auth_form_cubit.dart';
import '../modules/auth/cubit/session_cubit.dart';
import '../modules/profile/repositories/profile_repository.dart';
import '../modules/profile/repositories/profile_repository_interface.dart';
import '../modules/profile/cubit/profile_cubit.dart';
import '../modules/home/repositories/home_repository.dart';
import '../modules/home/repositories/home_repository_interface.dart';
import '../modules/home/cubit/home_cubit.dart';
import '../modules/loads/repositories/load_repository.dart';
import '../modules/loads/repositories/load_repository_interface.dart';
import '../modules/loads/cubit/loads_cubit.dart';
import '../modules/loads/cubit/load_details_cubit.dart';
import '../modules/loads/cubit/load_form_cubit.dart';
import '../modules/bookings/repositories/booking_repository.dart';
import '../modules/bookings/repositories/booking_repository_interface.dart';
import '../modules/bookings/cubit/trips_cubit.dart';
import '../modules/bookings/cubit/booking_details_cubit.dart';
import '../modules/notifications/repositories/notification_repository.dart';
import '../modules/notifications/repositories/notification_repository_interface.dart';
import '../modules/notifications/cubit/notifications_cubit.dart';
import '../modules/nearby_services/repositories/nearby_services_repository.dart';
import '../modules/nearby_services/repositories/nearby_services_repository_interface.dart';
import '../modules/nearby_services/cubit/nearby_services_cubit.dart';
import '../modules/vehicles/repositories/vehicle_repository.dart';
import '../modules/vehicles/repositories/vehicle_repository_interface.dart';
import '../modules/vehicles/cubit/vehicles_cubit.dart';
import '../modules/driver_documents/repositories/driver_documents_repository.dart';
import '../modules/driver_documents/repositories/driver_documents_repository_interface.dart';
import '../modules/driver_documents/cubit/driver_documents_cubit.dart';
import '../modules/availability/repositories/availability_repository.dart';
import '../modules/availability/repositories/availability_repository_interface.dart';
import '../modules/availability/cubit/availability_cubit.dart';
import '../modules/finance/repositories/finance_repository.dart';
import '../modules/finance/repositories/finance_repository_interface.dart';
import '../modules/finance/cubit/finance_cubit.dart';
import '../modules/verification/repositories/profile_documents_repository.dart';
import '../modules/verification/repositories/profile_documents_repository_interface.dart';
import '../modules/verification/cubit/profile_documents_cubit.dart';
import '../modules/customer_trucks/repositories/customer_trucks_repository.dart';
import '../modules/customer_trucks/repositories/customer_trucks_repository_interface.dart';
import '../modules/customer_trucks/cubit/customer_trucks_cubit.dart';
import '../modules/tracking/repositories/trip_tracking_repository.dart';
import '../modules/tracking/repositories/trip_tracking_repository_interface.dart';
import '../modules/tracking/cubit/trip_tracking_cubit.dart';

final di = GetIt.instance;
void configureDependencies(SupabaseClient client) {
  di.registerLazySingleton(() => SupabaseService(client));
  di.registerLazySingleton<ILocationService>(() => LocationService());
  di.registerLazySingleton<IPlaceSearchService>(() => PlaceSearchService());
  di.registerLazySingleton<NotificationSyncService>(
    () => NotificationSyncService(client),
  );
  di.registerLazySingleton<IAuthRepository>(
    () => AuthRepository(di(), di<NotificationSyncService>()),
  );
  di.registerLazySingleton<IProfileRepository>(() => ProfileRepository(di()));
  di.registerLazySingleton<ILoadRepository>(() => LoadRepository(di()));
  di.registerLazySingleton<IBookingRepository>(() => BookingRepository(di()));
  di.registerLazySingleton<IHomeRepository>(() => HomeRepository(di()));
  di.registerLazySingleton<INotificationRepository>(
    () => NotificationRepository(di()),
  );
  di.registerLazySingleton<INearbyServicesRepository>(
    () => NearbyServicesRepository(di()),
  );
  di.registerLazySingleton<IVehicleRepository>(() => VehicleRepository(di()));
  di.registerLazySingleton<IDriverDocumentsRepository>(
    () => DriverDocumentsRepository(di()),
  );
  di.registerLazySingleton<IAvailabilityRepository>(
    () => AvailabilityRepository(di()),
  );
  di.registerLazySingleton<IFinanceRepository>(() => FinanceRepository(di()));
  di.registerLazySingleton<IProfileDocumentsRepository>(
    () => ProfileDocumentsRepository(di()),
  );
  di.registerLazySingleton<ICustomerTrucksRepository>(
    () => CustomerTrucksRepository(di()),
  );
  di.registerLazySingleton<ITripTrackingRepository>(
    () => TripTrackingRepository(di()),
  );
  configureCubits();
  di.registerLazySingleton(
    () => TripLocationSharingService(di(), di(), di(), di()),
  );
}

void configureCubits() {
  di.registerFactory(() => SessionCubit(di()));
  di.registerFactory(() => AuthFormCubit(di()));
  di.registerFactory(() => ProfileCubit(di(), di()));
  di.registerFactory(() => LoadsCubit(di()));
  di.registerFactory(() => LoadDetailsCubit(di(), di()));
  di.registerFactory(() => LoadFormCubit(di(), di()));
  di.registerFactory(() => TripsCubit(di()));
  di.registerFactory(
    () => BookingDetailsCubit(
      di(),
      di(),
      onTripStarted: () => di<TripLocationSharingService>().sync(),
    ),
  );
  di.registerFactory(() => HomeCubit(di(), di(), di()));
  di.registerFactory(() => NotificationsCubit(di()));
  di.registerFactory(
    () => NearbyServicesCubit(
      di(),
      di(),
      resolveLocationLabel: LocationLabelService().describe,
    ),
  );
  di.registerFactory(() => VehiclesCubit(di()));
  di.registerFactory(() => DriverDocumentsCubit(di(), di()));
  di.registerFactory(() => AvailabilityCubit(di(), di(), di()));
  di.registerFactory(() => FinanceCubit(di()));
  di.registerFactory(() => ProfileDocumentsCubit(di()));
  di.registerFactory(() => CustomerTrucksCubit(di(), di(), di()));
  di.registerFactory(() => TripTrackingCubit(di(), di()));
}
