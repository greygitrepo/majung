import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/facility_repository.dart';
import 'domain/category.dart';
import 'domain/dataset.dart';
import 'domain/geo.dart';
import 'domain/opening_hours.dart';
import 'domain/ranking.dart';
import 'services/location_service.dart';

enum OriginKind { none, gps, landmark }

class Origin {
  const Origin.none()
      : kind = OriginKind.none,
        point = null,
        landmark = null;
  const Origin.gps(GeoPoint this.point)
      : kind = OriginKind.gps,
        landmark = null;
  Origin.landmark(Landmark this.landmark)
      : kind = OriginKind.landmark,
        point = landmark.point;

  final OriginKind kind;
  final GeoPoint? point;
  final Landmark? landmark;
}

/// 사용자가 고른 기준 장소(랜드마크 id)만 기기에 저장한다. GPS 좌표는 저장하지 않는다.
abstract class OriginStore {
  Future<String?> loadLandmarkId();
  Future<void> saveLandmarkId(String? id);
}

class PrefsOriginStore implements OriginStore {
  static const _key = 'origin_landmark';

  @override
  Future<String?> loadLandmarkId() async => (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> saveLandmarkId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, id);
    }
  }
}

class MemoryOriginStore implements OriginStore {
  MemoryOriginStore([this.id]);
  String? id;
  @override
  Future<String?> loadLandmarkId() async => id;
  @override
  Future<void> saveLandmarkId(String? value) async => id = value;
}

class AppController extends ChangeNotifier {
  AppController({
    required this.repository,
    required this.location,
    required this.originStore,
    DateTime Function()? clock,
    Duration? tick = const Duration(minutes: 1),
  }) : clock = clock ?? DateTime.now {
    if (tick != null) _ticker = Timer.periodic(tick, (_) => notifyListeners());
  }

  final FacilityRepository repository;
  final LocationService location;
  final OriginStore originStore;
  final DateTime Function() clock;
  Timer? _ticker;

  Dataset? dataset;
  Object? loadError;
  Origin origin = const Origin.none();
  bool locating = false;
  LocationFailure? lastLocationFailure;

  bool get ready => dataset != null;

  Future<void> start() async {
    try {
      dataset = await repository.load();
    } on Object catch (e) {
      loadError = e;
    }
    final saved = await originStore.loadLandmarkId();
    final landmark = saved == null ? null : Landmark.byId(saved);
    if (landmark != null) origin = Origin.landmark(landmark);
    notifyListeners();
    unawaited(_refreshInBackground());
  }

  Future<UpdateResult> _refreshInBackground() async {
    final result = await repository.refresh();
    if (result == UpdateResult.updated) {
      dataset = repository.current;
      notifyListeners();
    }
    return result;
  }

  /// 당겨서 새로고침.
  Future<UpdateResult> refresh() => _refreshInBackground();

  /// 성공하면 true. 실패 이유는 [lastLocationFailure].
  Future<bool> useGps() async {
    locating = true;
    lastLocationFailure = null;
    notifyListeners();
    final result = await location.current();
    locating = false;
    if (result.point != null) {
      origin = Origin.gps(result.point!);
      await originStore.saveLandmarkId(null);
    } else {
      lastLocationFailure = result.failure;
    }
    notifyListeners();
    return result.point != null;
  }

  Future<void> useLandmark(Landmark landmark) async {
    origin = Origin.landmark(landmark);
    lastLocationFailure = null;
    await originStore.saveLandmarkId(landmark.id);
    notifyListeners();
  }

  List<RankedFacility> ranked(CategoryGroup group) {
    final d = dataset;
    if (d == null) return const [];
    return rankFacilities(d, group: group, now: clock(), origin: origin.point);
  }

  int openCount(CategoryGroup group) =>
      ranked(group).where((r) => r.status.isOpenNow).length;

  OpenStatus statusOf(RankedFacility r) => r.status;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
