import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../playlist.dart';
import '../player.dart';
import 'player_page.dart';
import 'theme.dart';

class PlaylistPage extends StatelessWidget {
  const PlaylistPage({super.key});
  @override
  Widget build(BuildContext context) {
    final pl = context.watch<PlaylistService>();
    return Scaffold(appBar: AppBar(
      title: Text('收藏 (${pl.songs.length})'),
      actions: [
        if (pl.songs.isNotEmpty) IconButton(
          icon: const Icon(Icons.play_arrow), tooltip: '全部播放',
          onPressed: () {
            PlayerService.I.playFromList(pl.songs.first, pl.songs);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => const PlayerPage()));
          }),
        if (pl.songs.isNotEmpty) IconButton(
          icon: const Icon(Icons.delete_sweep), tooltip: '清空',
          onPressed: () => _confirm(context)),
      ]),
      body: pl.songs.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.favorite_border, size: 72,
              color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('还没有收藏',
              style: TextStyle(color: Colors.white.withOpacity(0.55))),
          ]))
        : ListView.builder(itemCount: pl.songs.length, itemBuilder: (_, i) {
            final s = pl.songs[i];
            return ListTile(
              leading: ClipRRect(borderRadius: BorderRadius.circular(8),
                child: s.cover != null ? CachedNetworkImage(imageUrl: s.cover!,
                  width: 46, height: 46, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _ph()) : _ph()),
              title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(icon: const Icon(Icons.favorite,
                color: Colors.redAccent, size: 20), onPressed: () => pl.toggle(s)),
              onTap: () {
                PlayerService.I.playFromList(s, pl.songs, startIndex: i);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const PlayerPage()));
              });
          }));
  }
  Widget _ph() => Container(width: 46, height: 46, color: AppTheme.surfaceHigh,
    child: Icon(Icons.music_note, color: Colors.white.withOpacity(0.3)));
  void _confirm(BuildContext c) {
    showDialog(context: c, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('清空收藏？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        FilledButton(onPressed: () {
          PlaylistService.I.clear(); Navigator.pop(c);
        }, child: const Text('清空')),
      ]));
  }
}
