import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'config/routes/routes_config.dart';
import 'di/injection.dart';
import 'design_system/design_system.dart';
import 'modules/auth/cubit/session_cubit.dart';
import 'modules/auth/models/auth_models.dart';
import 'utils/services/notification_sync_service.dart';

class LorryLinkApp extends StatefulWidget {
  const LorryLinkApp({super.key});
  @override
  State<LorryLinkApp> createState() => _LorryLinkAppState();
}

class _LorryLinkAppState extends State<LorryLinkApp>
    with WidgetsBindingObserver {
  late final SessionCubit session;
  late final RouterRefresh refresh;
  late final GoRouter router;
  StreamSubscription<SessionModel>? notificationSubscription;
  StreamSubscription<Map<String, dynamic>>? notificationOpens;

  void openNotification(Map<String, dynamic> data) {
    final profile = session.state.profile;
    if (session.state.status != SessionStatus.ready ||
        profile == null ||
        profile.needsSetup) {
      return;
    }
    di<NotificationSyncService>().takePendingOpen();
    final route = notificationRoute(data, profile.id);
    if (route != null) router.push(route);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session = di<SessionCubit>();
    refresh = RouterRefresh(session);
    router = createRouter(session, refresh);
    if (di.isRegistered<NotificationSyncService>()) {
      notificationOpens = di<NotificationSyncService>().opens.listen(
        openNotification,
      );
      notificationSubscription = session.stream.listen((state) {
        final profile = state.profile;
        if (state.status == SessionStatus.ready && profile != null) {
          di<NotificationSyncService>().start(profile.id);
          if (!profile.needsSetup) {
            final pending = di<NotificationSyncService>().takePendingOpen();
            if (pending != null) openNotification(pending);
          }
        } else {
          di<NotificationSyncService>().stop();
        }
      });
    }
    session.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    router.dispose();
    refresh.dispose();
    notificationSubscription?.cancel();
    notificationOpens?.cancel();
    if (di.isRegistered<NotificationSyncService>()) {
      di<NotificationSyncService>().stop();
    }
    session.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final profile = session.state.profile;
    if (state == AppLifecycleState.resumed &&
        profile != null &&
        session.state.status == SessionStatus.ready &&
        di.isRegistered<NotificationSyncService>()) {
      unawaited(di<NotificationSyncService>().start(profile.id));
    }
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: session,
    child: AppSizing(
      builder: () => MaterialApp.router(
        title: 'LORRY LINK',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(Brightness.light),
        themeMode: ThemeMode.light,
        routerConfig: router,
      ),
    ),
  );
}

class AppSizing extends StatelessWidget {
  const AppSizing({super.key, required this.builder});
  final Widget Function() builder;
  @override
  Widget build(BuildContext context) => ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    splitScreenMode: true,
    fontSizeResolver: (size, instance) =>
        size * (instance.screenWidth / 390).clamp(.9, 1.1),
    builder: (context, child) => builder(),
  );
}

class SetupApp extends StatelessWidget {
  const SetupApp({super.key, this.error});
  final String? error;
  @override
  Widget build(BuildContext context) => AppSizing(
    builder: () => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LORRY LINK',
      theme: AppTheme.build(Brightness.light),
      home: Scaffold(
        body: PageBody(
          narrow: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              const Brand(large: true),
              const SizedBox(height: 48),
              const Icon(
                Icons.settings_input_component_rounded,
                size: 64,
                color: AppTheme.green,
              ),
              const SizedBox(height: 24),
              Text(
                error == null
                    ? 'Connect your Supabase project'
                    : 'Connection setup needs attention',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                error ??
                    'The app is installed. Add your project URL and publishable key to the local configuration to connect authentication, loads and bookings.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: SelectableText(
                    '1. Follow docs/SUPABASE_SETUP.md\n2. Copy config/supabase.example.json to config/supabase.local.json\n3. Run with --dart-define-from-file=config/supabase.local.json',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No demo records or placeholder sessions are used.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
