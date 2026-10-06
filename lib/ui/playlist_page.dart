import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../playlist.dart';
import '../player.dart';
import 'player_page.dart';

class PlaylistPage extends StatelessWidget {
  const PlaylistPage({super.key});
  @override
  Widget build(BuildContext context) {
    final pl = context.watch<PlaylistService>();
    return Scaffold(
      appBar: AppBar(
        title: Text('播放列表 (${pl.songs.length})'),
        actions: [
          if (pl.songs.isNotEmpty)
            IconButton(icon: const Icon(Icons.play_arrow), tooltip: '全部播放',
              onPressed: () {
                PlayerService.I.playFromList(pl.songs.first, pl.songs);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PlayerPage()));
              }),
          if (pl.songs.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_sweep), tooltip: '清空',
              onPressed: () => _confirmClear(context)),
        ],
      ),
      body: pl.songs.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.favorite_border, size: 72, color: Colors.white24),
              SizedBox(height: 16),
              Text('还没有收藏歌曲', style: TextStyle(color: Colors.white54)),
              SizedBox(height: 6),
              Text('搜索结果点♡即可加入', style: TextStyle(fontSize: 12, color: Colors.white30)),
            ]))
          : ListView.builder(
              itemCount: pl.songs.length,
              itemBuilder: (_, i) {
                final s = pl.songs[i];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: s.cover != null
                        ? CachedNetworkImage(imageUrl: s.cover!, width: 46, height: 46,
                            fit: BoxFit.cover, errorWidget: (_, __, ___) => _ph())
                        : _ph(),
                  ),
                  title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.redAccent),
                    onPressed: () => pl.toggle(s),
                  ),
                  onTap: () {
                    PlayerService.I.playFromList(s, pl.songs, startIndex: i);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PlayerPage()));
                  },
                );
              },
            ),
    );
  }

  Widget _ph() => Container(width: 46, height: 46, color: Colors.white10,
      child: const Icon(Icons.music_note, color: Colors.white30));

  void _confirmClear(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('清空播放列表？'),
      content: const Text('所有收藏的歌曲都会被移除'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: () {
          PlaylistService.I.clear(); Navigator.pop(context);
        }, child: const Text('清空')),
      ],
    ));
  }
}
