import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../hot_rank.dart';
import '../client.dart';
import '../player.dart';
import '../playlist.dart';
import 'player_page.dart';

class HotRankPage extends StatefulWidget {
  const HotRankPage({super.key});
  @override
  State<HotRankPage> createState() => _HotRankPageState();
}

class _HotRankPageState extends State<HotRankPage> {
  List<RankItem> _ranks = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final r = await RankService.I.list();
    if (!mounted) return;
    setState(() { _ranks = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('热歌榜')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _ranks.isEmpty
                  ? const Center(child: Text('加载失败，下拉重试'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, crossAxisSpacing: 12,
                        mainAxisSpacing: 12, childAspectRatio: 0.85),
                      itemCount: _ranks.length,
                      itemBuilder: (_, i) => _card(_ranks[i]),
                    ),
            ),
    );
  }

  Widget _card(RankItem r) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => RankSongsPage(rank: r))),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4),
            blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(fit: StackFit.expand, children: [
            r.cover.isNotEmpty
                ? CachedNetworkImage(imageUrl: r.cover, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _ph())
                : _ph(),
            Container(decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.85)]))),
            Positioned(left: 12, right: 12, bottom: 12, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${r.songCount} 首', style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 11)),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  Widget _ph() => Container(color: Colors.white10,
      child: const Icon(Icons.music_note, size: 60, color: Colors.white24));
}

class RankSongsPage extends StatefulWidget {
  final RankItem rank;
  const RankSongsPage({super.key, required this.rank});
  @override
  State<RankSongsPage> createState() => _RankSongsPageState();
}

class _RankSongsPageState extends State<RankSongsPage> {
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final r = await RankService.I.songs(widget.rank.id);
    if (!mounted) return;
    setState(() { _songs = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.rank.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _songs.isEmpty
              ? const Center(child: Text('加载失败'))
              : ListView.builder(
                  itemCount: _songs.length,
                  itemBuilder: (_, i) {
                    final s = _songs[i];
                    return ListTile(
                      leading: SizedBox(width: 46, height: 46, child: Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: s.cover != null
                              ? CachedNetworkImage(imageUrl: s.cover!, width: 46, height: 46,
                                  fit: BoxFit.cover, errorWidget: (_, __, ___) => _ph())
                              : _ph(),
                        ),
                        Positioned(left: 0, top: 0, child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: i < 3 ? Colors.redAccent : Colors.black54,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8), bottomRight: Radius.circular(8))),
                          child: Text('${i + 1}', style: const TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )),
                      ])),
                      title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Consumer<PlaylistService>(builder: (_, pl, __) {
                          final fav = pl.contains(s);
                          return IconButton(icon: Icon(
                              fav ? Icons.favorite : Icons.favorite_border,
                              color: fav ? Colors.redAccent : Colors.white38, size: 20),
                              onPressed: () => pl.toggle(s));
                        }),
                        const Icon(Icons.play_circle_outline),
                      ]),
                      onTap: () {
                        PlayerService.I.playSong(s, list: _songs);
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
}
