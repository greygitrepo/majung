import 'category.dart';
import 'freshness.dart';
import 'geo.dart';
import 'opening_hours.dart';

enum VerifiedBy { publicData, official, phone, field, report }

/// general = 누구나·노숙 중인 분. senior = 어르신 경로식당처럼 미리 등록해야 하는 곳 (decisions #18).
enum Audience { general, senior }

/// 진료 시설 종류. 무료 진료소와 보건소(무료 아님)를 꼭 구분해 보여 준다.
enum ClinicType {
  freeClinic('free_clinic'),
  healthCenter('health_center'),
  hospitalSupport('hospital_support');

  const ClinicType(this.code);
  final String code;

  static ClinicType? tryParse(Object? v) {
    for (final t in values) {
      if (t.code == v) return t;
    }
    return null;
  }
}

class Facility {
  const Facility({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.location,
    required this.hours,
    required this.sourceId,
    required this.lastVerified,
    required this.verifiedBy,
    this.phone,
    this.hoursNote,
    this.eligibility,
    this.requirements,
    this.services = const [],
    this.sourceUrl,
    this.isFree = true,
    this.sido,
    this.sigungu,
    this.audience = Audience.general,
    this.clinicType,
    this.geocoded = false,
  });

  /// 필수 필드가 없거나 형식이 틀리면 [FormatException].
  factory Facility.fromJson(Map<String, dynamic> json) {
    String req(String key) {
      final v = json[key];
      if (v is! String || v.trim().isEmpty) {
        throw FormatException('필수 필드 누락: $key (id=${json['id']})');
      }
      return v.trim();
    }

    String? opt(String key) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      return null;
    }

    final category = FacilityCategory.tryParse(json['category'] as String?);
    if (category == null) {
      throw FormatException('알 수 없는 분류: ${json['category']} (id=${json['id']})');
    }

    final lat = json['lat'];
    final lng = json['lng'];
    if (lat is! num || lng is! num) throw FormatException('좌표 누락 (id=${json['id']})');
    final location = GeoPoint(lat.toDouble(), lng.toDouble());
    if (!location.isInKorea) throw FormatException('좌표가 국내 범위 밖 (id=${json['id']})');

    final rawHours = json['hours'];
    final rules = <HoursRule>[];
    if (rawHours is List) {
      for (final h in rawHours) {
        rules.add(HoursRule.fromJson(Map<String, dynamic>.from(h as Map)));
      }
    }
    final holidayPolicy = switch (json['holiday_policy']) {
      'open' => HolidayPolicy.open,
      'closed' => HolidayPolicy.closed,
      _ => null,
    };

    final verified = DateTime.tryParse(req('last_verified'));
    if (verified == null) throw FormatException('last_verified 형식 오류 (id=${json['id']})');

    final verifiedBy = switch (json['verified_by']) {
      'official' => VerifiedBy.official,
      'phone' => VerifiedBy.phone,
      'field' => VerifiedBy.field,
      'report' => VerifiedBy.report,
      _ => VerifiedBy.publicData,
    };

    final phone = opt('phone');
    if (phone != null && !isValidKoreanPhone(phone)) {
      throw FormatException('전화번호 형식 오류: $phone (id=${json['id']})');
    }

    return Facility(
      id: req('id'),
      name: req('name'),
      category: category,
      address: req('address'),
      location: location,
      phone: phone,
      hours: OpeningHours(rules, holidayPolicy: holidayPolicy),
      hoursNote: opt('hours_note'),
      eligibility: opt('eligibility'),
      requirements: opt('requirements'),
      services: (json['services'] as List?)?.map((e) => '$e').toList() ?? const [],
      isFree: json['cost'] != 'low_cost',
      sourceId: req('source_id'),
      sourceUrl: opt('source_url'),
      lastVerified: DateTime(verified.year, verified.month, verified.day),
      verifiedBy: verifiedBy,
      sido: opt('sido'),
      sigungu: opt('sigungu'),
      audience: json['audience'] == 'senior' ? Audience.senior : Audience.general,
      clinicType: ClinicType.tryParse(json['subtype']),
      geocoded: json['geocoded'] == true,
    );
  }

  final String id;
  final String name;
  final FacilityCategory category;
  final String address;
  final GeoPoint location;
  final String? phone;
  final OpeningHours hours;
  final String? hoursNote;
  final String? eligibility;
  final String? requirements;
  final List<String> services;
  final bool isFree;
  final String sourceId;
  final String? sourceUrl;
  final DateTime lastVerified;
  final VerifiedBy verifiedBy;
  final String? sido;
  final String? sigungu;
  final Audience audience;
  final ClinicType? clinicType;

  /// 주소로 좌표를 찾은 시설 (원본에 좌표 없음). 지도 위치가 조금 다를 수 있다.
  final bool geocoded;

  /// 사람이 확인한 운영시간만 믿는다. 공공데이터 시간은 대조해 보니 자주 틀렸다 (decisions #16).
  bool get hoursTrusted => verifiedBy != VerifiedBy.publicData && hours.rules.isNotEmpty;

  /// 확인 안 된 시설은 시간이 있어도 "지금 열림"을 계산하지 않는다.
  OpenStatus statusAt(DateTime now, {bool Function(DateTime)? isHoliday}) => hoursTrusted
      ? hours.statusAt(now, isHoliday: isHoliday)
      : const OpenStatus(OpenState.unknown);

  Freshness freshnessAt(DateTime now) => freshnessOf(lastVerified, now);
}

/// 02-123-4567, 1600-9582, 010-1234-5678, 120 같은 국내 번호.
bool isValidKoreanPhone(String value) {
  final digits = value.replaceAll(RegExp(r'[\s\-()]'), '');
  if (!RegExp(r'^\d+$').hasMatch(digits)) return false;
  if (RegExp(r'^(1[0-9]{2})$').hasMatch(digits)) return true; // 112, 119, 120, 129
  if (RegExp(r'^1[5-9]\d{2}\d{4}$').hasMatch(digits)) return true; // 1600-9582 등
  if (RegExp(r'^0\d{8,10}$').hasMatch(digits)) return true; // 지역번호·휴대폰
  return false;
}

/// tel: URI 용 숫자만.
String dialDigits(String phone) => phone.replaceAll(RegExp(r'[^\d]'), '');
