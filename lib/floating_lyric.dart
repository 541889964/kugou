import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'player.dart';
import 'lyric_parser.dart';

class FloatingLyricService {
  static final FloatingLyricService I = FloatingLyricService._();
  FloatingLyricService._();

  bool _active = false;
  bool get active => _active;
  LyricData? _lyrics;
  String _lastHash = '';

  Future<bool> show() async {
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      final granted = await FlutterOverlayWindow.requestPermission();
      if (granted != true) return false;
    }
    if (_active) return true;
    await FlutterOverlayWindow.showOverlay(
      height: 130, width: WindowSize.matchParent,
      alignment: OverlayAlignment.centerBottom,
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      enableDrag: true,
      positionGravity: PositionGravity.none,
      overlayTitle: 'KuGou 歌词',
      overlayContent: '悬浮歌词',
    );
    _active = true;
    _watch();
    return true;
  }

  Future<void> hide() async {
    if (_active) await FlutterOverlayWindow.closeOverlay();
    _active = false;
  }

  void _watch() {
    PlayerService.I.addListener(() async {
      if (!_active) return;
      final p = PlayerService.I;
      final s = p.current;
      if (s == null) return;
      if (s.hash != _lastHash) {
        _lastHash = s.hash;
        final raw = p.lyric;
        _lyrics = raw != null && raw.isNotEmpty
            ? LyricData.parse(raw) : LyricData([]);
      }
      int idx = 0;
      if (_lyrics != null && _lyrics!.lines.isNotEmpty) {
        idx = _lyrics!.indexAt(p.position.inMilliseconds);
      }
      final cur = (_lyrics != null && idx < _lyrics!.lines.length)
          ? _lyrics!.lines[idx].text : '';
      final next = (_lyrics != null && idx + 1 < _lyrics!.lines.length)
          ? _lyrics!.lines[idx + 1].text : '';
      try {
        await FlutterOverlayWindow.updateOverlay(
          {'cur': cur, 'next': next, 'title': s.name, 'playing': p.playing});
      } catch (_) {}
    });
  }
}
