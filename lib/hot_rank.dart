import 'dart:convert';
import 'package:dio/dio.dart';
import 'bridge.dart';
import 'client.dart';

class RankItem {
  final String id, name, cover, updateTime;
  final int songCount;
  RankItem({required this.id, required this.name, this.cover = '',
    this.updateTime = '', this.songCount = 0});
  factory RankItem.fromJson(Map j) => RankItem(
    id: j['id'].toString(), name: j['name'].toString(),
    cover: j['cover']?.toString() ?? '',
    updateTime: j['updateTime']?.toString() ?? '',
    songCount: int.tryParse('${j['songCount'] ?? 0}') ?? 0);
}

class RankService {
  static final RankService I = RankService._();
  RankService._();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15)));

  Future<List<RankItem>> list() async {
    final req = Bridge.I.call('ranks', 'build', {});
    if (req is! Map || req['url'] == null) return [];
    try {
      final r = await _dio.getUri(Uri.parse(req['url'].toString()));
      final raw = r.data is String ? r.data : jsonEncode(r.data);
      final data = Bridge.I.call('ranks', 'parse', raw);
      if (data is! List) return [];
      return data.whereType<Map>()
          .map((e) => RankItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) { return []; }
  }

  Future<List<Song>> songs(String rankId) async {
    final req = Bridge.I.call('rank_songs', 'build', {'rankId': rankId});
    if (req is! Map || req['url'] == null) return [];
    try {
      final r = await _dio.getUri(Uri.parse(req['url'].toString()));
      final raw = r.data is String ? r.data : jsonEncode(r.data);
      final data = Bridge.I.call('rank_songs', 'parse', raw);
      if (data is! List) return [];
      return data.whereType<Map>()
          .map((e) => Song.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) { return []; }
  }
}
