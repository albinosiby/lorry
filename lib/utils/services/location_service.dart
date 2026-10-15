import 'package:geolocator/geolocator.dart';
import '../exceptions/app_exception.dart';

enum DeviceLocationStatus {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class DeviceLocation {
  const DeviceLocation({required this.status, this.latitude, this.longitude});

  final DeviceLocationStatus status;
  final double? latitude;
  final double? longitude;
  bool get available => status == DeviceLocationStatus.ready;
}

abstract interface class ILocationService {
  Future<DeviceLocation> current({bool requestPermission = true});
  Future<void> openSettings();
  Future<void> openAppSettings();
}

class LocationService implements ILocationService {
  @override
  Future<DeviceLocation> current({bool requestPermission = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const DeviceLocation(
          status: DeviceLocationStatus.serviceDisabled,
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const DeviceLocation(
          status: DeviceLocationStatus.permissionDenied,
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const DeviceLocation(
          status: DeviceLocationStatus.permissionDeniedForever,
        );
      }
      final point = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      return DeviceLocation(
        status: DeviceLocationStatus.ready,
        latitude: point.latitude,
        longitude: point.longitude,
      );
    } catch (_) {
      throw const AppException(
        'We could not access your location. Turn on GPS and allow location access, then try again.',
      );
    }
  }

  @override
  Future<void> openSettings() => Geolocator.openLocationSettings();

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}
