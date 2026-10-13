import 'dart:async';
import 'package:lorry_link/di/injection.dart';
import 'package:lorry_link/modules/auth/models/auth_models.dart';
import 'package:lorry_link/modules/auth/repositories/auth_repository_interface.dart';
import 'package:lorry_link/modules/profile/models/profile_model.dart';
import 'package:lorry_link/modules/profile/repositories/profile_repository_interface.dart';
import 'package:lorry_link/modules/loads/models/load_model.dart';
import 'package:lorry_link/modules/loads/models/load_screen_models.dart';
import 'package:lorry_link/modules/loads/repositories/load_repository_interface.dart';
import 'package:lorry_link/modules/bookings/models/booking_model.dart';
import 'package:lorry_link/modules/bookings/repositories/booking_repository_interface.dart';
import 'package:lorry_link/modules/home/models/home_model.dart';
import 'package:lorry_link/modules/home/repositories/home_repository_interface.dart';
import 'package:lorry_link/modules/notifications/models/notification_model.dart';
import 'package:lorry_link/modules/notifications/repositories/notification_repository_interface.dart';

const shipper = ProfileModel(
  id: '00000000-0000-4000-8000-000000000001',
  name: 'Anita Logistics',
  role: UserRole.shipper,
  phone: '+919876543210',
);
const driver = ProfileModel(
  id: '00000000-0000-4000-8000-000000000002',
  name: 'Arjun Kumar',
  role: UserRole.driver,
);
final sampleLoad = LoadModel(
  id: '10000000-0000-4000-8000-000000000001',
  shipperId: shipper.id,
  pickup: 'Kochi',
  destination: 'Bengaluru',
  cargo: 'Packaged textiles · 4 tonnes',
  vehicle: 'Open truck',
  pickupDate: DateTime(2099, 1, 1),
  status: 'open',
  price: 12500,
  requestCount: 2,
);

class FakeAuth implements IAuthRepository {
  FakeAuth({this.current = shipper, this.authenticated = true});
  ProfileModel? current;
  bool authenticated;
  final controller = StreamController<SessionEvent>.broadcast();
  int signInCalls = 0;
  @override
  Stream<SessionEvent> get events => controller.stream;
  @override
  bool get signedIn => authenticated;
  @override
  String get email => 'qa@example.invalid';
  @override
  String get suggestedName => 'Test User';
  @override
  UserRole get suggestedRole => UserRole.shipper;
  @override
  Future<ProfileModel?> profile() async => current;
  @override
  Future<void> signIn(SignInModel model) async {
    signInCalls++;
    authenticated = true;
    current ??= shipper;
    controller.add(SessionEvent.changed);
  }

  @override
  Future<bool> signUp(SignUpModel model) async => false;
  @override
  Future<void> google() async {}
  @override
  Future<void> resetPassword(PasswordResetModel model) async {}
  @override
  Future<void> updatePassword(String password) async {}
  @override
  Future<void> signOut() async {
    authenticated = false;
    controller.add(SessionEvent.changed);
  }
}

class FakeProfile implements IProfileRepository {
  FakeProfile(this.auth);
  final FakeAuth auth;
  @override
  Future<ProfileModel> save({
    required String name,
    required String phone,
    UserRole? role,
  }) async {
    auth.current = ProfileModel(
      id: auth.current?.id ?? shipper.id,
      name: name,
      phone: phone,
      role: auth.current?.role ?? role!,
    );
    return auth.current!;
  }
}

class FakeLoads implements ILoadRepository {
  List<LoadModel> rows = [sampleLoad];
  LoadDraft? saved;
  int calls = 0;
  @override
  Future<List<LoadModel>> list({
    bool mine = false,
    LoadFilter filter = const LoadFilter(),
    int offset = 0,
  }) async {
    calls++;
    return rows
        .where(
          (l) =>
              (filter.pickup == null || l.pickup == filter.pickup) &&
              (filter.vehicle == null || l.vehicle == filter.vehicle) &&
              (filter.status == null || l.status == filter.status),
        )
        .skip(offset)
        .take(20)
        .toList();
  }

  @override
  Future<LoadDetailsModel> get(String id) async => LoadDetailsModel(
    rows.firstWhere((l) => l.id == id),
    ownerName: shipper.name,
  );
  @override
  Future<LoadModel> save(LoadDraft draft, {bool edit = false}) async {
    saved = draft;
    return rows.first;
  }

  @override
  Future<void> cancel(String id) async {}
  @override
  Future<void> callContact(String phone) async {}
}

class FakeBookings implements IBookingRepository {
  String status = 'requested';
  bool reported = false;
  final actions = <String>[];
  BookingModel get booking => BookingModel(
    id: '20000000-0000-4000-8000-000000000001',
    driverId: driver.id,
    status: status,
    load: sampleLoad,
    createdAt: DateTime(2026, 10, 12),
    driverName: driver.name,
    otherName: shipper.name,
    deliveryReportedAt: reported ? DateTime(2026, 10, 13) : null,
    events: [BookingEvent('requested', DateTime(2026, 10, 12), '')],
  );
  @override
  Future<String> request(String loadId) async => booking.id;
  @override
  Future<List<BookingModel>> list({
    String? loadId,
    String? status,
    int offset = 0,
  }) async =>
      offset == 0 && (status == null || status == this.status) ? [booking] : [];
  @override
  Future<BookingModel> get(String id) async => booking;
  @override
  Future<void> transition(String id, String status, {String? reason}) async {
    actions.add(status);
    if (status == 'delivery_reported') {
      reported = true;
    } else {
      this.status = status;
    }
  }

  @override
  Future<void> callContact(String phone) async {}
}

class FakeHome implements IHomeRepository {
  @override
  Future<HomeModel> get() async => HomeModel(
    open: 3,
    active: 2,
    completed: 12,
    pending: 2,
    unread: 1,
    loads: [sampleLoad],
  );
}

class FakeNotifications implements INotificationRepository {
  bool read = false;
  @override
  Future<List<NotificationModel>> list({int offset = 0}) async => offset > 0
      ? []
      : [
          NotificationModel(
            id: 'n1',
            title: 'New booking request',
            body: 'Arjun requested your load',
            createdAt: DateTime(2026, 10, 12),
            bookingId: '20000000-0000-4000-8000-000000000001',
            readAt: read ? DateTime.now() : null,
          ),
        ];
  @override
  Future<void> markRead([String? id]) async {
    read = true;
  }
}

Future<void> setupFakes(
  FakeAuth auth, {
  FakeLoads? loads,
  FakeBookings? bookings,
}) async {
  await di.reset();
  di.registerSingleton<IAuthRepository>(auth);
  di.registerSingleton<IProfileRepository>(FakeProfile(auth));
  di.registerSingleton<ILoadRepository>(loads ?? FakeLoads());
  di.registerSingleton<IBookingRepository>(bookings ?? FakeBookings());
  di.registerSingleton<IHomeRepository>(FakeHome());
  di.registerSingleton<INotificationRepository>(FakeNotifications());
  configureCubits();
}
