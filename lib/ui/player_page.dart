import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../player.dart';
import '../playlist.dart';
import '../downloader.dart';
import '../floating_lyric.dart';
import 'theme.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerService>();
    final s = p.current;
    if (s == null) return const Scaffold(body: Center(child: Text('无曲目')));
    final dur = p.duration ?? Duration.zero;
    final max = dur.inMilliseconds.toDouble();
    final cur = p.position.inMilliseconds.clamp(0, max.toInt()).toDouble();
    final pl = context.watch<PlaylistService>();
    final fav = pl.contains(s);
    final dl = context.watch<Downloader>();
    final t = dl.tasks[s.hash];

    return Scaffold(body: Container(
      decoration: const BoxDecoration(gradient: AppTheme.playerGrad),
      child: SafeArea(child: Column(children: [
        // 顶部
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [
          IconButton(icon: const Icon(Icons.keyboard_arrow_down, size: 28),
            onPressed: () => Navigator.pop(context)),
          const Spacer(),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('正在播放', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
            const SizedBox(height: 2),
            Text(s.album.isEmpty ? '未知专辑' : s.album,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.white38)),
          ]),
          const Spacer(),
          IconButton(
            icon: Icon(FloatingLyricService.I.active
              ? Icons.picture_in_picture_alt : Icons.picture_in_picture_alt_outlined,
              size: 24),
            tooltip: '悬浮歌词',
            onPressed: () async {
              if (FloatingLyricService.I.active) {
                await FloatingLyricService.I.hide();
              } else {
                final ok = await FloatingLyricService.I.show();
                if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('需要悬浮窗权限')));
              }
            }),
        ])),
        const Spacer(),
        // 封面
        Container(
          width: 290, height: 290,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: AppTheme.p.withOpacity(0.4), blurRadius: 60, spreadRadius: 2),
              const BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10)),
            ]),
          child: ClipRRect(borderRadius: BorderRadius.circular(28),
            child: s.cover != null
              ? CachedNetworkImage(imageUrl: s.cover!, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _ph())
              : _ph()),
        ),
        const SizedBox(height: 36),
        // 歌名歌手
        Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(children: [
            Text(s.name, maxLines: 2, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (s.isLocal)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.s.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text('本地', style: TextStyle(fontSize: 10, color: AppTheme.s))),
              if (s.isLocal) const SizedBox(width: 8),
              Flexible(child: Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.65)))),
            ]),
          ])),
        if (p.errorMsg != null) Padding(padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
          child: Text(p.errorMsg!, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
        const SizedBox(height: 28),
        // 进度条
        Padding(padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Slider(value: cur, max: max > 0 ? max : 1,
            onChanged: max > 0 ? (v) => p.seek(Duration(milliseconds: v.toInt())) : null,
            onChangeStart: (_) {}, onChangeEnd: (_) {})),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_f(p.position), style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.55))),
            Text(_f(dur), style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.55))),
          ])),
        const SizedBox(height: 22),
        // 控制按钮
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(iconSize: 32, icon: Icon(_mi(p.mode), color: Colors.white70),
            onPressed: () { p.cycleMode(); _toast(context, _mt(p.mode)); }),
          const SizedBox(width: 20),
          IconButton(iconSize: 48, icon: const Icon(Icons.skip_previous), onPressed: p.prev),
          const SizedBox(width: 20),
          Container(
            width: 76, height: 76,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.grad,
              boxShadow: [BoxShadow(color: AppTheme.p.withOpacity(0.4), blurRadius: 30, spreadRadius: 2)]),
            child: IconButton(iconSize: 44, color: Colors.white,
              icon: Icon(p.playing ? Icons.pause : Icons.play_arrow, size: 42),
              onPressed: p.toggle)),
          const SizedBox(width: 20),
          IconButton(iconSize: 48, icon: const Icon(Icons.skip_next), onPressed: p.next),
          const SizedBox(width: 20),
          // 下载按钮（本地音乐不显示）
          if (s.isLocal)
            const SizedBox(width: 32)
          else if (t == null)
            IconButton(iconSize: 32, icon: Icon(Icons.download_outlined, color: Colors.white70),
              onPressed: () async {
                final ok = await dl.download(s);
                if (context.mounted) _toast(context, ok ? '已开始下载' : '下载失败');
              })
          else if (t.status == 'done')
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 32)
          else if (t.status == 'failed')
            IconButton(iconSize: 32, icon: const Icon(Icons.refresh, color: Colors.redAccent),
              onPressed: () => dl.download(s))
          else Padding(padding: const EdgeInsets.all(6),
            child: SizedBox(width: 28, height: 28,
              child: CircularProgressIndicator(value: t.progress > 0 ? t.progress : null, strokeWidth: 3))),
        ]),
        const SizedBox(height: 20),
        // 歌词 + 收藏 + 歌词下载
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton.icon(
            onPressed: () => _showLyric(context, p),
            icon: const Icon(Icons.lyrics_outlined),
            label: const Text('歌词')),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () async {
              final a = await pl.toggle(s);
              if (context.mounted) _toast(context, a ? '已收藏' : '已取消');
            },
            icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
              color: fav ? Colors.redAccent : null),
            label: Text(fav ? '已收藏' : '收藏')),
          if (!s.isLocal) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () async {
                final ok = await dl.downloadLyric(s);
                if (context.mounted) _toast(context, ok ? '歌词已下载到音乐目录' : '歌词下载失败');
              },
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('下歌词')),
          ],
        ]),
        const Spacer(),
      ]))));
  }

  IconData _mi(PlayMode m) { switch (m) {
    case PlayMode.order: return Icons.repeat;
    case PlayMode.shuffle: return Icons.shuffle;
    case PlayMode.single: return Icons.repeat_one; } }
  String _mt(PlayMode m) { switch (m) {
    case PlayMode.order: return '顺序播放';
    case PlayMode.shuffle: return '随机播放';
    case PlayMode.single: return '单曲循环'; } }

  void _toast(BuildContext c, String s) {
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(s),
      duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating));
  }

  void _showLyric(BuildContext context, PlayerService p) {
    if (p.lyricLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无歌词')));
      return;
    }
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(expand: false, initialChildSize: 0.8, maxChildSize: 0.95,
        builder: (_, c) => _LyricSheet(player: p, scroll: c)));
  }

  Widget _ph() => Container(
    decoration: const BoxDecoration(gradient: AppTheme.discGrad),
    child: const Icon(Icons.music_note, size: 100, color: Colors.white54));

  static String _f(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _LyricSheet extends StatefulWidget {
  final PlayerService player;
  final ScrollController scroll;
  const _LyricSheet({required this.player, required this.scroll});
  @override
  State<_LyricSheet> createState() => _LyricSheetState();
}

class _LyricSheetState extends State<_LyricSheet> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.player,
      builder: (_, __) {
        final lines = widget.player.lyricLines;
        final cur = widget.player.currentLyricIndex;
        return ListView.builder(
          controller: widget.scroll,
          padding: const EdgeInsets.symmetric(vertical: 60),
          itemCount: lines.length,
          itemBuilder: (_, i) {
            final isCur = i == cur;
            return Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: isCur ? 18 : 14,
                  fontWeight: isCur ? FontWeight.bold : FontWeight.normal,
                  color: isCur ? AppTheme.p : Colors.white.withOpacity(0.5),
                  height: 1.5,
                ),
                child: Text(lines[i].text, textAlign: TextAlign.center),
              ));
          },
        );
      },
    );
  }
}
