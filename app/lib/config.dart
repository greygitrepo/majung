/// 앱 설정 한곳 모음. 출시 전 확정해야 할 값은 docs/decisions.md 참고.
class AppConfig {
  const AppConfig({
    this.appId = 'kr.or.majung.app',
    this.dataUrl = defaultDataUrl,
    this.reportEmail = contactEmail,
    this.privacyPolicyUrl = defaultPrivacyPolicyUrl,
    this.tileUrlTemplate = defaultTileUrl,
  });

  /// 패키지명 (decisions #3, 확정).
  final String appId;

  /// 시설 데이터 주소 (decisions #9). null 이면 업데이트 안 함.
  final String? dataUrl;

  /// 오류 신고·문의 이메일 (decisions #8). null 이면 버튼을 숨긴다.
  final String? reportEmail;

  /// 개인정보처리방침 (docs/privacy-policy.md 를 tools/build_site.py 로 만든 페이지).
  final String? privacyPolicyUrl;

  Uri? get dataUri => dataUrl == null ? null : Uri.parse(dataUrl!);
  Uri? get privacyPolicyUri => privacyPolicyUrl == null ? null : Uri.parse(privacyPolicyUrl!);

  /// 지도 타일 주소. null 이면 지도 배경 없이 핀만(테스트용).
  /// TODO(출시 전): 앱 배포에 허용되는 무료 타일 제공자로 교체 (data/research/map-osm.md).
  final String? tileUrlTemplate;

  /// 운영자 이름과 문의 이메일 (decisions #8). 개인정보처리방침·스토어 등록정보와 같게.
  static const operatorName = 'majungdev';
  static const contactEmail = 'majungdev@gmail.com';

  /// GitHub Pages (decisions #9). 한 번 배포한 주소는 설치된 앱이 계속 쓰므로 바꾸지 않는다.
  static const siteBase = 'https://greygitrepo.github.io/majung/';
  static const defaultDataUrl = '${siteBase}data/facilities.json';
  static const defaultPrivacyPolicyUrl = '${siteBase}privacy.html';

  static const defaultTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
}
