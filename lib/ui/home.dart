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
import 'theme.dart';

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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.current != null) const _MiniPlayer(),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search), label: '搜索'),
              NavigationDestination(icon: Icon(Icons.whatshot_outlined),
                  selectedIcon: Icon(Icons.whatshot), label: '榜单'),
              NavigationDestination(icon: Icon(Icons.favorite_border),
                  selectedIcon: Icon(Icons.favorite), label: '收藏'),
              NavigationDestination(icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings), label: '设置'),
            ],
          ),
        ],
      ),
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
  final _focus = FocusNode();
  List<Song> _list = [];
  bool _loading = false;
  String _kw = '';

  @override
  void dispose() { _c.dispose(); _focus.dispose(); super.dispose(); }

  Future<void> _s() async {
    final kw = _c.text.trim();
    if (kw.isEmpty) return;
    _focus.unfocus();
    setState(() { _loading = true; _kw = kw; });
    final r = await KuGouClient.I.search(kw);
    if (!mounted) return;
    setState(() { _list = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(
                  color: AppTheme.primary.withOpacity(0.15),
                  blurRadius: 20, offset: const Offset(0, 4))]),
              child: TextField(
                controller: _c,
                focusNode: _focus,
                onSubmitted: (_) => _s(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '搜索歌曲 / 歌手 / 专辑',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _c.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _c.clear()))
                      : null),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          Expanded(child: _body()),
        ]),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_kw.isEmpty) return _empty();
    if (_list.isEmpty) return _noResult();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _list.length,
      itemBuilder: (_, i) => _songCard(_list[i], i));
  }

  Widget _empty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: AppTheme.grad.withOpacity(0.15)),
        child: Icon(Icons.graphic_eq,
            size: 56, color: Colors.white.withOpacity(0.35))),
      const SizedBox(height: 20),
      Text('开始你的音乐之旅',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7))),
      const SizedBox(height: 6),
      Text('或者去「榜单」看看热歌',
          style: TextStyle(fontSize: 12.5,
              color: Colors.white.withOpacity(0.35))),
    ]));

  Widget _noResult() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_off, size: 64, color: Colors.white.withOpacity(0.2)),
      const SizedBox(height: 16),
      Text('没有找到结果',
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5))),
    ]));

  Widget _songCard(Song s, int i) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04))),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            PlayerService.I.playSong(s, list: _list);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PlayerPage()));
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              _cover(s.cover, 52),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12,
                          color: Colors.white.withOpacity(0.5))),
                ])),
              Consumer<PlaylistService>(builder: (_, pl, __) {
                final fav = pl.contains(s);
                return IconButton(
                  icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                      color: fav ? Colors.redAccent : Colors.white38, size: 20),
                  onPressed: () async {
                    final added = await pl.toggle(s);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(added ? '已收藏' : '已取消'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))));
                    }
                  });
              }),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _cover(String? url, double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: AppTheme.surfaceHigh),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: url != null
          ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: AppTheme.surfaceHigh),
              errorWidget: (_, __, ___) => Icon(Icons.music_note,
                  color: Colors.white.withOpacity(0.2), size: size * 0.5))
          : Icon(Icons.music_note,
              color: Colors.white.withOpacity(0.2), size: size * 0.5),
    ));
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer();
  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerService>();
    final s = p.current!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PlayerPage())),
          child: SizedBox(height: 60, child: Row(children: [
            const SizedBox(width: 10),
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppTheme.surface),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: s.cover != null
                    ? CachedNetworkImage(imageUrl: s.cover!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.music_note))
                    : const Icon(Icons.music_note, size: 20))),
            const SizedBox(width: 10),
            Expanded(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5,
                        fontWeight: FontWeight.w500)),
                Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11,
                        color: Colors.white.withOpacity(0.5))),
              ])),
            if (p.loading)
              const Padding(padding: EdgeInsets.all(12),
                  child: SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)))
            else
              IconButton(onPressed: p.toggle, iconSize: 22,
                  icon: Icon(p.playing ? Icons.pause_circle_filled
                      : Icons.play_circle_filled)),
            IconButton(onPressed: p.next, iconSize: 22,
                icon: const Icon(Icons.skip_next)),
            const SizedBox(width: 4),
          ])),
        ),
      ),
    );
  }
}
