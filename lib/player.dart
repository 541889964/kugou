import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'kugou.dart';

enum PlayMode { order, shuffle, single }

class PlayerService extends ChangeNotifier {
  static final PlayerService I = PlayerService._();
  PlayerService._();
  final AudioPlayer player = AudioPlayer();
  final List<Song> queue = [];
  int idx = -1;
  PlayMode _mode = PlayMode.order;
  PlayMode get mode => _mode;
  void cycleMode() {
    _mode = PlayMode.values[(_mode.index + 1) % PlayMode.values.length];
    notifyListeners();
  }
  void setMode(PlayMode m) { _mode = m; notifyListeners(); }

  bool loading = false;
  String? errorMsg, lyric;
  Song? get current => (idx >= 0 && idx < queue.length) ? queue[idx] : null;

  PlayerService() {
    player.playerStateStream.listen((_) => notifyListeners());
    player.positionStream.listen((_) => notifyListeners());
    player.durationStream.listen((_) => notifyListeners());
    player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) _autoNext();
    });
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
    loading = true; errorMsg = null; lyric = null; notifyListeners();
    if (list != null) {
      queue..clear()..addAll(list);
      idx = queue.indexWhere((x) => x.hash == s.hash);
      if (idx < 0) { queue.insert(0, s); idx = 0; }
    } else {
      final e = queue.indexWhere((x) => x.hash == s.hash);
      if (e >= 0) idx = e; else { queue.add(s); idx = queue.length - 1; }
    }
    await _load();
  }

  Future<void> playFromList(Song s, List<Song> list, {int? startIndex}) async {
    loading = true; errorMsg = null; lyric = null; notifyListeners();
    queue..clear()..addAll(list);
    idx = startIndex ?? queue.indexWhere((x) => x.hash == s.hash);
    if (idx < 0) idx = 0;
    await _load();
  }

  Future<void> _load() async {
    final s = current; if (s == null) return;
    try {
      final r = await KuGouApi.I.getSongUrl(s.hash, albumId: s.albumId);
      if (r == null) { errorMsg = '无法获取'; loading = false; notifyListeners(); return; }
      if (r['error'] != null) { errorMsg = r['message']?.toString() ?? '不可播'; loading = false; notifyListeners(); return; }
      final url = r['url'] as String?;
      if (url == null || url.isEmpty) { errorMsg = '空链接'; loading = false; notifyListeners(); return; }
      await player.setUrl(url); await player.play();
      KuGouApi.I.getLyric(s.hash, duration: s.duration).then((l) { lyric = l; notifyListeners(); });
    } catch (e) { errorMsg = '失败: $e'; }
    finally { loading = false; notifyListeners(); }
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
