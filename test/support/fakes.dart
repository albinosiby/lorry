import 'dart:async';
import 'dart:typed_data';
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
import 'package:lorry_link/modules/tracking/models/trip_location_model.dart';
import 'package:lorry_link/modules/tracking/repositories/trip_tracking_repository_interface.dart';
import 'package:lorry_link/utils/services/location_service.dart';
import 'package:lorry_link/utils/services/place_search_service.dart';
import 'package:lorry_link/modules/verification/models/profile_document_model.dart';
import 'package:lorry_link/modules/verification/repositories/profile_documents_repository_interface.dart';
import 'package:lorry_link/modules/driver_documents/models/driver_document_model.dart';
import 'package:lorry_link/modules/driver_documents/repositories/driver_documents_repository_interface.dart';
import 'package:lorry_link/modules/vehicles/models/vehicle_model.dart';
import 'package:lorry_link/modules/vehicles/repositories/vehicle_repository_interface.dart';

const shipper = ProfileModel(
  id: '00000000-0000-4000-8000-000000000001',
  name: 'Anita Logistics',
  role: UserRole.shipper,
  phone: '+919876543210',
  photoPath: 'profiles/anita.jpg',
  address: 'Kochi, Kerala',
);
const driver = ProfileModel(
  id: '00000000-0000-4000-8000-000000000002',
  name: 'Arjun Kumar',
  role: UserRole.driver,
  phone: '+919812345678',
  photoPath: 'profiles/arjun.jpg',
  address: 'Aluva, Kerala',
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
  Future<String> uploadPhoto(Uint8List bytes) async =>
      'https://example.invalid/profile.jpg';
  @override
  Future<ProfileModel> save({
    required String name,
    required String phone,
    UserRole? role,
    String? address,
    String? companyName,
    String? photoPath,
  }) async {
    auth.current = ProfileModel(
      id: auth.current?.id ?? shipper.id,
      name: name,
      phone: phone,
      role: auth.current?.role ?? role!,
      address: address,
      companyName: companyName,
      photoPath: photoPath,
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
  double? collectedAmount;
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
  Future<void> transition(
    String id,
    String status, {
    String? reason,
    double? collectedAmount,
    double? latitude,
    double? longitude,
  }) async {
    actions.add(status);
    this.collectedAmount = collectedAmount;
    if (status == 'delivery_reported') {
      reported = true;
    } else {
      this.status = status;
    }
  }

  @override
  Future<void> callContact(String phone) async {}
  @override
  Future<void> acceptCustomerInvitation(String id) async {
    status = 'accepted';
  }
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

class FakeLocationService implements ILocationService {
  @override
  Future<DeviceLocation> current({bool requestPermission = true}) async =>
      const DeviceLocation(
        status: DeviceLocationStatus.ready,
        latitude: 9.9312,
        longitude: 76.2673,
      );

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> openAppSettings() async {}
}

class FakePlaceSearchService implements IPlaceSearchService {
  @override
  Future<List<PlaceSearchResult>> search(String query) async => [
    PlaceSearchResult(label: query, latitude: 9.9312, longitude: 76.2673),
  ];
}

class FakeProfileDocuments implements IProfileDocumentsRepository {
  final documents = <ProfileDocumentModel>[];

  @override
  Future<List<ProfileDocumentModel>> list() async => documents;

  @override
  Future<void> remove(ProfileDocumentModel document) async {
    documents.removeWhere((item) => item.id == document.id);
  }

  @override
  Future<ProfileDocumentModel> upload(ProfileDocumentDraft draft) async {
    final document = ProfileDocumentModel(
      id: '40000000-0000-4000-8000-000000000001',
      type: draft.type,
      status: 'submitted',
      createdAt: DateTime.now(),
      storagePath: 'test/${draft.filename}',
    );
    documents
      ..clear()
      ..add(document);
    return document;
  }

  @override
  Future<Uri?> viewUrl(ProfileDocumentModel document) async {
    final path = document.storagePath;
    return path == null ? null : Uri.parse('https://example.invalid/$path');
  }
}

class FakeDriverDocuments implements IDriverDocumentsRepository {
  final documents = <DriverDocumentModel>[];

  @override
  Future<List<DriverDocumentModel>> list() async => List.of(documents);

  @override
  Future<DriverDocumentModel> upload(DriverDocumentDraft draft) async {
    final document = DriverDocumentModel(
      id: '50000000-0000-4000-8000-000000000001',
      type: draft.type,
      status: 'submitted',
      createdAt: DateTime.now(),
      vehicleId: draft.vehicleId,
      storagePath: 'test/${draft.filename}',
    );
    documents.add(document);
    return document;
  }

  @override
  Future<Uri?> viewUrl(DriverDocumentModel document) async =>
      Uri.parse('https://example.invalid/${document.storagePath}');
}

class FakeVehicles implements IVehicleRepository {
  @override
  Future<List<VehicleModel>> list() async => const [
    VehicleModel(
      id: '30000000-0000-4000-8000-000000000001',
      registrationNumber: 'KL 07 AB 1234',
      vehicleType: 'Open truck',
      bodyType: 'Open truck',
      lengthFt: 14,
      capacityTonnes: 4,
      isDefault: true,
    ),
  ];

  @override
  Future<VehicleModel> save(VehicleDraft draft) async => VehicleModel(
    id: draft.id ?? '30000000-0000-4000-8000-000000000001',
    registrationNumber: draft.registrationNumber,
    vehicleType: draft.vehicleType,
    bodyType: draft.bodyType,
    lengthFt: draft.lengthFt,
    capacityTonnes: draft.capacityTonnes,
    isDefault: draft.isDefault,
  );
}

class FakeTripTracking implements ITripTrackingRepository {
  TripLocationModel? location;

  @override
  Future<TripLocationModel?> get(String bookingId) async => location;

  @override
  Future<void> update({
    required String bookingId,
    required double latitude,
    required double longitude,
  }) async {
    location = TripLocationModel(
      latitude: latitude,
      longitude: longitude,
      recordedAt: DateTime.now().toUtc(),
    );
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
  di.registerSingleton<ILocationService>(FakeLocationService());
  di.registerSingleton<IPlaceSearchService>(FakePlaceSearchService());
  di.registerSingleton<IProfileDocumentsRepository>(FakeProfileDocuments());
  di.registerSingleton<ITripTrackingRepository>(FakeTripTracking());
  configureCubits();
}
