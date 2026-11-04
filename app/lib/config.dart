/// 앱 설정 한곳 모음. 출시 전 확정해야 할 값은 docs/decisions.md 참고.
class AppConfig {
  const AppConfig({
    this.appId = 'kr.majung.app.dev',
    this.dataUrl,
    this.reportEmail,
    this.privacyPolicyUrl,
    this.tileUrlTemplate = defaultTileUrl,
  });

  /// 임시 패키지명 (decisions #3).
  final String appId;

  /// GitHub Pages 에 올릴 시설 데이터 주소 (decisions #9). 정해지기 전에는 null → 업데이트 안 함.
  final Uri? dataUrl;

  /// 오류 신고 이메일 (decisions #8). 정해지기 전에는 버튼을 숨긴다.
  final String? reportEmail;

  final Uri? privacyPolicyUrl;

  /// 지도 타일 주소. null 이면 지도 배경 없이 핀만(테스트용).
  /// TODO(출시 전): 앱 배포에 허용되는 무료 타일 제공자로 교체 (data/research/map-osm.md).
  final String? tileUrlTemplate;

  static const defaultTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
}
