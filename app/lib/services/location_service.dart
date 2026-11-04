import 'package:geolocator/geolocator.dart';

import '../domain/geo.dart';

enum LocationFailure { denied, deniedForever, serviceOff, error }

class LocationResult {
  const LocationResult.success(GeoPoint this.point) : failure = null;
  const LocationResult.failed(LocationFailure this.failure) : point = null;

  final GeoPoint? point;
  final LocationFailure? failure;
}

/// 현재 위치를 한 번 얻는다. 지속 추적·백그라운드 위치는 쓰지 않는다.
/// 얻은 좌표는 거리 계산에만 쓰고 저장·전송·로그하지 않는다.
abstract class LocationService {
  Future<LocationResult> current();
  Future<void> openSettings();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failed(LocationFailure.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failed(LocationFailure.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.failed(LocationFailure.denied);
      }
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } on Object {
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) return const LocationResult.failed(LocationFailure.error);
      return LocationResult.success(GeoPoint(position.latitude, position.longitude));
    } on Object {
      return const LocationResult.failed(LocationFailure.error);
    }
  }

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();
}
