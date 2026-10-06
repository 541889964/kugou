import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'mode_manager.dart';
import 'signature_manager.dart';

class Song {
  final String hash, name, singer, album, albumId;
  final int duration;
  final String? cover;
  Song({required this.hash, required this.name, required this.singer,
    this.album = '', this.albumId = '', this.duration = 0, this.cover});
  Map<String, dynamic> toJson() => {'hash': hash, 'name': name,
    'singer': singer, 'album': album, 'albumId': albumId,
    'duration': duration, 'cover': cover};
  factory Song.fromJson(Map j) => Song(
    hash: (j['hash'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    singer: (j['singer'] ?? '').toString(),
    album: (j['album'] ?? '').toString(),
    albumId: (j['albumId'] ?? '').toString(),
    duration: (j['duration'] as num?)?.toInt() ?? 0,
    cover: j['cover']?.toString());
}

class KuGouApi {
  static final KuGouApi I = KuGouApi._();
  KuGouApi._();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'User-Agent': 'KuGou2012-11590-1-1-0-0-0-0-0'},
  ));
  Map<String, dynamic> get _u => SignatureManager.I.config!['user'] as Map<String, dynamic>;
  Map<String, dynamic> get _cfg => SignatureManager.I.config!;

  String _cookie() {
    final u = _u;
    return <String>[
      'token=${u['token'] ?? ''}',
      'userid=${u['userid'] ?? ''}',
      if ((u['dfid'] ?? '').toString().isNotEmpty) 'dfid=${u['dfid']}',
      if ((u['mid'] ?? '').toString().isNotEmpty) 'mid=${u['mid']}',
      if ((u['uuid'] ?? '').toString().isNotEmpty) 'uuid=${u['uuid']}',
      'appid=${u['appid'] ?? "3116"}',
      'clientver=${u['clientver'] ?? "11590"}',
      'KG-FAKE=${u['kg_fake'] ?? u['userid'] ?? ""}',
      'KUGOU_API_PLATFORM=lite',
    ].join('; ');
  }

  String _sign(Map<String, String> p, String salt) {
    final ks = p.keys.where((k) => k != 'signature' && (p[k] ?? '').isNotEmpty).toList()..sort();
    final sb = StringBuffer(salt);
    for (final k in ks) sb.write('$k=${p[k]}');
    sb.write(salt);
    return md5.convert(utf8.encode(sb.toString())).toString().toUpperCase();
  }

  String _qs(Map<String, String> p) => p.entries
      .where((e) => e.value.isNotEmpty)
      .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');

  Future<List<Song>> search(String kw, {int page = 1, int pagesize = 30}) async {
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
      'keyword': kw, 'page': '$page', 'pagesize': '$pagesize',
      'bitrate': '0', 'isfuzzy': '0', 'inputtype': '0',
      'platform': platform, 'filter': '10',
    };
    p['signature'] = _sign(p, salt);
    try {
      final r = await _dio.get('https://${sc['host']}${sc['path']}?${_qs(p)}',
          options: Options(headers: {'Cookie': _cookie()}));
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      final lists = d['data']?['lists'] as List? ?? d['data']?['info'] as List? ?? [];
      return lists.whereType<Map>().map((j) {
        var c = (j['Image'] ?? j['img'] ?? j['cover'] ?? '').toString();
        if (c.contains('{size}')) c = c.replaceAll('{size}', '400');
        var dur = int.tryParse('${j['Duration'] ?? j['duration'] ?? j['timelength'] ?? 0}') ?? 0;
        if (dur > 10000) dur ~/= 1000;
        var singer = (j['SingerName'] ?? j['singername'] ?? j['singer'] ?? '').toString();
        if (singer.isEmpty && j['Singers'] is List && (j['Singers'] as List).isNotEmpty) {
          singer = ((j['Singers'] as List)[0] as Map)['name']?.toString() ?? '';
        }
        return Song(
          hash: (j['FileHash'] ?? j['hash'] ?? '').toString(),
          name: (j['SongName'] ?? j['songname'] ?? j['name'] ?? '未知').toString(),
          singer: singer,
          album: (j['AlbumName'] ?? j['album_name'] ?? '').toString(),
          albumId: (j['AlbumID'] ?? j['album_id'] ?? '').toString(),
          duration: dur, cover: c.isEmpty ? null : c);
      }).where((s) => s.hash.isNotEmpty).toList();
    } catch (e) { print('[search] $e'); return []; }
  }

  Future<Map?> getSongUrl(String hash, {String albumId = ''}) async {
    final salt = _cfg['salt'] as String;
    final u = _u;
    final sc = _cfg['song_url'] as Map<String, dynamic>;

    // 方式 1: songinfo
    try {
      final p = <String, String>{
        'srcappid': '2919', 'clientver': u['clientver'].toString(),
        'clienttime': '${DateTime.now().millisecondsSinceEpoch}',
        'mid': u['mid'].toString(), 'dfid': u['dfid'].toString(),
        'uuid': u['uuid'].toString(), 'appid': u['appid'].toString(),
        'platid': '4', 'encode_album_audio_id': hash,
        'token': u['token'].toString(), 'userid': u['userid'].toString(),
      };
      p['signature'] = _sign(p, salt);
      final r = await _dio.get('https://${sc['songinfo_host']}${sc['songinfo_path']}?${_qs(p)}',
          options: Options(headers: {'Cookie': _cookie()}));
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      if (d is Map) {
        final pu = d['data']?['play_url'];
        if (pu != null && pu.toString().isNotEmpty) return {'url': pu.toString()};
      }
    } catch (_) {}

    // 方式 2: yy 老接口
    try {
      final p = <String, String>{
        'r': 'play/getdata', 'hash': hash, 'album_id': albumId,
        'dfid': u['dfid'].toString(), 'mid': u['mid'].toString(),
        'platid': '4', '_': '${DateTime.now().millisecondsSinceEpoch}',
      };
      final r = await _dio.get('https://${sc['yy_host']}${sc['yy_path']}?${_qs(p)}',
          options: Options(headers: {'Cookie': _cookie()}));
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      if (d is Map) {
        final pu = d['data']?['play_url'];
        if (pu != null && pu.toString().isNotEmpty) return {'url': pu.toString()};
        if (d['err_code'] != null) {
          return {'error': 'VIP_ONLY', 'message': 'err ${d['err_code']}'};
        }
      }
    } catch (_) {}

    return {'error': 'NO_URL', 'message': '无法获取播放链接'};
  }

  Future<String?> getLyric(String hash, {int duration = 0}) async {
    final lc = _cfg['lyric'] as Map<String, dynamic>;
    final u = _u;
    try {
      final p1 = <String, String>{'ver': '1', 'man': 'yes', 'client': 'mobi',
        'hash': hash, 'duration': '${duration * 1000}', 'mid': u['mid'].toString()};
      final r1 = await _dio.get('https://${lc['search_host']}${lc['search_path']}?${_qs(p1)}');
      final d1 = r1.data is String ? jsonDecode(r1.data) : r1.data;
      final cands = d1['candidates'] as List? ?? [];
      if (cands.isEmpty) return null;
      final c = cands[0] as Map;
      final p2 = <String, String>{'ver': '1', 'client': 'mobi',
        'id': c['id'].toString(), 'accesskey': c['accesskey'].toString(),
        'fmt': 'lrc', 'charset': 'utf8'};
      final r2 = await _dio.get('https://${lc['download_host']}${lc['download_path']}?${_qs(p2)}');
      final d2 = r2.data is String ? jsonDecode(r2.data) : r2.data;
      final content = d2['content'] as String?;
      if (content == null || content.isEmpty) return null;
      return utf8.decode(base64.decode(content));
    } catch (_) { return null; }
  }

  Future<bool> verifyCookie() async {
    final u = _u;
    if ((u['token'] ?? '').toString().length < 20) return false;
    try {
      final p = <String, String>{'r': 'user/info',
        'mid': u['mid'].toString(), 'dfid': u['dfid'].toString(),
        'platid': '4', '_': '${DateTime.now().millisecondsSinceEpoch}'};
      final r = await _dio.get('https://wwwapi.kugou.com/yy/index.php?${_qs(p)}',
          options: Options(headers: {'Cookie': _cookie()}));
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      if (d is Map) {
        final uid = d['data']?['userid'] ?? '0';
        return uid != '0' && uid.toString().isNotEmpty;
      }
      return false;
    } catch (_) { return false; }
  }
}
