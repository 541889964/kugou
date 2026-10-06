import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'mode_manager.dart';
import 'signature_manager.dart';

class Song {
  final String hash, name, singer, album, albumId;
  final int duration;
  final String? cover;
  final String? audioId;

  Song({
    required this.hash,
    required this.name,
    required this.singer,
    this.album = '',
    this.albumId = '',
    this.duration = 0,
    this.cover,
    this.audioId,
  });

  Map<String, dynamic> toJson() => {
    'hash': hash, 'name': name, 'singer': singer, 'album': album,
    'albumId': albumId, 'duration': duration, 'cover': cover,
    'audioId': audioId,
  };

  factory Song.fromJson(Map j) => Song(
    hash: (j['hash'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    singer: (j['singer'] ?? '').toString(),
    album: (j['album'] ?? '').toString(),
    albumId: (j['albumId'] ?? '').toString(),
    duration: (j['duration'] as num?)?.toInt() ?? 0,
    cover: j['cover']?.toString(),
    audioId: j['audioId']?.toString(),
  );
}

class KuGouApi {
  static final KuGouApi I = KuGouApi._();
  KuGouApi._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  String? lastError;

  Map<String, dynamic> get _u => SignatureManager.I.config!['user'] as Map<String, dynamic>;
  Map<String, dynamic> get _cfg => SignatureManager.I.config!;

  String _ua() {
    final u = _u;
    final mid = (u['mid'] ?? '').toString();
    final cv = (u['clientver'] ?? '11590').toString();
    // 真实酷狗 Android App UA 格式
    return 'Android13-Xiaomi-2201123C-kuqusic-$cv-$mid-0-0-0-0-0-0';
  }

  String _cookie() {
    final u = _u;
    final parts = <String>[];
    if ((u['token'] ?? '').toString().isNotEmpty) parts.add('token=${u['token']}');
    if ((u['userid'] ?? '').toString().isNotEmpty) parts.add('userid=${u['userid']}');
    if ((u['dfid'] ?? '').toString().isNotEmpty) parts.add('dfid=${u['dfid']}');
    if ((u['mid'] ?? '').toString().isNotEmpty) parts.add('mid=${u['mid']}');
    if ((u['uuid'] ?? '').toString().isNotEmpty) parts.add('uuid=${u['uuid']}');
    parts.add('appid=${u['appid'] ?? "3116"}');
    parts.add('clientver=${u['clientver'] ?? "11590"}');
    parts.add('KG-FAKE=${u['kg_fake'] ?? u['userid'] ?? ""}');
    return parts.join('; ');
  }

  String _sign(Map<String, String> p, String salt) {
    final ks = p.keys
        .where((k) => k != 'signature' && (p[k] ?? '').isNotEmpty)
        .toList()
      ..sort();
    final sb = StringBuffer(salt);
    for (final k in ks) {
      sb.write('$k=${p[k]}');
    }
    sb.write(salt);
    return md5.convert(utf8.encode(sb.toString())).toString().toUpperCase();
  }

  String _qs(Map<String, String> p) {
    return p.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  // ============================================================
  // 搜索
  // ============================================================
  Future<List<Song>> search(String kw, {int page = 1, int pagesize = 30}) async {
    lastError = null;
    final sc = _cfg['search'] as Map<String, dynamic>;
    final salt = _cfg['salt'] as String;
    final platform = ModeManager.I.isLite
        ? sc['platform_lite'] as String
        : sc['platform_standard'] as String;
    final u = _u;

    final p = <String, String>{
      'srcappid': sc['srcappid'].toString(),
      'clientver': sc['clientver'].toString(),
      'appid': sc['appid'].toString(),
      'platid': sc['platid'].toString(),
      'userid': u['userid'].toString(),
      'token': u['token'].toString(),
      'mid': u['mid'].toString(),
      'dfid': u['dfid'].toString(),
      'uuid': u['uuid'].toString(),
      'clienttime': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
      'keyword': kw,
      'page': '$page',
      'pagesize': '$pagesize',
      'bitrate': '0',
      'isfuzzy': '0',
      'inputtype': '0',
      'platform': platform,
      'filter': '10',
    };
    p['signature'] = _sign(p, salt);

    final url = 'https://${sc['host']}${sc['path']}?${_qs(p)}';

    try {
      final r = await _dio.get(url, options: Options(headers: {
        'Cookie': _cookie(),
        'User-Agent': _ua(),
        'Referer': 'https://www.kugou.com/',
      }));
      final raw = r.data is String ? r.data : jsonEncode(r.data);
      final d = jsonDecode(raw);

      final data = d['data'];
      if (data == null) {
        lastError = '响应无 data: ${raw.toString().substring(0, raw.toString().length > 300 ? 300 : raw.toString().length)}';
        return [];
      }

      final lists = data['lists'] as List? ?? data['info'] as List? ?? [];
      if (lists.isEmpty) {
        lastError = '返回 0 条';
        return [];
      }

      return lists.whereType<Map>().map((j) {
        var c = (j['Image'] ?? j['img'] ?? j['cover'] ?? '').toString();
        if (c.contains('{size}')) c = c.replaceAll('{size}', '400');
        var dur = int.tryParse(
                '${j['Duration'] ?? j['duration'] ?? j['timelength'] ?? 0}') ??
            0;
        if (dur > 10000) dur ~/= 1000;
        var singer =
            (j['SingerName'] ?? j['singername'] ?? j['singer'] ?? '').toString();
        if (singer.isEmpty &&
            j['Singers'] is List &&
            (j['Singers'] as List).isNotEmpty) {
          singer = ((j['Singers'] as List)[0] as Map)['name']?.toString() ?? '';
        }
        // 关键：EMixSongID 是播放接口要的 audio_id
        final audioId = (j['EMixSongID'] ??
                j['MixSongID'] ??
                j['audio_id'] ??
                j['Audioid'] ??
                '')
            .toString();
        return Song(
          hash: (j['FileHash'] ?? j['hash'] ?? '').toString(),
          name: (j['SongName'] ?? j['songname'] ?? j['name'] ?? '未知').toString(),
          singer: singer,
          album: (j['AlbumName'] ?? j['album_name'] ?? '').toString(),
          albumId: (j['AlbumID'] ?? j['album_id'] ?? '').toString(),
          duration: dur,
          cover: c.isEmpty ? null : c,
          audioId: audioId.isEmpty ? null : audioId,
        );
      }).where((s) => s.hash.isNotEmpty).toList();
    } catch (e) {
      lastError = '异常: $e';
      return [];
    }
  }

  // ============================================================
  // 获取播放地址（多种方式）
  // ============================================================
  Future<Map?> getSongUrl(String hash,
      {String albumId = '', String? audioId}) async {
    final salt = _cfg['salt'] as String;
    final u = _u;
    final sc = _cfg['song_url'] as Map<String, dynamic>;
    final ua = _ua();
    final cookie = _cookie();

    // 方式 1: trackercdn（最简单，不需要登录）
    try {
      final key = md5
          .convert(utf8.encode('kgcloudv2$hash'))
          .toString()
          .substring(0, 16);
      final url =
          'https://trackercdn.kugou.com/i/v2/?hash=$hash&key=$key&pid=2&behavior=play&cmd=25&version=9108';
      final r = await _dio.get(url, options: Options(headers: {
        'User-Agent': ua,
      }));
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      if (d is Map) {
        final urls = d['url'];
        if (urls is List && urls.isNotEmpty) {
          final pu = urls[0].toString();
          if (pu.isNotEmpty) return {'url': pu};
        }
      }
    } catch (_) {}

    // 方式 2: play/songinfo（需要 audioId）
    if (audioId != null && audioId.isNotEmpty) {
      try {
        final p = <String, String>{
          'srcappid': '2919',
          'clientver': (u['clientver'] ?? '11590').toString(),
          'clienttime': '${DateTime.now().millisecondsSinceEpoch}',
          'mid': u['mid'].toString(),
          'dfid': u['dfid'].toString(),
          'uuid': (u['uuid'] ?? '-').toString(),
          'appid': (u['appid'] ?? '3116').toString(),
          'platid': '4',
          'encode_album_audio_id': audioId,
          'token': u['token'].toString(),
          'userid': u['userid'].toString(),
        };
        p['signature'] = _sign(p, salt);
        final url =
            'https://${sc['songinfo_host']}${sc['songinfo_path']}?${_qs(p)}';
        final r = await _dio.get(url, options: Options(headers: {
          'Cookie': cookie,
          'User-Agent': ua,
          'Referer': 'https://www.kugou.com/',
        }));
        final d = r.data is String ? jsonDecode(r.data) : r.data;
        if (d is Map) {
          final pu = d['data']?['play_url'];
          if (pu != null && pu.toString().isNotEmpty) {
            return {'url': pu.toString()};
          }
        }
      } catch (_) {}
    }

    // 方式 3: yy/index.php 老接口（带完整参数）
    try {
      final p = <String, String>{
        'r': 'play/getdata',
        'hash': hash,
        'album_id': albumId,
        'dfid': u['dfid'].toString(),
        'mid': u['mid'].toString(),
        'platid': '4',
        '_': '${DateTime.now().millisecondsSinceEpoch}',
      };
      final url = 'https://${sc['yy_host']}${sc['yy_path']}?${_qs(p)}';
      final r = await _dio.get(url, options: Options(headers: {
        'Cookie': cookie,
        'User-Agent': ua,
        'Referer': 'https://www.kugou.com/',
        'x-router': 'trackercdn.kugou.com',
      }));
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      if (d is Map) {
        final pu = d['data']?['play_url'];
        if (pu != null && pu.toString().isNotEmpty) {
          return {'url': pu.toString()};
        }
        final err = d['err_code'];
        if (err != null) {
          return {'error': 'ERR_$err', 'message': '接口拒绝 (err_code=$err)'};
        }
      }
    } catch (_) {}

    return {'error': 'NO_URL', 'message': '所有方式都失败'};
  }

  // ============================================================
  // 歌词
  // ============================================================
  Future<String?> getLyric(String hash, {int duration = 0}) async {
    final lc = _cfg['lyric'] as Map<String, dynamic>;
    final u = _u;
    try {
      final p1 = <String, String>{
        'ver': '1', 'man': 'yes', 'client': 'mobi',
        'hash': hash, 'duration': '${duration * 1000}',
        'mid': u['mid'].toString(),
      };
      final r1 = await _dio.get(
          'https://${lc['search_host']}${lc['search_path']}?${_qs(p1)}');
      final d1 = r1.data is String ? jsonDecode(r1.data) : r1.data;
      final cands = d1['candidates'] as List? ?? [];
      if (cands.isEmpty) return null;
      final c = cands[0] as Map;
      final p2 = <String, String>{
        'ver': '1', 'client': 'mobi',
        'id': c['id'].toString(),
        'accesskey': c['accesskey'].toString(),
        'fmt': 'lrc', 'charset': 'utf8',
      };
      final r2 = await _dio.get(
          'https://${lc['download_host']}${lc['download_path']}?${_qs(p2)}');
      final d2 = r2.data is String ? jsonDecode(r2.data) : r2.data;
      final content = d2['content'] as String?;
      if (content == null || content.isEmpty) return null;
      return utf8.decode(base64.decode(content));
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // 用户校验
  // ============================================================
  Future<bool> verifyCookie() async {
    final u = _u;
    if ((u['token'] ?? '').toString().length < 20) return false;
    try {
      final p = <String, String>{
        'r': 'user/info',
        'mid': u['mid'].toString(),
        'dfid': u['dfid'].toString(),
        'platid': '4',
        '_': '${DateTime.now().millisecondsSinceEpoch}',
      };
      final r = await _dio.get(
          'https://wwwapi.kugou.com/yy/index.php?${_qs(p)}',
          options: Options(headers: {
            'Cookie': _cookie(),
            'User-Agent': _ua(),
            'Referer': 'https://www.kugou.com/',
          }));
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
}
