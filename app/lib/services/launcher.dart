import 'package:url_launcher/url_launcher.dart';

import '../domain/facility.dart';
import '../domain/geo.dart';

/// 앱 밖으로 나가는 동작(전화·길찾기·메일). 테스트에서는 가짜로 바꾼다.
abstract class ActionLauncher {
  /// 전화 앱(다이얼러)을 연다. CALL_PHONE 권한 없이 번호만 채워 준다.
  Future<bool> dial(String phone);

  /// 지도 앱으로 길찾기. 출발지는 보내지 않는다(지도 앱이 판단).
  Future<bool> directions(String name, GeoPoint destination);

  Future<bool> email(String to, {required String subject, required String body});

  Future<bool> openWeb(Uri url);
}

class UrlActionLauncher implements ActionLauncher {
  UrlActionLauncher({required this.appId});

  /// 네이버 지도 딥링크에 필요한 호출 앱 식별자(패키지명).
  final String appId;

  @override
  Future<bool> dial(String phone) => _try(Uri(scheme: 'tel', path: dialDigits(phone)));

  @override
  Future<bool> directions(String name, GeoPoint d) async {
    for (final uri in directionUris(name, d, appId: appId)) {
      if (await _try(uri)) return true;
    }
    return false;
  }

  @override
  Future<bool> email(String to, {required String subject, required String body}) => _try(
        Uri(scheme: 'mailto', path: to, query: _encodeQuery({'subject': subject, 'body': body})),
      );

  @override
  Future<bool> openWeb(Uri url) => _try(url);

  Future<bool> _try(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}

/// 길찾기 시도 순서: 네이버지도 앱 → 카카오맵 앱 → 기기 기본 지도(geo:) → 카카오맵 웹.
List<Uri> directionUris(String name, GeoPoint d, {required String appId}) => [
      Uri.parse('nmap://route/walk?dlat=${d.lat}&dlng=${d.lng}'
          '&dname=${Uri.encodeComponent(name)}&appname=${Uri.encodeComponent(appId)}'),
      Uri.parse('kakaomap://route?ep=${d.lat},${d.lng}&by=foot'),
      Uri.parse('geo:${d.lat},${d.lng}?q=${d.lat},${d.lng}(${Uri.encodeComponent(name)})'),
      Uri.parse('https://map.kakao.com/link/to/${Uri.encodeComponent(name)},${d.lat},${d.lng}'),
    ];

/// mailto 는 + 대신 %20 이 필요해서 직접 인코딩한다.
String _encodeQuery(Map<String, String> params) => params.entries
    .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
    .join('&');
