import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../player.dart';
import '../playlist.dart';
import '../downloader.dart';
import 'theme.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  IconData _mi(PlayMode m) { switch (m) {
    case PlayMode.order: return Icons.repeat;
    case PlayMode.shuffle: return Icons.shuffle;
    case PlayMode.single: return Icons.repeat_one; } }
  String _mt(PlayMode m) { switch (m) {
    case PlayMode.order: return '顺序';
    case PlayMode.shuffle: return '随机';
    case PlayMode.single: return '单曲'; } }

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
        Row(children: [
          IconButton(icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () => Navigator.pop(context)),
          const Spacer(),
          const Text('正在播放', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          const SizedBox(width: 48),
        ]),
        const Spacer(),
        Container(width: 270, height: 270, decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Colors.black54,
            blurRadius: 40, spreadRadius: 2)]),
          child: ClipRRect(borderRadius: BorderRadius.circular(24),
            child: s.cover != null ? CachedNetworkImage(imageUrl: s.cover!,
              fit: BoxFit.cover, errorWidget: (_, __, ___) => _ph())
              : _ph())),
        const SizedBox(height: 32),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(children: [
            Text(s.name, maxLines: 2, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(s.singer, style: TextStyle(fontSize: 14,
              color: Colors.white.withOpacity(0.6))),
          ])),
        if (p.errorMsg != null) Padding(
          padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
          child: Text(p.errorMsg!, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
        const SizedBox(height: 22),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Slider(value: cur, max: max > 0 ? max : 1,
            onChanged: max > 0 ? (v) => p.seek(Duration(milliseconds: v.toInt())) : null)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_f(p.position), style: TextStyle(fontSize: 12,
              color: Colors.white.withOpacity(0.55))),
            Text(_f(dur), style: TextStyle(fontSize: 12,
              color: Colors.white.withOpacity(0.55))),
          ])),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(iconSize: 30, icon: Icon(_mi(p.mode), color: Colors.white70),
            onPressed: () { p.cycleMode();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(_mt(p.mode)),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating)); }),
          const SizedBox(width: 12),
          IconButton(iconSize: 42, icon: const Icon(Icons.skip_previous),
            onPressed: p.prev),
          const SizedBox(width: 16),
          Container(decoration: const BoxDecoration(shape: BoxShape.circle,
            gradient: AppTheme.grad),
            child: IconButton(iconSize: 44, color: Colors.white,
              icon: Icon(p.playing ? Icons.pause : Icons.play_arrow),
              onPressed: p.toggle)),
          const SizedBox(width: 16),
          IconButton(iconSize: 42, icon: const Icon(Icons.skip_next),
            onPressed: p.next),
          const SizedBox(width: 12),
          if (t == null) IconButton(iconSize: 30,
            icon: Icon(Icons.download_outlined, color: Colors.white70),
            onPressed: () => dl.download(s))
          else if (t.status == 'done')
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 30)
          else if (t.status == 'failed') IconButton(iconSize: 30,
            icon: const Icon(Icons.refresh, color: Colors.redAccent),
            onPressed: () => dl.download(s))
          else Padding(padding: const EdgeInsets.all(6),
            child: SizedBox(width: 26, height: 26,
              child: CircularProgressIndicator(
                value: t.progress > 0 ? t.progress : null, strokeWidth: 2.5))),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton.icon(onPressed: () {
            if (p.lyric != null && p.lyric!.isNotEmpty) {
              showModalBottomSheet(context: context, isScrollControlled: true,
                backgroundColor: AppTheme.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => DraggableScrollableSheet(
                  expand: false, initialChildSize: 0.75, maxChildSize: 0.95,
                  builder: (_, c) => Padding(padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(controller: c,
                      child: Text(p.lyric!, style: const TextStyle(
                        fontSize: 15, height: 1.9))))));
            } else ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('暂无歌词')));
          }, icon: const Icon(Icons.lyrics_outlined), label: const Text('歌词')),
          const SizedBox(width: 12),
          TextButton.icon(onPressed: () async {
            final a = await pl.toggle(s);
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(a ? '已收藏' : '已取消'),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating));
          }, icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
            color: fav ? Colors.redAccent : null),
            label: Text(fav ? '已收藏' : '收藏')),
        ]),
        const Spacer(),
      ]))));
  }

  Widget _ph() => Container(color: AppTheme.surfaceHigh,
    child: Icon(Icons.music_note, size: 90, color: Colors.white.withOpacity(0.24)));

  static String _f(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
