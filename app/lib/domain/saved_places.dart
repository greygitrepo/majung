import 'dart:convert';

import 'category.dart';
import 'dataset.dart';
import 'facility.dart';
import 'freshness.dart';
import 'geo.dart';
import 'ranking.dart';

/// 사용자가 저장한 시설 하나 (decisions #20). 기기에만 둔다.
///
/// 시설 ID는 공공데이터가 바뀌면(급식소 이름·주소 등) 달라질 수 있어서,
/// 다시 찾을 수 있게 이름·주소·전화도 같이 남긴다. 전화는 "예전 정보"로만 보여 준다.
class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.savedAt,
    this.phone,
    this.sido,
  });

  factory SavedPlace.fromFacility(Facility f, DateTime now) => SavedPlace(
        id: f.id,
        name: f.name,
        category: f.category,
        address: f.address,
        phone: f.phone,
        sido: f.sido,
        savedAt: DateTime(now.year, now.month, now.day),
      );

  /// 형식이 틀리면 [FormatException].
  factory SavedPlace.fromJson(Map<String, dynamic> json) {
    String req(String key) {
      final v = json[key];
      if (v is! String || v.isEmpty) throw FormatException('저장한 곳 필드 누락: $key');
      return v;
    }

    final category = FacilityCategory.tryParse(json['category'] as String?);
    if (category == null) throw const FormatException('저장한 곳 분류 오류');
    final savedAt = DateTime.tryParse(req('saved_at'));
    if (savedAt == null) throw const FormatException('저장한 곳 날짜 오류');
    return SavedPlace(
      id: req('id'),
      name: req('name'),
      category: category,
      address: req('address'),
      phone: json['phone'] is String ? json['phone'] as String : null,
      sido: json['sido'] is String ? json['sido'] as String : null,
      savedAt: savedAt,
    );
  }

  final String id;
  final String name;
  final FacilityCategory category;
  final String address;
  final String? phone;
  final String? sido;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'address': address,
        'phone': ?phone,
        'sido': ?sido,
        'saved_at': '${savedAt.year.toString().padLeft(4, '0')}-'
            '${savedAt.month.toString().padLeft(2, '0')}-${savedAt.day.toString().padLeft(2, '0')}',
      };

  /// 지금 데이터의 시설로 이름·주소·전화를 새로 고친다 (저장한 날은 그대로).
  SavedPlace refreshedFrom(Facility f) => SavedPlace(
        id: f.id,
        name: f.name,
        category: f.category,
        address: f.address,
        phone: f.phone,
        sido: f.sido,
        savedAt: savedAt,
      );
}

/// 저장값(JSON 문자열)을 읽는다. 깨졌으면 빈 목록, 깨진 항목·중복은 건너뛴다.
List<SavedPlace> decodeSavedPlaces(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  Object? json;
  try {
    json = jsonDecode(raw);
  } on FormatException {
    return const [];
  }
  if (json is! List) return const [];
  final out = <SavedPlace>[];
  final seen = <String>{};
  for (final item in json) {
    try {
      final p = SavedPlace.fromJson(Map<String, dynamic>.from(item as Map));
      if (seen.add(p.id)) out.add(p);
    } on FormatException {
      continue;
    } on TypeError {
      continue;
    }
  }
  return out;
}

String encodeSavedPlaces(List<SavedPlace> places) => jsonEncode([for (final p in places) p.toJson()]);

/// 이름·주소 비교용: 괄호 안, 공백, 문장부호를 뺀다 (pipeline/build.py `_norm` 과 비슷).
String normalizeForMatch(String s) =>
    s.replaceAll(RegExp(r'\(.*?\)'), '').replaceAll(RegExp(r'[\s,·\-\.]'), '').toLowerCase();

/// 지금 데이터에 맞춰 저장 목록을 고친다.
///
/// - ID가 그대로 있으면 이름·주소·전화를 최신으로.
/// - ID가 없어졌지만 같은 분류·이름·주소인 시설이 있으면 그 시설로 옮긴다 (ID만 바뀐 경우).
/// - 못 찾으면 그대로 둔다 (화면에서 "정보가 바뀌었거나 빠졌어요").
List<SavedPlace> reconcileSavedPlaces(List<SavedPlace> saved, Dataset dataset) {
  final byId = {for (final f in dataset.facilities) f.id: f};
  final byKey = <String, Facility>{};
  for (final f in dataset.facilities) {
    byKey.putIfAbsent(_key(f.category, f.name, f.address), () => f);
  }
  final out = <SavedPlace>[];
  final seen = <String>{};
  for (final p in saved) {
    final f = byId[p.id] ?? byKey[_key(p.category, p.name, p.address)];
    final next = f == null ? p : p.refreshedFrom(f);
    if (seen.add(next.id)) out.add(next);
  }
  return out;
}

String _key(FacilityCategory c, String name, String address) =>
    '${c.name}|${normalizeForMatch(name)}|${normalizeForMatch(address)}';

/// 화면에 보여 줄 저장한 곳 하나.
class SavedEntry {
  const SavedEntry({required this.saved, this.current, this.similar = const []});

  final SavedPlace saved;

  /// 지금 데이터에 있는 시설 (없으면 null = 바뀌었거나 빠짐).
  final RankedFacility? current;

  /// [current]가 없을 때 이름이 같은 같은 분류 시설 (다른 주소로 옮겼을 수 있음).
  final List<Facility> similar;

  bool get missing => current == null;
}

/// 저장한 곳을 지금 상태로 계산해 정렬한다:
/// 지금 열린 곳 → 나머지(가까운 순, 기준 위치가 없으면 저장한 순) → 180일 넘은 정보 → 못 찾은 곳.
List<SavedEntry> savedEntries(
  List<SavedPlace> saved,
  Dataset dataset, {
  required DateTime now,
  GeoPoint? origin,
}) {
  final byId = {for (final f in dataset.facilities) f.id: f};
  final entries = <SavedEntry>[];
  for (final p in saved) {
    final f = byId[p.id];
    if (f != null) {
      entries.add(SavedEntry(
        saved: p,
        current: RankedFacility(
          facility: f,
          status: f.statusAt(now, isHoliday: dataset.isHoliday),
          freshness: f.freshnessAt(now),
          distance: origin == null ? null : distanceMeters(origin, f.location),
        ),
      ));
    } else {
      final name = normalizeForMatch(p.name);
      entries.add(SavedEntry(
        saved: p,
        similar: dataset.facilities
            .where((x) =>
                x.category == p.category &&
                normalizeForMatch(x.name) == name &&
                (p.sido == null || x.sido == null || x.sido == p.sido))
            .take(2)
            .toList(),
      ));
    }
  }

  int bucket(SavedEntry e) {
    final c = e.current;
    if (c == null) return 3;
    if (c.freshness == Freshness.expired) return 2;
    return c.status.isOpenNow ? 0 : 1;
  }

  final order = {for (var i = 0; i < saved.length; i++) saved[i].id: i};
  entries.sort((a, b) {
    final byBucket = bucket(a).compareTo(bucket(b));
    if (byBucket != 0) return byBucket;
    final da = a.current?.distance;
    final db = b.current?.distance;
    if (da != null && db != null && da != db) return da.compareTo(db);
    return order[a.saved.id]!.compareTo(order[b.saved.id]!);
  });
  return entries;
}
