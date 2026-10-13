import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/services/supabase_service.dart';
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

final di = GetIt.instance;
void configureDependencies(SupabaseClient client) {
  di.registerLazySingleton(() => SupabaseService(client));
  di.registerLazySingleton<IAuthRepository>(() => AuthRepository(di()));
  di.registerLazySingleton<IProfileRepository>(() => ProfileRepository(di()));
  di.registerLazySingleton<ILoadRepository>(() => LoadRepository(di()));
  di.registerLazySingleton<IBookingRepository>(() => BookingRepository(di()));
  di.registerLazySingleton<IHomeRepository>(() => HomeRepository(di()));
  di.registerLazySingleton<INotificationRepository>(
    () => NotificationRepository(di()),
  );
  configureCubits();
}

void configureCubits() {
  di.registerFactory(() => SessionCubit(di()));
  di.registerFactory(() => AuthFormCubit(di()));
  di.registerFactory(() => ProfileCubit(di(), di()));
  di.registerFactory(() => LoadsCubit(di()));
  di.registerFactory(() => LoadDetailsCubit(di(), di()));
  di.registerFactory(() => LoadFormCubit(di()));
  di.registerFactory(() => TripsCubit(di()));
  di.registerFactory(() => BookingDetailsCubit(di()));
  di.registerFactory(() => HomeCubit(di()));
  di.registerFactory(() => NotificationsCubit(di()));
}
