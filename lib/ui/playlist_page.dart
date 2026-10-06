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
    return Scaffold(
      appBar: AppBar(title: Text('收藏 (${pl.songs.length})'), actions: [
        if (pl.songs.isNotEmpty) IconButton(icon: const Icon(Icons.play_arrow),
          onPressed: () {
            PlayerService.I.playFromList(pl.songs.first, pl.songs);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
          }),
        if (pl.songs.isNotEmpty) IconButton(icon: const Icon(Icons.delete_sweep),
          onPressed: () => pl.clear()),
      ]),
      body: pl.songs.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 20),
            Text('还没有收藏歌曲', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 15)),
            const SizedBox(height: 8),
            Text('点击 ♡ 加入收藏', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
          ]))
        : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: pl.songs.length, itemBuilder: (_, i) {
            final s = pl.songs[i];
            return Container(margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.04))),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: s.cover != null
                    ? CachedNetworkImage(imageUrl: s.cover!, width: 48, height: 48,
                        fit: BoxFit.cover, errorWidget: (_, __, ___) => _ph())
                    : _ph()),
                title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
                subtitle: Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
                trailing: IconButton(icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                  onPressed: () => pl.toggle(s)),
                onTap: () {
                  PlayerService.I.playFromList(s, pl.songs, i: i);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
                },
              ));
          }));
  }
  Widget _ph() => Container(width: 48, height: 48, decoration: const BoxDecoration(gradient: AppTheme.discGrad),
    child: const Icon(Icons.music_note, color: Colors.white54, size: 24));
}
