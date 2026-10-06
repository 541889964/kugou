import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'kugou.dart';

class PlaylistService extends ChangeNotifier {
  static final PlaylistService I = PlaylistService._();
  PlaylistService._();
  final List<Song> _songs = [];
  List<Song> get songs => List.unmodifiable(_songs);
  final Set<String> _set = {};
  bool contains(Song s) => _set.contains(s.hash);

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    try {
      final list = jsonDecode(sp.getString('playlist') ?? '[]') as List;
      _songs.clear();
      for (final e in list) if (e is Map) _songs.add(Song.fromJson(Map<String, dynamic>.from(e)));
      _set..clear()..addAll(_songs.map((s) => s.hash)); notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('playlist', jsonEncode(_songs.map((s) => s.toJson()).toList()));
  }

  Future<bool> toggle(Song s) async {
    if (_set.contains(s.hash)) {
      _songs.removeWhere((x) => x.hash == s.hash);
      _set.remove(s.hash); await _save(); notifyListeners(); return false;
    }
    _songs.insert(0, s);
    _set.add(s.hash); await _save(); notifyListeners(); return true;
  }

  Future<void> clear() async { _songs.clear(); _set.clear(); await _save(); notifyListeners(); }
}
