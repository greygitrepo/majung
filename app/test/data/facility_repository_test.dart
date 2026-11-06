import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:majung/data/facility_repository.dart';

import '../fixtures.dart';

http.Response ok(String body) => http.Response.bytes(utf8.encode(body), 200);

String ds(String version, {String id = 'a'}) =>
    jsonEncode(datasetJson(version: version, facilities: [facilityJson(id: id)]));

void main() {
  final remote = Uri.parse('https://example.org/facilities.json');

  FacilityRepository repo({
    String bundled = '',
    MemoryDatasetCache? cache,
    MockClient? client,
    Uri? url,
  }) =>
      FacilityRepository(
        loadBundled: () async => bundled.isEmpty ? ds('2026-10-01T00:00:00Z', id: 'bundled') : bundled,
        cache: cache ?? MemoryDatasetCache(),
        remoteUrl: url ?? remote,
        client: client ?? MockClient((_) async => http.Response('', 500)),
        timeout: const Duration(milliseconds: 200),
      );

  group('load', () {
    test('저장본이 없으면 기본본', () async {
      final d = await repo().load();
      expect(d.facilities.single.id, 'bundled');
    });

    test('저장본이 더 새 것이면 저장본', () async {
      final cache = MemoryDatasetCache(ds('2026-11-01T00:00:00Z', id: 'cached'));
      expect((await repo(cache: cache).load()).facilities.single.id, 'cached');
    });

    test('저장본이 더 오래됐으면 기본본 (앱 업데이트로 기본본이 새로워진 경우)', () async {
      final cache = MemoryDatasetCache(ds('2026-01-01T00:00:00Z', id: 'cached'));
      expect((await repo(cache: cache).load()).facilities.single.id, 'bundled');
    });

    test('저장본이 깨졌으면 기본본', () async {
      final cache = MemoryDatasetCache('{not json');
      expect((await repo(cache: cache).load()).facilities.single.id, 'bundled');
    });
  });

  group('refresh', () {
    test('더 새 버전이면 교체하고 저장', () async {
      final cache = MemoryDatasetCache();
      final r = repo(
        cache: cache,
        client: MockClient((_) async => http.Response.bytes(utf8.encode(ds('2026-11-02T00:00:00Z', id: '새데이터')), 200)),
      );
      await r.load();
      expect(await r.refresh(), UpdateResult.updated);
      expect(r.current!.facilities.single.id, '새데이터');
      expect(cache.value, contains('새데이터'));
    });

    test('같거나 오래된 버전이면 교체하지 않음', () async {
      final r = repo(client: MockClient((_) async => ok(ds('2026-10-01T00:00:00Z', id: 'same'))));
      await r.load();
      expect(await r.refresh(), UpdateResult.alreadyLatest);
      expect(r.current!.facilities.single.id, 'bundled');
    });

    test('서버 오류면 기존 데이터 유지', () async {
      final r = repo();
      await r.load();
      expect(await r.refresh(), UpdateResult.failed);
      expect(r.current!.facilities.single.id, 'bundled');
    });

    test('깨진 응답이면 기존 데이터 유지, 저장하지 않음', () async {
      final cache = MemoryDatasetCache();
      final r = repo(cache: cache, client: MockClient((_) async => http.Response('<html>', 200)));
      await r.load();
      expect(await r.refresh(), UpdateResult.failed);
      expect(cache.value, isNull);
    });

    test('시설이 0개인 응답은 거부 (실수로 빈 파일 배포 방지)', () async {
      final empty = jsonEncode(datasetJson(version: '2026-12-01T00:00:00Z', facilities: []));
      final r = repo(client: MockClient((_) async => ok(empty)));
      await r.load();
      expect(await r.refresh(), UpdateResult.failed);
    });

    test('네트워크 예외·시간 초과면 failed', () async {
      final r1 = repo(client: MockClient((_) async => throw const SocketException('offline')));
      await r1.load();
      expect(await r1.refresh(), UpdateResult.failed);

      final r2 = repo(client: MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return ok(ds('2026-12-01T00:00:00Z'));
      }));
      await r2.load();
      expect(await r2.refresh(), UpdateResult.failed);
    });

    test('요청에 위치 정보를 담지 않는다', () async {
      Uri? requested;
      final r = repo(client: MockClient((req) async {
        requested = req.url;
        return http.Response('', 500);
      }));
      await r.load();
      await r.refresh();
      expect(requested, remote);
      expect(requested!.query, isEmpty);
    });

    group('바뀐 게 없으면 다시 받지 않는다 (ETag)', () {
      test('처음엔 표시 없이 요청하고, 받은 표시를 저장한다', () async {
        final cache = MemoryDatasetCache();
        final headers = <Map<String, String>>[];
        final r = repo(
          cache: cache,
          client: MockClient((req) async {
            headers.add(req.headers);
            return http.Response.bytes(utf8.encode(ds('2026-11-02T00:00:00Z', id: 'new')), 200,
                headers: {'etag': '"v2"'});
          }),
        );
        await r.load();
        expect(await r.refresh(), UpdateResult.updated);
        expect(headers.single.containsKey('If-None-Match'), isFalse);
        expect(cache.etag, '"v2"');
      });

      test('저장된 표시를 보내고, 304면 기존 데이터 그대로', () async {
        final cache = MemoryDatasetCache(ds('2026-11-02T00:00:00Z', id: 'cached'), '"v2"');
        String? sent;
        final r = repo(
          cache: cache,
          client: MockClient((req) async {
            sent = req.headers['If-None-Match'];
            return http.Response('', 304);
          }),
        );
        await r.load();
        expect(await r.refresh(), UpdateResult.alreadyLatest);
        expect(sent, '"v2"');
        expect(r.current!.facilities.single.id, 'cached');
        expect(cache.value, contains('cached'));
      });

      test('기본본과 같은 버전을 받아도 표시와 함께 저장한다 (다음부터 304)', () async {
        final cache = MemoryDatasetCache();
        final r = repo(
          cache: cache,
          client: MockClient((_) async =>
              http.Response.bytes(utf8.encode(ds('2026-10-01T00:00:00Z', id: 'same')), 200, headers: {'etag': '"v1"'})),
        );
        await r.load();
        expect(await r.refresh(), UpdateResult.alreadyLatest);
        expect(r.current!.facilities.single.id, 'bundled');
        expect(cache.etag, '"v1"');
        expect(cache.value, contains('same'));
      });

      test('더 오래된 버전은 저장하지 않는다', () async {
        final cache = MemoryDatasetCache(ds('2026-11-02T00:00:00Z', id: 'cached'), '"v2"');
        final r = repo(
          cache: cache,
          client: MockClient((_) async =>
              http.Response.bytes(utf8.encode(ds('2026-09-01T00:00:00Z', id: 'old')), 200, headers: {'etag': '"v0"'})),
        );
        await r.load();
        expect(await r.refresh(), UpdateResult.alreadyLatest);
        expect(cache.value, contains('cached'));
        expect(cache.etag, '"v2"');
      });

      test('저장본이 없으면 표시도 보내지 않는다', () async {
        final cache = MemoryDatasetCache(null, '"stale"');
        Map<String, String>? sent;
        final r = repo(
          cache: cache,
          client: MockClient((req) async {
            sent = req.headers;
            return http.Response('', 500);
          }),
        );
        await r.load();
        await r.refresh();
        expect(sent!.containsKey('If-None-Match'), isFalse);
      });
    });

    test('원격 주소가 없으면 disabled', () async {
      final r = FacilityRepository(
        loadBundled: () async => ds('2026-10-01T00:00:00Z'),
        cache: MemoryDatasetCache(),
      );
      await r.load();
      expect(await r.refresh(), UpdateResult.disabled);
    });
  });

  test('FileDatasetCache 쓰고 읽기', () async {
    final dir = await Directory.systemTemp.createTemp('majung');
    addTearDown(() => dir.delete(recursive: true));
    final cache = FileDatasetCache(File('${dir.path}/data.json'));
    expect(await cache.read(), isNull);
    await cache.write('{"a":1}');
    expect(await cache.read(), '{"a":1}');
    expect(await cache.readEtag(), isNull);
    await cache.write('{"a":2}', etag: '"x"');
    expect(await cache.readEtag(), '"x"');
    await cache.write('{"a":3}');
    expect(await cache.readEtag(), isNull, reason: '표시 없이 새로 쓰면 옛 표시를 지운다');
    expect(File('${dir.path}/data.json.tmp').existsSync(), isFalse);
  });
}
