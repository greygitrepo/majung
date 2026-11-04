import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/dataset.dart';

/// 기기에 저장된 최신 데이터 한 벌을 읽고 쓰는 곳.
abstract class DatasetCache {
  Future<String?> read();
  Future<void> write(String json);
}

class FileDatasetCache implements DatasetCache {
  FileDatasetCache(this.file);
  final File file;

  @override
  Future<String?> read() async => await file.exists() ? file.readAsString() : null;

  /// 임시 파일에 쓴 뒤 이름을 바꿔, 쓰다 끊겨도 기존 파일이 깨지지 않게 한다.
  @override
  Future<void> write(String json) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(file.path);
  }
}

class MemoryDatasetCache implements DatasetCache {
  MemoryDatasetCache([this.value]);
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String json) async => value = json;
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
  Future<UpdateResult> refresh() async {
    final url = remoteUrl;
    if (url == null) return UpdateResult.disabled;
    try {
      final response = await _client.get(url).timeout(timeout);
      if (response.statusCode != 200) return UpdateResult.failed;
      final body = utf8.decode(response.bodyBytes);
      final incoming = Dataset.fromJson(_decode(body));
      if (incoming.facilities.isEmpty) return UpdateResult.failed;
      final existing = _current;
      if (existing != null && !incoming.version.isAfter(existing.version)) {
        return UpdateResult.alreadyLatest;
      }
      await cache.write(body);
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
