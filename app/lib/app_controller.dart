import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/facility_repository.dart';
import 'domain/category.dart';
import 'domain/dataset.dart';
import 'domain/geo.dart';
import 'domain/opening_hours.dart';
import 'domain/ranking.dart';
import 'domain/region.dart';
import 'services/location_service.dart';

enum OriginKind { none, gps, region }

class Origin {
  const Origin.none()
      : kind = OriginKind.none,
        point = null,
        region = null;

  /// [region] 은 GPS 좌표에서 기기 안에서 찾은 가장 가까운 시군구 (긴급 연락처 지역 판단용).
  const Origin.gps(GeoPoint this.point, {this.region}) : kind = OriginKind.gps;

  Origin.region(Region this.region)
      : kind = OriginKind.region,
        point = region.point;

  final OriginKind kind;
  final GeoPoint? point;
  final Region? region;
}

/// 사용자가 고른 시군구 코드만 기기에 저장한다. GPS 좌표는 저장하지 않는다.
abstract class OriginStore {
  Future<String?> loadRegionCode();
  Future<void> saveRegionCode(String? code);
}

class PrefsOriginStore implements OriginStore {
  static const _key = 'origin_region';

  /// 서울 3개 구 시절 저장값. 읽지 않고 지운다.
  static const _legacyKey = 'origin_landmark';

  @override
  Future<String?> loadRegionCode() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_legacyKey)) await prefs.remove(_legacyKey);
    return prefs.getString(_key);
  }

  @override
  Future<void> saveRegionCode(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, code);
    }
  }
}

class MemoryOriginStore implements OriginStore {
  MemoryOriginStore([this.code]);
  String? code;
  @override
  Future<String?> loadRegionCode() async => code;
  @override
  Future<void> saveRegionCode(String? value) async => code = value;
}

class AppController extends ChangeNotifier {
  AppController({
    required this.repository,
    required this.location,
    required this.originStore,
    Future<RegionCatalog> Function()? loadRegions,
    DateTime Function()? clock,
    Duration? tick = const Duration(minutes: 1),
  })  : clock = clock ?? DateTime.now,
        _loadRegions = loadRegions {
    if (tick != null) _ticker = Timer.periodic(tick, (_) => notifyListeners());
  }

  final FacilityRepository repository;
  final LocationService location;
  final OriginStore originStore;
  final DateTime Function() clock;
  final Future<RegionCatalog> Function()? _loadRegions;
  Timer? _ticker;

  RegionCatalog regions = RegionCatalog.empty;

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
    try {
      final load = _loadRegions;
      if (load != null) regions = await load();
    } on Object {
      regions = RegionCatalog.empty;
    }
    final saved = await originStore.loadRegionCode();
    final region = saved == null ? null : regions.byCode(saved);
    if (region != null) origin = Origin.region(region);
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
      origin = Origin.gps(result.point!, region: regions.nearest(result.point!));
      await originStore.saveRegionCode(null);
    } else {
      lastLocationFailure = result.failure;
    }
    notifyListeners();
    return result.point != null;
  }

  Future<void> useRegion(Region region) async {
    origin = Origin.region(region);
    lastLocationFailure = null;
    await originStore.saveRegionCode(region.code);
    notifyListeners();
  }

  /// 긴급 연락처를 지역에 맞추는 데 쓴다. 모르면 null(전국 공통 번호만).
  String? get currentSido => origin.region?.sido;

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
