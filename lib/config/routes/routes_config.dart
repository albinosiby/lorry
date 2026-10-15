import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../di/injection.dart';
import '../../design_system/design_system.dart';
import '../../design_system/layouts/adaptive_scaffold.dart';
import '../../modules/auth/cubit/session_cubit.dart';
import '../../modules/auth/cubit/auth_form_cubit.dart';
import '../../modules/auth/models/auth_models.dart';
import '../../modules/auth/screens/auth_screen.dart';
import '../../modules/auth/screens/welcome_screen.dart';
import '../../modules/profile/models/profile_model.dart';
import '../../modules/profile/cubit/profile_cubit.dart';
import '../../modules/profile/screens/profile_screen.dart';
import '../../modules/home/cubit/home_cubit.dart';
import '../../modules/home/screens/home_screen.dart';
import '../../modules/loads/cubit/loads_cubit.dart';
import '../../modules/loads/cubit/load_form_cubit.dart';
import '../../modules/loads/cubit/load_details_cubit.dart';
import '../../modules/loads/screens/loads_screen.dart';
import '../../modules/loads/screens/load_form_screen.dart';
import '../../modules/loads/screens/load_details_screen.dart';
import '../../modules/bookings/cubit/trips_cubit.dart';
import '../../modules/bookings/cubit/booking_details_cubit.dart';
import '../../modules/bookings/screens/trips_screen.dart';
import '../../modules/bookings/screens/booking_details_screen.dart';
import '../../modules/notifications/cubit/notifications_cubit.dart';
import '../../modules/notifications/screens/notifications_screen.dart';
import '../../modules/nearby_services/cubit/nearby_services_cubit.dart';
import '../../modules/nearby_services/screens/nearby_services_screen.dart';
import '../../modules/vehicles/cubit/vehicles_cubit.dart';
import '../../modules/vehicles/screens/vehicles_screen.dart';
import '../../modules/vehicles/screens/vehicle_details_screen.dart';
import '../../modules/driver_documents/cubit/driver_documents_cubit.dart';
import '../../modules/driver_documents/screens/driver_documents_screen.dart';
import '../../modules/availability/cubit/availability_cubit.dart';
import '../../modules/availability/screens/availability_screen.dart';
import '../../modules/finance/cubit/finance_cubit.dart';
import '../../modules/finance/screens/finance_screen.dart';
import '../../modules/verification/cubit/profile_documents_cubit.dart';
import '../../modules/verification/screens/verification_screen.dart';
import '../../modules/customer_trucks/cubit/customer_trucks_cubit.dart';
import '../../modules/customer_trucks/screens/customer_trucks_screen.dart';
import '../../modules/tracking/cubit/trip_tracking_cubit.dart';
import '../../modules/tracking/screens/trip_tracking_screen.dart';
import '../../modules/account/screens/account_resources_screen.dart';
import 'routes.dart';

