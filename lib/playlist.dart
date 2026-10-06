import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'client.dart';

class PlaylistService extends ChangeNotifier {
  static final PlaylistService I = PlaylistService._();
  PlaylistService._();
  final List<Song> _songs = [];
  List<Song> get songs => List.unmodifiable(_songs);
  final Set<String> _hashSet = {};
  bool contains(Song s) => _hashSet.contains(s.hash);

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('playlist') ?? '[]';
    try {
      final list = jsonDecode(raw) as List;
      _songs.clear();
      for (final e in list) {
        if (e is Map) _songs.add(Song.fromJson(Map<String, dynamic>.from(e)));
      }
      _hashSet..clear()..addAll(_songs.map((s) => s.hash));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('playlist',
        jsonEncode(_songs.map((s) => s.toJson()).toList()));
  }

  Future<bool> toggle(Song s) async {
    if (_hashSet.contains(s.hash)) {
      _songs.removeWhere((x) => x.hash == s.hash);
      _hashSet.remove(s.hash);
      await _save();
      notifyListeners();
      return false;
    } else {
      _songs.insert(0, s);
      _hashSet.add(s.hash);
      await _save();
      notifyListeners();
      return true;
    }
  }

  Future<void> clear() async {
    _songs.clear(); _hashSet.clear();
    await _save(); notifyListeners();
  }
}
