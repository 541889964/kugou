import 'dart:convert';
import 'package:dio/dio.dart';
import 'mode_manager.dart';
import 'signature_manager.dart';

class Song {
  final String hash, name, singer, album, albumId;
  final int duration;
  final String? cover, audioId;
  final String? localPath;
  final bool isLocal;

  Song({required this.hash, required this.name, required this.singer,
    this.album = '', this.albumId = '', this.duration = 0,
    this.cover, this.audioId, this.localPath, this.isLocal = false});

  Map<String,dynamic> toJson() => {'hash':hash,'name':name,'singer':singer,
    'album':album,'albumId':albumId,'duration':duration,'cover':cover,'audioId':audioId};

  factory Song.fromJson(Map j) => Song(
    hash: (j['hash'] ?? j['FileHash'] ?? '').toString(),
    name: (j['name'] ?? j['songname'] ?? j['SongName'] ?? '未知').toString(),
    singer: (j['singer'] ?? j['singername'] ?? j['SingerName'] ?? '').toString(),
    album: (j['album'] ?? j['AlbumName'] ?? '').toString(),
    albumId: (j['albumId'] ?? j['AlbumID'] ?? '').toString(),
    duration: int.tryParse('${j['duration'] ?? j['Duration'] ?? 0}') ?? 0,
    cover: (j['cover'] ?? j['Image'] ?? '').toString().isEmpty ? null : (j['cover'] ?? j['Image']).toString(),
    audioId: (j['audioId'] ?? j['MixSongID'] ?? j['EMixSongID'] ?? '').toString().isEmpty
      ? null : (j['audioId'] ?? j['MixSongID'] ?? j['EMixSongID']).toString());
}

class KuGouApi {
  static final KuGouApi I = KuGouApi._();
  KuGouApi._();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));
  String? lastError;
  String get _base => ModeManager.I.backendUrl;
  String get _cookie {
    final u = SignatureManager.I.config!['user'] as Map;
    return <String>[
      if ((u['token'] ?? '').toString().isNotEmpty) 'token=${u['token']}',
      if ((u['userid'] ?? '').toString().isNotEmpty) 'userid=${u['userid']}',
      if ((u['dfid'] ?? '').toString().isNotEmpty) 'dfid=${u['dfid']}',
      if ((u['mid'] ?? '').toString().isNotEmpty) 'mid=${u['mid']}',
      'appid=${u['appid'] ?? "3116"}',
      'clientver=${u['clientver'] ?? "11590"}',
      'KG-FAKE=${u['kg_fake'] ?? u['userid'] ?? ""}',
    ].join('; ');
  }

  Future<List<Song>> search(String kw, {int page = 1, int pagesize = 30}) async {
    lastError = null;
    try {
      final r = await _dio.get('$_base/search',
        queryParameters: {'keywords': kw, 'type': 'song', 'page': page, 'pagesize': pagesize},
        options: Options(headers: {'Cookie': _cookie}));
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      final lists = (d['data']?['lists'] ?? d['data']?['info'] ?? []) as List;
      return lists.whereType<Map>()
        .map((e) => Song.fromJson(Map<String,dynamic>.from(e)))
        .where((s) => s.hash.isNotEmpty).toList();
    } catch (e) {
      lastError = '后端未启动: $e';
      return [];
    }
  }

  Future<Map?> getSongUrl(String hash, {String albumId = '', String? audioId}) async {
    try {
      final params = <String,dynamic>{'id': hash};
      if (audioId != null && audioId.isNotEmpty) params['album_audio_id'] = audioId;
      final r = await _dio.get('$_base/song/url',
        queryParameters: params,
        options: Options(headers: {'Cookie': _cookie}));
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      if (d is Map) {
        final u = d['data']?['url'] ?? d['url'];
        if (u is String && u.isNotEmpty) return {'url': u};
        if (u is List && u.isNotEmpty) return {'url': u[0].toString()};
        final bu = d['backupUrl'] ?? d['data']?['backupUrl'];
        if (bu is List && bu.isNotEmpty) return {'url': bu[0].toString()};
        if (d['error_code'] == 20018) return {'error':'VIP_ONLY','message':'切到概念版试试'};
      }
      return {'error':'NO_URL','message':'未返回 URL'};
    } catch (e) {
      return {'error':'BACKEND_ERR','message':'后端请求失败: $e'};
    }
  }

  Future<String?> getLyric(String hash, {int duration = 0}) async {
    try {
      final r = await _dio.get('$_base/lyric',
        queryParameters: {'id': hash},
        options: Options(headers: {'Cookie': _cookie}));
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      if (d is Map) return (d['data']?['lyric'] ?? d['data']?['decodeContent']) as String?;
      return null;
    } catch (_) { return null; }
  }

  Future<bool> verifyCookie() async {
    final u = SignatureManager.I.config!['user'] as Map;
    return (u['token'] ?? '').toString().length >= 20;
  }
}
