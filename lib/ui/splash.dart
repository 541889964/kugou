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
  State<SplashPage> createState() => _S();
}
class _S extends State<SplashPage> {
  String _st = '启动中…';
  double _p = 0;
  @override
  void initState() { super.initState(); _b(); }
  Future<void> _b() async {
    setState(() { _st = '加载配置…'; _p = 0.3; });
    await SignatureManager.I.init();
    await ModeManager.I.init();
    await PlaylistService.I.init();
    setState(() { _st = '检查更新…'; _p = 0.7; });
    Updater.I.check();
    setState(() { _p = 1.0; _st = '就绪'; });
    await Future.delayed(const Duration(milliseconds: 400));
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
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 40)]),
          child: const Icon(Icons.music_note, size: 80, color: Colors.white)),
        const SizedBox(height: 32),
        const Text('KuGou', style: TextStyle(color: Colors.white, fontSize: 42,
          fontWeight: FontWeight.w900, letterSpacing: 4)),
        const SizedBox(height: 12),
        Text('遇见更好的音乐', style: TextStyle(color: Colors.white.withOpacity(0.75),
          fontSize: 14, letterSpacing: 3)),
        const SizedBox(height: 60),
        SizedBox(width: 200, child: ClipRRect(borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(value: _p > 0 ? _p : null, minHeight: 5,
            backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white)))),
        const SizedBox(height: 18),
        Text(_st, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ]))));
  }
}
