import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// `flutter drive` 가 쓰는 드라이버. 테스트가 찍은 화면을 docs/screenshots/<이름>.png 로 저장한다.
/// app/ 에서 실행한다 (integration_test/screenshots_test.dart 맨 위 명령 참고).
Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final file = File('../docs/screenshots/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
        return true;
      },
    );
