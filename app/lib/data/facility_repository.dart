import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/dataset.dart';

/// 기기에 저장된 최신 데이터 한 벌을 읽고 쓰는 곳.
///
/// [etag]는 서버가 그 데이터에 붙인 표시다. 다음 요청에 함께 보내면 서버는 바뀐 게
/// 없을 때 본문 없이 304만 돌려준다 (데이터 요금 절약).
abstract class DatasetCache {
  Future<String?> read();
  Future<String?> readEtag();
  Future<void> write(String json, {String? etag});
}

class FileDatasetCache implements DatasetCache {
  FileDatasetCache(this.file);
  final File file;

  File get _etagFile => File('${file.path}.etag');

  @override
  Future<String?> read() async => await file.exists() ? file.readAsString() : null;

  @override
  Future<String?> readEtag() async {
    // 데이터 파일이 없으면 표시도 의미가 없다 (304를 받아도 쓸 저장본이 없음).
    if (!await file.exists() || !await _etagFile.exists()) return null;
    final tag = (await _etagFile.readAsString()).trim();
    return tag.isEmpty ? null : tag;
  }

  /// 임시 파일에 쓴 뒤 이름을 바꿔, 쓰다 끊겨도 기존 파일이 깨지지 않게 한다.
  /// 표시는 데이터 다음에 쓴다. 중간에 끊기면 옛 표시가 남아 다음에 한 번 더 받을 뿐이다.
  @override
  Future<void> write(String json, {String? etag}) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(file.path);
    if (etag == null) {
      if (await _etagFile.exists()) await _etagFile.delete();
    } else {
      await _etagFile.writeAsString(etag, flush: true);
    }
  }
}

class MemoryDatasetCache implements DatasetCache {
  MemoryDatasetCache([this.value, this.etag]);
  String? value;
  String? etag;

  @override
  Future<String?> read() async => value;

  @override
  Future<String?> readEtag() async => value == null ? null : etag;

  @override
  Future<void> write(String json, {String? etag}) async {
    value = json;
    this.etag = etag;
  }
}

enum UpdateResult { updated, alreadyLatest, failed, disabled }

/// 데이터 우선순위: 기기 저장본(더 새 것이면) > 앱에 들어 있는 기본본.
/// 원격 업데이트는 더 새 버전일 때만 교체하고, 실패하면 기존 데이터를 그대로 둔다.
///
/// 사용자 위치는 이 클래스에 절대 들어오지 않는다(요청에 좌표 없음).
class FacilityRepository {
  FacilityRepository({
    required Future<String> Function() loadBundled,
    required this.cache,
    this.remoteUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  })  : _loadBundled = loadBundled,
        _client = client ?? http.Client();

  final Future<String> Function() _loadBundled;
  final DatasetCache cache;
  final Uri? remoteUrl;
  final http.Client _client;
  final Duration timeout;

  Dataset? _current;
  Dataset? get current => _current;

  /// 네트워크 없이 바로 쓸 수 있는 데이터를 준비한다.
  Future<Dataset> load() async {
    final bundled = Dataset.fromJson(_decode(await _loadBundled()));
    Dataset best = bundled;
    try {
      final cached = await cache.read();
      if (cached != null) {
        final fromCache = Dataset.fromJson(_decode(cached));
        if (fromCache.version.isAfter(bundled.version)) best = fromCache;
      }
    } on Object {
      // 저장본이 깨졌으면 기본본을 쓴다.
    }
    return _current = best;
  }

  /// 원격에서 새 데이터를 받아온다. 어떤 실패도 예외로 던지지 않는다.
  ///
  /// 앱을 다시 열 때마다 불리므로, 저장본의 표시(ETag)를 보내 바뀐 게 없으면
  /// 본문을 받지 않는다(304).
  Future<UpdateResult> refresh() async {
    final url = remoteUrl;
    if (url == null) return UpdateResult.disabled;
    try {
      String? etag;
      try {
        etag = await cache.readEtag();
      } on Object {
        etag = null;
      }
      final response = await _client
          .get(url, headers: {'If-None-Match': ?etag})
          .timeout(timeout);
      if (response.statusCode == 304) return UpdateResult.alreadyLatest;
      if (response.statusCode != 200) return UpdateResult.failed;
      final body = utf8.decode(response.bodyBytes);
      final incoming = Dataset.fromJson(_decode(body));
      if (incoming.facilities.isEmpty) return UpdateResult.failed;
      final existing = _current;
      final newer = existing == null || incoming.version.isAfter(existing.version);
      // 같은 버전이어도 저장해 둔다. 그래야 표시가 생겨 다음부터 304로 끝난다.
      // 더 오래된 버전(서버 되돌림)은 저장하지 않는다.
      if (newer || !existing.version.isAfter(incoming.version)) {
        await cache.write(body, etag: response.headers['etag']);
      }
      if (!newer) return UpdateResult.alreadyLatest;
      _current = incoming;
      return UpdateResult.updated;
    } on Object {
      return UpdateResult.failed;
    }
  }

  static Map<String, dynamic> _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('데이터 형식 오류');
    return Map<String, dynamic>.from(decoded);
  }
}
