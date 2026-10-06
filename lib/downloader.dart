import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'kugou.dart';
import 'mode_manager.dart';

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
  final _tasks = <String, DownloadTask>{};
  Map<String, DownloadTask> get tasks => Map.unmodifiable(_tasks);
  final _dio = Dio();
  static const _dir = '/storage/emulated/0/Music/KuGou';

  Future<bool> _perm() async {
    var s = await Permission.storage.status; if (s.isGranted) return true;
    s = await Permission.storage.request(); if (s.isGranted) return true;
    var m = await Permission.manageExternalStorage.status; if (m.isGranted) return true;
    m = await Permission.manageExternalStorage.request(); return m.isGranted;
  }
  String _safe(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  /// 下载音频
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
      final r = await KuGouApi.I.getSongUrl(song.hash, albumId: song.albumId, audioId: song.audioId);
      if (r == null || r['error'] != null) { t.status = 'failed'; t.error = r?['message']?.toString() ?? '失败'; notifyListeners(); return false; }
      final url = r['url'] as String?;
      if (url == null || url.isEmpty) { t.status = 'failed'; t.error = '空链接'; notifyListeners(); return false; }
      String ext = '.mp3';
      final low = url.toLowerCase();
      if (low.contains('.flac')) ext = '.flac';
      else if (low.contains('.m4a')) ext = '.m4a';
      final d = Directory(_dir);
      if (!await d.exists()) await d.create(recursive: true);
      final p = '$_dir/${_safe(t.display)}$ext';
      t.status = 'downloading'; notifyListeners();
      await _dio.download(url, p, onReceiveProgress: (r, tot) {
        t.received = r; t.total = tot;
        t.progress = tot > 0 ? r / tot : 0;
        notifyListeners();
      });
      t.status = 'done'; t.progress = 1.0; t.filePath = p;
      notifyListeners();
      // 下载完立刻下歌词
      await downloadLyric(song, audioPath: p);
      return true;
    } catch (e) {
      t.status = 'failed'; t.error = e.toString(); notifyListeners(); return false;
    }
  }

  /// 下载歌词到音频同目录（.lrc）
  Future<bool> downloadLyric(Song song, {String? audioPath}) async {
    try {
      if (!await _perm()) return false;
      String? audioFile = audioPath ?? _tasks[song.hash]?.filePath;
      // 若未指定，按文件名规则找
      if (audioFile == null) {
        final d = Directory(_dir);
        if (!await d.exists()) return false;
        final base = _safe(song.title);
        for (final f in d.listSync()) {
          if (f is File && f.path.contains(base)) { audioFile = f.path; break; }
        }
      }
      if (audioFile == null) return false;

      final l = await KuGouApi.I.getLyric(song.hash, duration: song.duration);
      if (l == null || l.isEmpty) return false;

      final lrcPath = audioFile.replaceAll(RegExp(r'\.[^.]+$'), '.lrc');
      await File(lrcPath).writeAsString(l);
      return true;
    } catch (_) { return false; }
  }

  void clearTask(String h) { _tasks.remove(h); notifyListeners(); }
  void clearAllDone() { _tasks.removeWhere((_, t) => t.status == 'done' || t.status == 'failed'); notifyListeners(); }
}
