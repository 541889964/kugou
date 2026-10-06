import 'package:flutter/material.dart';
import '../mode_manager.dart';
import '../playlist.dart';
import '../signature_manager.dart';
import '../updater.dart';
import 'theme.dart';
import 'home.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String _st = '启动中…';
  double _p = 0;

  @override
  void initState() { super.initState(); _boot(); }

  Future<void> _boot() async {
    setState(() { _st = '加载配置…'; _p = 0.3; });
    await SignatureManager.I.init();
    await ModeManager.I.init();
    await PlaylistService.I.init();
    setState(() { _st = '检查更新…'; _p = 0.7; });
    Updater.I.check();
    setState(() { _p = 1.0; _st = '就绪'; });
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const RootPage(),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 400)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Container(
      decoration: const BoxDecoration(gradient: AppTheme.grad),
      child: Center(child: Padding(padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15)),
            child: const Icon(Icons.music_note, size: 72, color: Colors.white)),
          const SizedBox(height: 28),
          const Text('KuGou', style: TextStyle(color: Colors.white,
            fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: 3)),
          const SizedBox(height: 8),
          Text('概念版 · 完整功能', style: TextStyle(
            color: Colors.white.withOpacity(0.7), fontSize: 13, letterSpacing: 2)),
          const SizedBox(height: 50),
          ClipRRect(borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: _p > 0 ? _p : null,
              minHeight: 4, backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white))),
          const SizedBox(height: 16),
          Text(_st, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ])))),
    );
  }
}
