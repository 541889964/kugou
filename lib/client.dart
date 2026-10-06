import 'dart:convert';
import 'package:dio/dio.dart';
import 'bridge.dart';

class Song {
  final String hash, name, singer, album, albumId;
  final int duration;
  final String? cover;
  Song({required this.hash, required this.name, required this.singer,
    this.album = '', this.albumId = '', this.duration = 0, this.cover});
  String get title => singer.isEmpty ? name : '$name - $singer';
  Map<String, dynamic> toJson() => {
    'hash': hash, 'name': name, 'singer': singer, 'album': album,
    'albumId': albumId, 'duration': duration, 'cover': cover,
  };
  factory Song.fromJson(Map j) => Song(
    hash: (j['hash'] ?? '').toString(),
    name: (j['name'] ?? '未知').toString(),
    singer: (j['singer'] ?? '').toString(),
    album: (j['album'] ?? '').toString(),
    albumId: (j['albumId'] ?? '').toString(),
    duration: int.tryParse('${j['duration'] ?? 0}') ?? 0,
    cover: (j['cover'] ?? '').toString().isEmpty ? null : j['cover'],
  );
}

class KuGouClient {
  static final KuGouClient I = KuGouClient._();
  KuGouClient._();
  final Dio dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile'},
  ));

  Future<List<Song>> search(String kw, {int page = 1, int pagesize = 30}) async {
    final sources = Bridge.I.call('search', 'build',
        {'keyword': kw, 'page': page, 'pagesize': pagesize});
    if (sources is Map && sources['__cache'] != null) {
      final list = sources['__cache'];
      if (list is List) {
        return list.whereType<Map>().map((e) => Song.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.hash.isNotEmpty).toList();
      }
    }
    if (sources is! List || sources.isEmpty) return [];
    for (final src in sources) {
      if (src is! Map || src['url'] == null) continue;
      try {
        final r = await dio.request(src['url'].toString(),
          options: Options(method: (src['method'] ?? 'GET').toString(),
            headers: (src['headers'] as Map?)?.cast<String, dynamic>()));
        final raw = r.data is String ? r.data : jsonEncode(r.data);
        final parsed = Bridge.I.call('search', 'parse',
            {'sourceId': src['sourceId'], 'raw': raw, 'keyword': kw, 'page': page});
        if (parsed is List && parsed.isNotEmpty) {
          return parsed.whereType<Map>()
            .map((e) => Song.fromJson(Map<String, dynamic>.from(e)))
            .where((s) => s.hash.isNotEmpty).toList();
        }
      } catch (_) { continue; }
    }
    return [];
  }

  Future<Map?> getSongUrl(String hash, {String albumId = ''}) async {
    final sources = Bridge.I.call('song_url', 'build', {'hash': hash, 'albumId': albumId});
    if (sources is! List) return null;
    for (final src in sources) {
      if (src is! Map || src['url'] == null) continue;
      try {
        final r = await dio.request(src['url'].toString(),
          options: Options(method: (src['method'] ?? 'GET').toString(),
            headers: (src['headers'] as Map?)?.cast<String, dynamic>()));
        final raw = r.data is String ? r.data : jsonEncode(r.data);
        final parsed = Bridge.I.call('song_url', 'parse', {'raw': raw});
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      } catch (_) { continue; }
    }
    return null;
  }

  Future<String?> getLyric(String hash, {String albumId = '', int duration = 0}) async {
    final a = Bridge.I.call('lyric', 'build',
        {'hash': hash, 'albumId': albumId, 'duration': duration});
    if (a is! Map || a['url'] == null) return null;
    try {
      final r = await dio.request(a['url'].toString(),
        options: Options(method: (a['method'] ?? 'GET').toString(),
          headers: (a['headers'] as Map?)?.cast<String, dynamic>()));
      final raw = r.data is String ? r.data : jsonEncode(r.data);
      var p = Bridge.I.call('lyric', 'parse', raw);
      if (p is Map && p['__continue'] == true) {
        final b = Bridge.I.call('lyric', 'build',
            {'hash': hash, 'albumId': albumId, 'duration': duration});
        if (b is Map && b['url'] != null) {
          final r2 = await dio.request(b['url'].toString(),
            options: Options(method: (b['method'] ?? 'GET').toString(),
              headers: (b['headers'] as Map?)?.cast<String, dynamic>()));
          final raw2 = r2.data is String ? r2.data : jsonEncode(r2.data);
          p = Bridge.I.call('lyric', 'parse', raw2);
        }
      }
      if (p is String && p.isNotEmpty) return p;
    } catch (_) {}
    return null;
  }
}
