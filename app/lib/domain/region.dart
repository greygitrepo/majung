import 'geo.dart';

/// 시군구 하나 (위치 권한 없이 고르는 기준 장소).
/// 좌표는 행정구역 대표점이다. 출처·계산 방법은 pipeline 과 data/build-report.md.
class Region {
  const Region({required this.code, required this.sido, required this.sigungu, required this.point});

  factory Region.fromJson(Map<String, dynamic> json) {
    final lat = json['lat'];
    final lng = json['lng'];
    final code = '${json['code'] ?? ''}'.trim();
    final sido = '${json['sido'] ?? ''}'.trim();
    final sigungu = '${json['sigungu'] ?? ''}'.trim();
    if (code.isEmpty || sido.isEmpty || sigungu.isEmpty || lat is! num || lng is! num) {
      throw FormatException('지역 형식 오류: $json');
    }
    final point = GeoPoint(lat.toDouble(), lng.toDouble());
    if (!point.isInKorea) throw FormatException('지역 좌표가 국내 범위 밖: $code');
    return Region(code: code, sido: sido, sigungu: sigungu, point: point);
  }

  final String code;
  final String sido;
  final String sigungu;
  final GeoPoint point;

  /// "서울 용산구"
  String get label => '$sido $sigungu';

  @override
  bool operator ==(Object other) => other is Region && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

class RegionCatalog {
  RegionCatalog(List<Region> regions) : regions = List.unmodifiable(regions);

  /// 잘못된 항목은 건너뛴다. 목록 자체가 깨졌으면 [FormatException].
  factory RegionCatalog.fromJson(Object? json) {
    if (json is! List) throw const FormatException('지역 목록 형식 오류');
    final out = <Region>[];
    final seen = <String>{};
    for (final raw in json) {
      try {
        final r = Region.fromJson(Map<String, dynamic>.from(raw as Map));
        if (seen.add(r.code)) out.add(r);
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    out.sort((a, b) => a.code.compareTo(b.code));
    return RegionCatalog(out);
  }

  static final empty = RegionCatalog(const []);

  final List<Region> regions;

  bool get isEmpty => regions.isEmpty;

  /// 시도 이름, 행정코드 순서.
  List<String> get sidos {
    final out = <String>[];
    for (final r in regions) {
      if (!out.contains(r.sido)) out.add(r.sido);
    }
    return out;
  }

  List<Region> inSido(String sido) => [for (final r in regions) if (r.sido == sido) r];

  Region? byCode(String code) {
    for (final r in regions) {
      if (r.code == code) return r;
    }
    return null;
  }

  /// 가장 가까운 시군구 대표점. 기기 안에서만 계산한다(좌표를 밖으로 보내지 않음).
  Region? nearest(GeoPoint p) {
    Region? best;
    var bestD = double.infinity;
    for (final r in regions) {
      final d = distanceMeters(p, r.point);
      if (d < bestD) {
        bestD = d;
        best = r;
      }
    }
    return best;
  }
}
