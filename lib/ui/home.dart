import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../client.dart';
import '../player.dart';
import '../playlist.dart';
import 'player_page.dart';
import 'hot_rank_page.dart';
import 'playlist_page.dart';
import 'settings.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _tab = 0;
  static const _pages = [HomePage(), HotRankPage(), PlaylistPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerService>();
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (p.current != null) const _MiniPlayer(),
        NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.search), label: '搜索'),
            NavigationDestination(icon: Icon(Icons.whatshot), label: '榜单'),
            NavigationDestination(icon: Icon(Icons.favorite), label: '收藏'),
            NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
          ],
        ),
      ]),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _c = TextEditingController();
  List<Song> _list = [];
  bool _loading = false;
  String _kw = '';

  Future<void> _s() async {
    final kw = _c.text.trim();
    if (kw.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _kw = kw; });
    final r = await KuGouClient.I.search(kw);
    if (!mounted) return;
    setState(() { _list = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _c,
              onSubmitted: (_) => _s(),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: '搜索歌曲 / 歌手 / 专辑',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(vertical: 0),
              ),
            )),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsPage())),
            ),
          ]),
        ),
        Expanded(child: _body()),
      ])),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_kw.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.queue_music, size: 96, color: Colors.white24),
        SizedBox(height: 16),
        Text('输入关键词开始搜索', style: TextStyle(color: Colors.white54)),
        SizedBox(height: 6),
        Text('或者去「榜单」看看热歌', style: TextStyle(fontSize: 12, color: Colors.white30)),
      ]));
    }
    if (_list.isEmpty) return const Center(child: Text('没有找到结果'));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: _list.length,
      itemBuilder: (_, i) {
        final s = _list[i];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: s.cover != null
                  ? CachedNetworkImage(imageUrl: s.cover!, width: 52, height: 52,
                      fit: BoxFit.cover, errorWidget: (_, __, ___) => _ph())
                  : _ph(),
            ),
            title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Consumer<PlaylistService>(builder: (_, pl, __) {
                final fav = pl.contains(s);
                return IconButton(
                  icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                      color: fav ? Colors.redAccent : Colors.white38, size: 20),
                  onPressed: () async {
                    final added = await pl.toggle(s);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(added ? '已收藏' : '已取消收藏'),
                        duration: const Duration(seconds: 1)));
                    }
                  },
                );
              }),
              const Icon(Icons.play_circle_outline),
            ]),
            onTap: () {
              PlayerService.I.playSong(s, list: _list);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
            },
          ),
        );
      },
    );
  }

  Widget _ph() => Container(width: 52, height: 52, color: Colors.white10,
      child: const Icon(Icons.music_note, color: Colors.white30));
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer();
  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerService>();
    final s = p.current!;
    return Material(
      color: const Color(0xFF1A1726),
      child: InkWell(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PlayerPage())),
        child: SizedBox(height: 66, child: Row(children: [
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: s.cover != null
                ? CachedNetworkImage(imageUrl: s.cover!, width: 44, height: 44,
                    fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.music_note))
                : const Icon(Icons.music_note),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: Colors.white54)),
          ])),
          if (p.loading)
            const Padding(padding: EdgeInsets.all(12),
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(onPressed: p.toggle,
                icon: Icon(p.playing ? Icons.pause : Icons.play_arrow)),
          IconButton(onPressed: p.next, icon: const Icon(Icons.skip_next)),
          const SizedBox(width: 4),
        ])),
      ),
    );
  }
}
