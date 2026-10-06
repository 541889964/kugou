import 'dart:convert';
import 'package:dio/dio.dart';
import 'mode_manager.dart';

class Song {
  final String hash, name, singer, album, albumId;
  final int duration;
  final String? cover;

  Song({
    required this.hash,
    required this.name,
    required this.singer,
    this.album = '',
    this.albumId = '',
    this.duration = 0,
    this.cover,
  });

  String get title => singer.isEmpty ? name : '$name - $singer';

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'name': name,
        'singer': singer,
        'album': album,
        'albumId': albumId,
        'duration': duration,
        'cover': cover,
      };

  factory Song.fromJson(Map j) => Song(
        hash: (j['FileHash'] ?? j['hash'] ?? j['filehash'] ?? '').toString(),
        name: (j['SongName'] ??
                j['songname'] ??
                j['name'] ??
                j['FileName'] ??
                '未知')
            .toString(),
        singer: (j['SingerName'] ??
                j['singername'] ??
                j['singer'] ??
                j['author_name'] ??
                '')
            .toString(),
        album: (j['AlbumName'] ?? j['album_name'] ?? j['albumName'] ?? '').toString(),
        albumId: (j['AlbumID'] ?? j['album_id'] ?? j['albumId'] ?? '').toString(),
        duration: _parseDuration(j),
        cover: _parseCover(j),
      );

  static int _parseDuration(Map j) {
    final d = j['Duration'] ?? j['duration'] ?? j['timelength'] ?? 0;
    int v = 0;
    if (d is int) {
      v = d;
    } else if (d is num) {
      v = d.toInt();
    } else {
      v = int.tryParse(d.toString()) ?? 0;
    }
    if (v > 10000) v = v ~/ 1000;
    return v;
  }

  static String? _parseCover(Map j) {
    final c = j['Image'] ?? j['img'] ?? j['cover'] ?? j['ImageUrl'];
    if (c == null) return null;
    final s = c.toString();
    if (s.isEmpty) return null;
    if (s.contains('{size}')) return s.replaceAll('{size}', '400');
    return s;
  }
}

class KuGouClient {
  static final KuGouClient I = KuGouClient._();
  KuGouClient._();

  final Dio dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'User-Agent': 'KuGouApp/11.0'},
  ));

  String get _base => ModeManager.I.baseUrl;
  String get _cookie => ModeManager.I.cookie;

  Future<bool> verifyCookie() async {
    if (_cookie.isEmpty) return false;
    if (!_cookie.contains('userid=') || !_cookie.contains('token=')) return false;
    try {
      final r = await dio.get('$_base/user/detail',
          options: Options(headers: {'Cookie': _cookie}));
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      if (d is Map) {
        final uid = d['data']?['userid'] ?? '0';
        return uid != '0' && uid.toString().isNotEmpty;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<Song>> search(String kw, {int page = 1, int pagesize = 30}) async {
    try {
      final r = await dio.get('$_base/search',
          queryParameters: {
            'keywords': kw,
            'page': page,
            'pagesize': pagesize,
          },
          options: Options(headers: {'Cookie': _cookie}));
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      final lists = d['data']?['lists'] as List? ?? [];
      return lists
          .whereType<Map>()
          .map((e) => Song.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.hash.isNotEmpty)
          .toList();
    } catch (e) {
      print('[search] $e');
      return [];
    }
  }

  /// 返回 {url: "...", br: 320} 或 {error: "VIP_ONLY", message: "..."}
  Future<Map?> getSongUrl(String hash, {String albumId = ''}) async {
    try {
      final r = await dio.get('$_base/song/url',
          queryParameters: {'id': hash},
          options: Options(headers: {'Cookie': _cookie}));
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      if (d is Map) {
        final data = d['data'];
        if (data is Map && data['url'] != null && data['url'].toString().isNotEmpty) {
          return {
            'url': data['url'].toString(),
            'br': data['br'] ?? 320,
          };
        }
        if (d['url'] != null && d['url'].toString().isNotEmpty) {
          return {'url': d['url'].toString()};
        }
        return {'error': 'NO_URL', 'message': '无播放链接'};
      }
      return null;
    } catch (e) {
      print('[url] $e');
      return null;
    }
  }

  Future<String?> getLyric(String hash) async {
    try {
      final r = await dio.get('$_base/lyric',
          queryParameters: {'id': hash},
          options: Options(headers: {'Cookie': _cookie}));
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      if (d is Map) {
        return (d['data']?['lyric'] ??
                d['data']?['decodeContent'] ??
                d['lyric']) as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> checkBackend() async {
    try {
      final r = await dio.get('$_base/',
          options: Options(receiveTimeout: const Duration(seconds: 3)));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
