import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'client.dart';
import 'mode_manager.dart';

class DownloadTask {
  final String hash;
  final String name;
  final String singer;
  double progress = 0;
  int received = 0;
  int total = 0;
  String status = 'pending';
  String? error;
  String? filePath;

  DownloadTask({
    required this.hash,
    required this.name,
    required this.singer,
  });

  String get display => singer.isEmpty ? name : '$name - $singer';
}

class Downloader extends ChangeNotifier {
  static final Downloader I = Downloader._();
  Downloader._();

  final Map<String, DownloadTask> _tasks = {};
  Map<String, DownloadTask> get tasks => Map.unmodifiable(_tasks);

  final Dio _dio = Dio();

  static const String _downloadDir = '/storage/emulated/0/Music/KuGou';

  Future<bool> _ensurePermission() async {
    if (!Platform.isAndroid) return true;

    var s = await Permission.storage.status;
    if (s.isGranted) return true;

    s = await Permission.storage.request();
    if (s.isGranted) return true;

    var m = await Permission.manageExternalStorage.status;
    if (m.isGranted) return true;
    m = await Permission.manageExternalStorage.request();
    return m.isGranted;
  }

  String _safeName(String s) {
    return s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  Future<bool> download(Song song) async {
    if (_tasks.containsKey(song.hash)) {
      final t = _tasks[song.hash]!;
      if (t.status == 'downloading' || t.status == 'done') return false;
    }

    final task = DownloadTask(
      hash: song.hash,
      name: song.name,
      singer: song.singer,
    );
    _tasks[song.hash] = task;
    notifyListeners();

    try {
      if (!await _ensurePermission()) {
        task.status = 'failed';
        task.error = '需要存储权限';
        notifyListeners();
        return false;
      }

      task.status = 'resolving';
      notifyListeners();

      final r = await KuGouClient.I.getSongUrl(song.hash, albumId: song.albumId);
      if (r == null || r['error'] != null) {
        task.status = 'failed';
        task.error = r?['message']?.toString() ?? '无法获取链接';
        notifyListeners();
        return false;
      }
      final url = r['url'] as String?;
      if (url == null || url.isEmpty) {
        task.status = 'failed';
        task.error = '空链接';
        notifyListeners();
        return false;
      }

      // 确定扩展名
      String ext = '.mp3';
      final lower = url.toLowerCase();
      if (lower.contains('.flac')) {
        ext = '.flac';
      } else if (lower.contains('.m4a')) {
        ext = '.m4a';
      } else if (lower.contains('.ogg')) {
        ext = '.ogg';
      }

      final dir = Directory(_downloadDir);
      if (!await dir.exists()) await dir.create(recursive: true);

      final prefix = ModeManager.I.isLite ? '[概念版]' : '[普通版]';
      final fileName = '$prefix${_safeName(task.display)}$ext';
      final filePath = '$_downloadDir/$fileName';

      task.status = 'downloading';
      notifyListeners();

      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (rec, total) {
          task.received = rec;
          task.total = total;
          task.progress = total > 0 ? rec / total : 0;
          notifyListeners();
        },
      );

      task.status = 'done';
      task.progress = 1.0;
      task.filePath = filePath;
      notifyListeners();
      return true;
    } catch (e) {
      task.status = 'failed';
      task.error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearTask(String hash) {
    _tasks.remove(hash);
    notifyListeners();
  }

  void clearAllDone() {
    _tasks.removeWhere((_, t) => t.status == 'done' || t.status == 'failed');
    notifyListeners();
  }
}
