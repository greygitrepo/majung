import 'facility.dart';

class DataSource {
  const DataSource({required this.id, required this.name, this.provider, this.url, this.license});

  factory DataSource.fromJson(Map<String, dynamic> json) => DataSource(
        id: '${json['id']}',
        name: '${json['name']}',
        provider: json['provider'] as String?,
        url: json['url'] as String?,
        license: json['license'] as String?,
      );

  final String id;
  final String name;
  final String? provider;
  final String? url;
  final String? license;
}

/// 앱에 배포되는 시설 데이터 묶음 하나.
class Dataset {
  const Dataset({
    required this.version,
    required this.facilities,
    this.sources = const [],
    this.holidays = const {},
    this.skipped = 0,
  });

  /// 잘못된 시설 항목은 건너뛰고(개수는 [skipped]), 묶음 자체가 깨졌으면 [FormatException].
  factory Dataset.fromJson(Map<String, dynamic> json) {
    final version = DateTime.tryParse('${json['version']}');
    if (version == null) throw const FormatException('데이터 버전 누락');
    final rawFacilities = json['facilities'];
    if (rawFacilities is! List) throw const FormatException('facilities 누락');

    final facilities = <Facility>[];
    final seen = <String>{};
    var skipped = 0;
    for (final raw in rawFacilities) {
      try {
        final f = Facility.fromJson(Map<String, dynamic>.from(raw as Map));
        if (!seen.add(f.id)) {
          skipped++;
          continue;
        }
        facilities.add(f);
      } on FormatException {
        skipped++;
      } on TypeError {
        skipped++;
      }
    }

    final holidays = <DateTime>{};
    for (final h in (json['holidays'] as List?) ?? const []) {
      final d = DateTime.tryParse('$h');
      if (d != null) holidays.add(DateTime(d.year, d.month, d.day));
    }

    return Dataset(
      version: version,
      facilities: facilities,
      sources: [
        for (final s in (json['sources'] as List?) ?? const [])
          DataSource.fromJson(Map<String, dynamic>.from(s as Map)),
      ],
      holidays: holidays,
      skipped: skipped,
    );
  }

  final DateTime version;
  final List<Facility> facilities;
  final List<DataSource> sources;
  final Set<DateTime> holidays;
  final int skipped;

  bool isHoliday(DateTime date) =>
      holidays.contains(DateTime(date.year, date.month, date.day));

  DataSource? sourceById(String id) {
    for (final s in sources) {
      if (s.id == id) return s;
    }
    return null;
  }
}