class RouterRefresh extends ChangeNotifier {
  RouterRefresh(SessionCubit session) {
    _subscription = session.stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<SessionModel> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

String? sessionRedirect(SessionModel session, Uri uri) {
  final path = uri.path;
  const publicPaths = [
    '/welcome',
    '/sign-in',
    '/sign-up',
    '/forgot-password',
    '/auth/callback',
  ];
  final isPublic = publicPaths.contains(path);
  if (session.status == SessionStatus.loading ||
      session.status == SessionStatus.failure) {
    return path == '/startup'
        ? null
        : '/startup?from=${Uri.encodeComponent(uri.toString())}';
  }
  if (session.status == SessionStatus.signedOut) {
    if (isPublic) return null;
    final from = uri.queryParameters['from'] ?? uri.toString();
    return '/sign-in?from=${Uri.encodeComponent(from)}';
  }
  if (session.status == SessionStatus.recovery) {
    return path == Routes.reset ? null : Routes.reset;
  }
  if (session.status == SessionStatus.setup) {
    return path == Routes.setup ? null : Routes.setup;
  }
  final profile = session.profile;
  if (profile == null || profile.needsSetup) {
    return path == Routes.setup ? null : Routes.setup;
  }
  final driver = session.profile?.role == UserRole.driver;
  final parts = uri.pathSegments;
  if (parts.length >= 2 &&
      (parts[0] == 'bookings' ||
          (parts[0] == 'loads' &&
              !['new', 'find', 'mine'].contains(parts[1])))) {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(parts[1])) {
      return '/not-found';
    }
  }

  if (isPublic ||
      [
        '/startup',
        '/complete-profile',
        '/reset-password',
        '/',
      ].contains(path)) {
    final from = uri.queryParameters['from'];
    if (from != null && from.startsWith('/') && !from.startsWith('//')) {
      final target = Uri.tryParse(from);
      if (target != null &&
          !publicPaths.contains(target.path) &&
          ![
            '/startup',
            '/complete-profile',
            '/reset-password',
            '/',
          ].contains(target.path)) {
        return from;
      }
    }
    return Routes.home;
  }
  if (driver &&
      (path == Routes.postLoad ||
          path == Routes.myLoads ||
          path.endsWith('/edit') ||
          path.endsWith('/requests') ||
          path == '/requests')) {
    return Routes.findLoads;
  }
  if (!driver && (path == Routes.findLoads || path == Routes.trips)) {
    return Routes.myLoads;
  }
  return null;
}

GoRouter createRouter(SessionCubit session, RouterRefresh refresh) => GoRouter(
  initialLocation: Routes.welcome,
  refreshListenable: refresh,
  redirect: (context, state) => sessionRedirect(session.state, state.uri),
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Page unavailable')),
    body: AppEmptyState(
      'This page is unavailable',
      'The link may be incomplete or no longer available.',
      action: AppButton(
        label: 'Go home',
        onPressed: () => context.go(Routes.home),
      ),
    ),
  ),
  routes: [
    GoRoute(
      path: '/startup',
      builder: (context, state) => Scaffold(
        body: Center(
          child: BlocBuilder<SessionCubit, SessionModel>(
            builder: (context, state) => state.error == null
                ? const CircularProgressIndicator()
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ErrorPanel(state.error!, retry: session.refresh),
                        TextButton(
                          onPressed: () => session.repository.signOut(),
                          child: const Text('Back to sign in'),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/auth/callback',
      builder: (context, state) =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
    ),
    GoRoute(
      path: Routes.welcome,
      builder: (context, state) => const WelcomeScreen(),
    ),
    for (final entry in {
      Routes.signIn: AuthScreenMode.signIn,
      Routes.signUp: AuthScreenMode.signUp,
      Routes.forgot: AuthScreenMode.forgot,
      Routes.reset: AuthScreenMode.reset,
    }.entries)
      GoRoute(
        path: entry.key,
        builder: (context, state) => BlocProvider(
          create: (_) => di<AuthFormCubit>(),
          child: AuthScreen(mode: entry.value),
        ),
      ),
    GoRoute(
      path: Routes.setup,
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => di<ProfileCubit>()..load()),
          BlocProvider(create: (_) => di<ProfileDocumentsCubit>()),
        ],
        child: const ProfileScreen(setup: true),
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AdaptiveScaffold(
        key: ValueKey(session.state.profile?.id),
        shell: shell,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.home,
              builder: (context, state) => MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (_) => di<HomeCubit>()
                      ..load(
                        includeDriverTools:
                            session.state.profile?.role == UserRole.driver,
                      ),
                  ),
                  BlocProvider(create: (_) => di<BookingDetailsCubit>()),
                ],
                child: const HomeScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.postLoad,
              builder: (context, state) => BlocProvider(
                create: (_) => di<LoadFormCubit>(),
                child: const LoadFormScreen(),
              ),
            ),
            GoRoute(
              path: Routes.findLoads,
              builder: (context, state) => BlocProvider(
                create: (_) => di<LoadsCubit>()..load(),
                child: const LoadsScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.myLoads,
              builder: (context, state) => BlocProvider(
                create: (_) => di<LoadsCubit>()..load(mine: true),
                child: const LoadsScreen(mine: true),
              ),
            ),
            GoRoute(
              path: Routes.trips,
              builder: (context, state) => BlocProvider(
                create: (_) => di<TripsCubit>()..load(),
                child: const TripsScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.profile,
              builder: (context, state) => BlocProvider(
                create: (_) => di<ProfileCubit>()..load(),
                child: const ProfileScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/loads/:loadId',
      builder: (context, state) {
        final id = state.pathParameters['loadId']!;
        return BlocProvider(
          create: (_) => di<LoadDetailsCubit>()..load(id),
          child: LoadDetailsScreen(id: id),
        );
      },
      routes: [
        GoRoute(
          path: 'edit',
          builder: (context, state) {
            final id = state.pathParameters['loadId']!;
            return BlocProvider(
              create: (_) => di<LoadFormCubit>()..load(id),
              child: LoadFormScreen(id: id),
            );
          },
        ),
        GoRoute(
          path: 'requests',
          builder: (context, state) {
            final id = state.pathParameters['loadId']!;
            return BlocProvider(
              create: (_) =>
                  di<TripsCubit>()..load(loadId: id, status: 'requested'),
              child: TripsScreen(loadId: id, requests: true),
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/requests',
      builder: (context, state) => BlocProvider(
        create: (_) => di<TripsCubit>()..load(status: 'requested'),
        child: const TripsScreen(requests: true),
      ),
    ),
    GoRoute(
      path: '/bookings/:bookingId',
      builder: (context, state) {
        final id = state.pathParameters['bookingId']!;
        return BlocProvider(
          create: (_) => di<BookingDetailsCubit>()..load(id),
          child: BookingDetailsScreen(id: id),
        );
      },
    ),
    GoRoute(
      path: Routes.legal,
      builder: (_, _) =>
          const AccountResourcesScreen(resource: AccountResource.legal),
    ),
    GoRoute(
      path: Routes.support,
      builder: (_, _) =>
          const AccountResourcesScreen(resource: AccountResource.support),
    ),
    GoRoute(
      path: '${Routes.tracking}/:bookingId',
      builder: (context, state) => BlocProvider(
        create: (_) =>
            di<TripTrackingCubit>()..load(state.pathParameters['bookingId']!),
        child: TripTrackingScreen(
          bookingId: state.pathParameters['bookingId']!,
        ),
      ),
    ),
    GoRoute(
      path: Routes.availableTrucks,
      builder: (context, state) => BlocProvider(
        create: (_) => di<CustomerTrucksCubit>()..load(),
        child: const CustomerTrucksScreen(),
      ),
    ),
    GoRoute(
      path: Routes.verification,
      builder: (context, state) => BlocProvider(
        create: (_) => di<ProfileDocumentsCubit>()..load(),
        child: const VerificationScreen(),
      ),
    ),
    GoRoute(
      path: Routes.notifications,
      builder: (context, state) => BlocProvider(
        create: (_) => di<NotificationsCubit>()..load(),
        child: const NotificationsScreen(),
      ),
    ),
    GoRoute(
      path: Routes.nearbyServices,
      builder: (context, state) => BlocProvider(
        create: (_) => di<NearbyServicesCubit>(),
        child: const NearbyServicesScreen(),
      ),
    ),
    GoRoute(
      path: Routes.vehicles,
      builder: (context, state) => BlocProvider(
        create: (_) => di<VehiclesCubit>()..load(),
        child: const VehiclesScreen(),
      ),
    ),
    GoRoute(
      path: '${Routes.vehicles}/:vehicleId',
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => di<VehiclesCubit>()..load()),
          BlocProvider(create: (_) => di<DriverDocumentsCubit>()..load()),
        ],
        child: VehicleDetailsScreen(
          vehicleId: state.pathParameters['vehicleId']!,
        ),
      ),
    ),
    GoRoute(
      path: Routes.driverDocuments,
      builder: (context, state) => BlocProvider(
        create: (_) => di<DriverDocumentsCubit>()..load(),
        child: DriverDocumentsScreen(
          identityOnly: state.uri.queryParameters['identity'] == 'true',
        ),
      ),
    ),
    GoRoute(
      path: Routes.availability,
      builder: (context, state) => BlocProvider(
        create: (_) => di<AvailabilityCubit>()..load(),
        child: const AvailabilityScreen(),
      ),
    ),
    GoRoute(
      path: Routes.finance,
      builder: (context, state) => BlocProvider(
        create: (_) => di<FinanceCubit>()..load(),
        child: const FinanceScreen(),
      ),
    ),
  ],
);
