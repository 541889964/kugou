import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bridge.dart';
import '../mode_manager.dart';
import '../playlist.dart';
import '../updater.dart';
import 'theme.dart';
import 'first_launch.dart';
import 'home.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _S();
}

class _S extends State<SplashPage> {
  String _status = '正在初始化…';

  @override
  void initState() { super.initState(); _boot(); }

  Future<void> _boot() async {
    await Device.init();
    setState(() => _status = '加载配置…');
    await ModeManager.I.init();
    await PlaylistService.I.init();
    setState(() => _status = '检查更新…');
    await Updater.I.check();
    await Bridge.I.initFromCache();
    if (!mounted) return;
    final sp = await SharedPreferences.getInstance();
    final seen = sp.getBool('first_launch_done') ?? false;
    if (!seen) {
      await sp.setBool('first_launch_done', true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const FirstLaunchPage(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 400)));
    } else {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const RootPage(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 400)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.grad),
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.music_note, size: 96, color: Colors.white),
          const SizedBox(height: 20),
          const Text('KuGou', style: TextStyle(color: Colors.white,
            fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 2)),
          const SizedBox(height: 40),
          const SizedBox(width: 32, height: 32,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
          const SizedBox(height: 16),
          Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ])),
      ),
    );
  }
}
