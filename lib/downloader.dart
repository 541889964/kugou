import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'kugou.dart';

class DownloadTask {
  final String hash, name, singer;
  double progress = 0;
  int received = 0, total = 0;
  String status = 'pending';
  String? error, filePath;
  DownloadTask({required this.hash, required this.name, required this.singer});
  String get display => singer.isEmpty ? name : '$name - $singer';
}

class Downloader extends ChangeNotifier {
  static final Downloader I = Downloader._();
  Downloader._();
  final Map<String, DownloadTask> _tasks = {};
  Map<String, DownloadTask> get tasks => Map.unmodifiable(_tasks);
  final Dio _dio = Dio();
  static const String _dir = '/storage/emulated/0/Music/KuGou';

  Future<bool> _perm() async {
    var s = await Permission.storage.status;
    if (s.isGranted) return true;
    s = await Permission.storage.request();
    if (s.isGranted) return true;
    var m = await Permission.manageExternalStorage.status;
    if (m.isGranted) return true;
    m = await Permission.manageExternalStorage.request();
    return m.isGranted;
  }

  String _safe(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  Future<bool> download(Song song) async {
    if (_tasks.containsKey(song.hash)) {
      final t = _tasks[song.hash]!;
      if (t.status == 'downloading' || t.status == 'done') return false;
    }
    final t = DownloadTask(hash: song.hash, name: song.name, singer: song.singer);
    _tasks[song.hash] = t; notifyListeners();
    try {
      if (!await _perm()) { t.status = 'failed'; t.error = '需要权限'; notifyListeners(); return false; }
      t.status = 'resolving'; notifyListeners();
      final r = await KuGouApi.I.getSongUrl(song.hash, albumId: song.albumId);
      if (r == null || r['error'] != null) {
        t.status = 'failed';
        t.error = r?['message']?.toString() ?? '获取失败';
        notifyListeners(); return false;
      }
      final url = r['url'] as String?;
      if (url == null || url.isEmpty) { t.status = 'failed'; t.error = '空链接'; notifyListeners(); return false; }
      String ext = '.mp3'; final low = url.toLowerCase();
      if (low.contains('.flac')) ext = '.flac';
      else if (low.contains('.m4a')) ext = '.m4a';
      final d = Directory(_dir); if (!await d.exists()) await d.create(recursive: true);
      final path = '$_dir/${_safe(t.display)}$ext';
      t.status = 'downloading'; notifyListeners();
      await _dio.download(url, path, onReceiveProgress: (r, tot) {
        t.received = r; t.total = tot;
        t.progress = tot > 0 ? r / tot : 0; notifyListeners();
      });
      t.status = 'done'; t.progress = 1.0; t.filePath = path; notifyListeners(); return true;
    } catch (e) {
      t.status = 'failed'; t.error = e.toString(); notifyListeners(); return false;
    }
  }

  void clearTask(String h) { _tasks.remove(h); notifyListeners(); }
  void clearAllDone() {
    _tasks.removeWhere((_, t) => t.status == 'done' || t.status == 'failed');
    notifyListeners();
  }
}
