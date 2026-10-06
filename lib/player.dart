import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'kugou.dart';
import 'lyric_parser.dart';

enum PlayMode { order, shuffle, single }

class PlayerService extends ChangeNotifier {
  static final PlayerService I = PlayerService._();
  PlayerService._();
  final player = AudioPlayer();
  final List<Song> queue = [];
  int idx = -1;
  PlayMode _mode = PlayMode.order;
  PlayMode get mode => _mode;
  void cycleMode() {
    _mode = PlayMode.values[(_mode.index + 1) % PlayMode.values.length];
    notifyListeners();
  }

  bool loading = false;
  String? errorMsg;
  String? lyric;
  List<LyricLine> lyricLines = [];
  int currentLyricIndex = 0;

  Song? get current => (idx >= 0 && idx < queue.length) ? queue[idx] : null;

  PlayerService() {
    player.playerStateStream.listen((_) => notifyListeners());
    player.positionStream.listen((_) {
      _updateLyric();
      notifyListeners();
    });
    player.durationStream.listen((_) => notifyListeners());
    player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) _autoNext();
    });
  }

  void _updateLyric() {
    if (lyricLines.isEmpty) return;
    final ms = player.position.inMilliseconds;
    int ni = 0;
    for (int i = lyricLines.length - 1; i >= 0; i--) {
      if (ms >= lyricLines[i].time) { ni = i; break; }
    }
    if (ni != currentLyricIndex) {
      currentLyricIndex = ni;
    }
  }

  void _autoNext() {
    switch (_mode) {
      case PlayMode.single:
        player.seek(Duration.zero); player.play(); break;
      case PlayMode.shuffle:
        if (queue.length > 1) {
          final r = Random(); int n;
          do { n = r.nextInt(queue.length); } while (n == idx);
          idx = n; _load();
        } break;
      case PlayMode.order:
        if (idx < queue.length - 1) { idx++; _load(); } break;
    }
  }

  Future<void> playSong(Song s, {List<Song>? list}) async {
    loading = true; errorMsg = null; lyric = null; lyricLines = []; currentLyricIndex = 0;
    notifyListeners();
    if (list != null) {
      queue.clear();
      queue.addAll(list);
      idx = queue.indexWhere((x) => x.hash == s.hash);
      if (idx < 0) { queue.insert(0, s); idx = 0; }
    } else {
      final e = queue.indexWhere((x) => x.hash == s.hash);
      if (e >= 0) { idx = e; } else { queue.add(s); idx = queue.length - 1; }
    }
    await _load();
  }

  Future<void> playFromList(Song s, List<Song> list, {int? i}) async {
    loading = true; errorMsg = null; lyric = null; lyricLines = []; currentLyricIndex = 0;
    notifyListeners();
    queue.clear();
    queue.addAll(list);
    idx = i ?? queue.indexWhere((x) => x.hash == s.hash);
    if (idx < 0) idx = 0;
    await _load();
  }

  Future<void> _load() async {
    final s = current;
    if (s == null) return;
    try {
      // 本地音乐直接播放
      if (s.isLocal && s.localPath != null) {
        if (!await File(s.localPath!).exists()) {
          errorMsg = '文件不存在'; loading = false; notifyListeners(); return;
        }
        await player.setFilePath(s.localPath!);
        await player.play();
        // 尝试读同目录 lrc 歌词
        await _loadLocalLyric(s.localPath!);
        loading = false;
        notifyListeners();
        return;
      }
      // 在线音乐走后端
      final r = await KuGouApi.I.getSongUrl(s.hash, albumId: s.albumId, audioId: s.audioId);
      if (r == null || r['error'] != null) {
        errorMsg = r?['message']?.toString() ?? '失败';
        loading = false; notifyListeners(); return;
      }
      final url = r['url'] as String?;
      if (url == null || url.isEmpty) { errorMsg = '空链接'; loading = false; notifyListeners(); return; }
      await player.setUrl(url);
      await player.play();
      KuGouApi.I.getLyric(s.hash, duration: s.duration).then((l) {
        lyric = l;
        lyricLines = l == null ? [] : LyricParser.parse(l);
        notifyListeners();
      });
    } catch (e) {
      errorMsg = '失败: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadLocalLyric(String audioPath) async {
    try {
      final lrcPath = audioPath.replaceAll(RegExp(r'\.[^.]+$'), '.lrc');
      final f = File(lrcPath);
      if (await f.exists()) {
        lyric = await f.readAsString();
        lyricLines = LyricParser.parse(lyric!);
      }
    } catch (_) {}
  }

  Future<void> toggle() async {
    if (player.playing) await player.pause(); else await player.play();
  }
  Future<void> next() async { _autoNext(); }
  Future<void> prev() async { if (idx > 0) { idx--; await _load(); } }
  Future<void> seek(Duration d) => player.seek(d);
  Duration get position => player.position;
  Duration? get duration => player.duration;
  bool get playing => player.playing;
}
