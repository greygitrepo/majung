import 'dart:math' as math;

class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;

  /// 대한민국 대략 범위 (제주~독도 포함).
  bool get isInKorea => lat >= 33.0 && lat <= 38.7 && lng >= 124.5 && lng <= 132.0;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

/// 두 지점 사이 거리(미터), 하버사인 공식.
double distanceMeters(GeoPoint a, GeoPoint b) {
  const earthRadius = 6371000.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadius * math.asin(math.sqrt(h));
}

/// 걷는 속도 시속 4km(분당 약 67m). 직선거리라 실제보다 짧게 나오므로 1.3배 보정한다.
int walkingMinutes(double meters) {
  const metersPerMinute = 4000 / 60;
  const detourFactor = 1.3;
  final minutes = (meters * detourFactor / metersPerMinute).ceil();
  return minutes < 1 ? 1 : minutes;
}

/// 350m, 1.2km 처럼 짧게.
String formatDistance(double meters) {
  if (meters < 1000) {
    final rounded = (meters / 10).round() * 10;
    return '${rounded < 10 ? 10 : rounded}m';
  }
  final km = meters / 1000;
  return km < 10 ? '${km.toStringAsFixed(1)}km' : '${km.round()}km';
}

/// 이 거리 안이면 "걸어서 약 N분", 넘으면 거리만 보여 준다.
const walkableMeters = 3000.0;
