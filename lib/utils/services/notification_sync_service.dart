import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String? notificationRoute(Map<String, dynamic> data, String profileId) {
  if (data['recipient_id'] != profileId) return null;
  final id = data['booking_id']?.toString();
  if (id != null &&
      RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(id)) {
    return '/bookings/$id';
  }
  return '/notifications';
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Android displays the notification payload itself in the background.
}

class NotificationSyncService {
  NotificationSyncService(this.client);
  final SupabaseClient client;
  final _local = FlutterLocalNotificationsPlugin();
  final _opens = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get opens => _opens.stream;
  Map<String, dynamic>? _pendingOpen;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foreground, _opened;
  RealtimeChannel? _realtime;
  String? _profileId, _token;
  bool _ready = false;
  int _generation = 0;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> initializeFirebase() async {
    if (!supported) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (_) {
      debugPrint('Firebase notifications could not initialize.');
    }
  }

  Map<String, dynamic>? takePendingOpen() {
    final value = _pendingOpen;
    _pendingOpen = null;
    return value;
  }

  void _open(Map<String, dynamic> data) {
    _pendingOpen = data;
    _opens.add(data);
  }

  Future<void> initialize() async {
    if (_ready || !supported || Firebase.apps.isEmpty) return;
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) {
          _open(Map<String, dynamic>.from(jsonDecode(payload)));
        }
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'lorry_link_updates',
            'LORRY LINK updates',
            description: 'Booking and shipment updates',
            importance: Importance.high,
          ),
        );
    _foreground = FirebaseMessaging.onMessage.listen((message) {
      if (_profileId == null || message.data['recipient_id'] != _profileId) {
        return;
      }
      unawaited(_show(message));
    });
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _open(message.data),
    );
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _open(initial.data);
    final localInitial = await _local.getNotificationAppLaunchDetails();
    final payload = localInitial?.notificationResponse?.payload;
    if (localInitial?.didNotificationLaunchApp == true && payload != null) {
      _open(Map<String, dynamic>.from(jsonDecode(payload)));
    }
    _ready = true;
  }

  Future<void> start(String profileId) async {
    if (!supported || profileId == _profileId) return;
    final generation = ++_generation;
    _profileId = profileId;
    try {
      await initialize();
      if (!_ready || generation != _generation) return;
      final permission = await FirebaseMessaging.instance.requestPermission();
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        _profileId = null;
        return;
      }
      final oldChannel = _realtime;
      if (oldChannel != null) await client.removeChannel(oldChannel);
      _realtime = client
          .channel('app-notifications-$profileId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'recipient_id',
              value: profileId,
            ),
            callback: (payload) {
              if (WidgetsBinding.instance.lifecycleState !=
                      AppLifecycleState.resumed ||
                  client.auth.currentUser?.id != profileId) {
                return;
              }
              final row = payload.newRecord;
              unawaited(
                _show(
                  RemoteMessage(
                    data: {...row, 'notification_id': row['id']},
                    notification: RemoteNotification(
                      title: row['title']?.toString(),
                      body: row['body']?.toString(),
                    ),
                  ),
                ),
              );
            },
          )
          .subscribe();
      await _tokenRefresh?.cancel();
      _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        unawaited(_register(token, profileId, generation));
      });
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _register(token, profileId, generation);
    } catch (_) {
      _profileId = null;
      debugPrint(
        'Push registration failed; it will retry when the app resumes.',
      );
    }
  }

  Future<void> _register(String token, String profileId, int generation) async {
    if (generation != _generation || client.auth.currentUser?.id != profileId) {
      return;
    }
    try {
      await client.rpc('register_push_token', params: {'device_token': token});
      if (generation == _generation) _token = token;
    } catch (_) {
      _profileId = null;
      debugPrint('Could not save push registration.');
    }
  }

  Future<void> unregister() async {
    final token = _token;
    if (supported && Firebase.apps.isNotEmpty) {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {
        debugPrint('Could not invalidate the Firebase device token.');
      }
    }
    if (token != null && client.auth.currentUser != null) {
      try {
        await client.rpc('remove_push_token', params: {'device_token': token});
      } catch (_) {
        debugPrint('Could not remove the server push registration.');
      }
    }
    _token = null;
    await stop();
  }

  Future<void> stop() async {
    ++_generation;
    _profileId = null;
    await _tokenRefresh?.cancel();
    _tokenRefresh = null;
    final channel = _realtime;
    _realtime = null;
    if (channel != null) await client.removeChannel(channel);
  }

  Future<void> dispose() async {
    await stop();
    await _foreground?.cancel();
    await _opened?.cancel();
    await _opens.close();
  }

  Future<void> _show(RemoteMessage message) async {
    if (!_ready) return;
    await _local.show(
      id:
          (message.data['notification_id'] ?? message.messageId ?? '')
              .hashCode &
          0x7fffffff,
      title: message.notification?.title ?? 'LORRY LINK update',
      body: message.notification?.body,
      payload: jsonEncode(message.data),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'lorry_link_updates',
          'LORRY LINK updates',
          importance: Importance.high,
          priority: Priority.high,
          onlyAlertOnce: true,
        ),
      ),
    );
  }
}
