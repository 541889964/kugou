import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../kugou.dart';
import '../player.dart';
import '../playlist.dart';
import '../downloader.dart';
import '../mode_manager.dart';
import 'player_page.dart';
import 'playlist_page.dart';
import 'downloads_page.dart';
import 'settings.dart';
import 'theme.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerService>();
    return Scaffold(
      body: IndexedStack(index: _tab, children: const [
        HomePage(), PlaylistPage(), DownloadsPage(), SettingsPage()]),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (p.current != null) const _MiniPlayer(),
        NavigationBar(selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search), label: '搜索'),
            NavigationDestination(icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite), label: '收藏'),
            NavigationDestination(icon: Icon(Icons.download_outlined),
              selectedIcon: Icon(Icons.download), label: '下载'),
            NavigationDestination(icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings), label: '设置'),
          ])),
      ]));
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _c = TextEditingController();
  List<Song> _l = [];
  bool _loading = false;
  String _kw = '';

  Future<void> _s() async {
    final kw = _c.text.trim(); if (kw.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _kw = kw; });
    final r = await KuGouApi.I.search(kw);
    if (!mounted) return;
    setState(() { _l = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<ModeManager>();
    return Scaffold(body: SafeArea(child: Column(children: [
      Container(margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: (m.isLite ? AppTheme.primary : AppTheme.secondary).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(m.isLite ? Icons.diamond_outlined : Icons.music_note_outlined,
            size: 14, color: m.isLite ? AppTheme.primary : AppTheme.secondary),
          const SizedBox(width: 6),
          Text(m.isLite ? '概念版' : '普通版', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: m.isLite ? AppTheme.primary : AppTheme.secondary)),
        ])),
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(controller: _c, onSubmitted: (_) => _s(),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: '搜索歌曲 / 歌手',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _c.text.isNotEmpty ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _c.clear())) : null),
          onChanged: (_) => setState(() {}))),
      Expanded(child: _body()),
    ])));
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_kw.isEmpty) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.graphic_eq, size: 64, color: Colors.white.withOpacity(0.3)),
      const SizedBox(height: 16),
      Text('输入关键词开始搜索', style: TextStyle(color: Colors.white.withOpacity(0.6))),
    ]));
    if (_l.isEmpty) return Center(child: Text('没有找到结果',
      style: TextStyle(color: Colors.white.withOpacity(0.5))));
    return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _l.length, itemBuilder: (_, i) => _card(_l[i]));
  }

  Widget _card(Song s) => Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    decoration: BoxDecoration(color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.04))),
    child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(16),
      child: InkWell(borderRadius: BorderRadius.circular(16),
        onTap: () {
          PlayerService.I.playSong(s, list: _l);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
        },
        child: Padding(padding: const EdgeInsets.all(10),
          child: Row(children: [
            _cover(s.cover, 52),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
              ])),
            Consumer<Downloader>(builder: (_, dl, __) {
              final t = dl.tasks[s.hash];
              if (t != null) {
                if (t.status == 'done') return const Icon(Icons.check_circle,
                  color: Colors.greenAccent, size: 22);
                if (t.status == 'failed') return IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 20),
                  onPressed: () => dl.download(s));
                return Padding(padding: const EdgeInsets.all(10),
                  child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                      value: t.progress > 0 ? t.progress : null, strokeWidth: 2)));
              }
              return IconButton(icon: Icon(Icons.download_outlined,
                color: Colors.white.withOpacity(0.5), size: 20),
                onPressed: () => dl.download(s));
            }),
            Consumer<PlaylistService>(builder: (_, pl, __) {
              final fav = pl.contains(s);
              return IconButton(icon: Icon(
                fav ? Icons.favorite : Icons.favorite_border,
                color: fav ? Colors.redAccent : Colors.white38, size: 20),
                onPressed: () => pl.toggle(s));
            }),
          ])))));
  Widget _cover(String? u, double s) => Container(width: s, height: s,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
      color: AppTheme.surfaceHigh),
    child: ClipRRect(borderRadius: BorderRadius.circular(12),
      child: u != null ? CachedNetworkImage(imageUrl: u, fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Icon(Icons.music_note,
          color: Colors.white.withOpacity(0.2), size: s * 0.5))
        : Icon(Icons.music_note, color: Colors.white.withOpacity(0.2), size: s * 0.5)));
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer();
  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerService>();
    final s = p.current!;
    return Container(margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(14),
        child: InkWell(borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PlayerPage())),
          child: SizedBox(height: 60, child: Row(children: [
            const SizedBox(width: 10),
            Container(width: 42, height: 42, decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10), color: AppTheme.surface),
              child: ClipRRect(borderRadius: BorderRadius.circular(10),
                child: s.cover != null ? CachedNetworkImage(imageUrl: s.cover!,
                  fit: BoxFit.cover, errorWidget: (_, __, ___) =>
                    const Icon(Icons.music_note))
                  : const Icon(Icons.music_note, size: 20))),
            const SizedBox(width: 10),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
              Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5))),
            ])),
            if (p.loading) const Padding(padding: EdgeInsets.all(12),
              child: SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)))
            else IconButton(onPressed: p.toggle, iconSize: 22,
              icon: Icon(p.playing ? Icons.pause_circle_filled : Icons.play_circle_filled)),
            IconButton(onPressed: p.next, iconSize: 22, icon: const Icon(Icons.skip_next)),
            const SizedBox(width: 4),
          ])))),
    );
  }
}
