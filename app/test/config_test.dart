import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:majung/config.dart';

void main() {
  test('출시 설정: 패키지명·문의 이메일이 정해져 있다 (decisions #3, #8)', () {
    const c = AppConfig();
    expect(c.appId, 'kr.or.majung.app');
    expect(c.reportEmail, 'majungdev@gmail.com');
  });

  test('데이터·개인정보처리방침 주소: GitHub Pages, https, 위치 정보 없음 (decisions #9)', () {
    const c = AppConfig();
    expect(c.dataUri.toString(), 'https://greygitrepo.github.io/majung/data/facilities.json');
    expect(c.privacyPolicyUri.toString(), 'https://greygitrepo.github.io/majung/privacy.html');
    for (final u in [c.dataUri!, c.privacyPolicyUri!]) {
      expect(u.scheme, 'https');
      expect(u.query, isEmpty);
    }
  });

  test('개인정보처리방침이 공개 가능한 상태다 (초안 아님, 시행일 날짜)', () {
    final policy = File('../docs/privacy-policy.md').readAsStringSync();
    expect(policy, isNot(contains('(초안)')));
    expect(RegExp(r'^시행일: \d{4}-\d{2}-\d{2}$', multiLine: true).hasMatch(policy), isTrue);
    expect(policy, contains(const AppConfig().privacyPolicyUrl!), reason: '작업 메모에 공개 주소를 적어 둔다');
  });

  test('개인정보처리방침의 문의처가 앱 설정과 같다', () {
    // flutter test 는 app/ 에서 실행된다.
    final policy = File('../docs/privacy-policy.md').readAsStringSync();
    expect(policy, contains('${AppConfig.operatorName} · ${AppConfig.contactEmail}'));
    expect(policy, isNot(contains('(이메일)')));
  });

  test('안드로이드 applicationId 가 앱 설정의 appId 와 같다', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationId = "${const AppConfig().appId}"'));
  });
}
