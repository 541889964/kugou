import 'package:flutter/material.dart';
import '../bridge.dart';
import '../mode_manager.dart';
import '../playlist.dart';
import '../updater.dart';
import 'theme.dart';
import 'home.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Device.init();
    await ModeManager.I.init();
    await PlaylistService.I.init();
    Updater.I.check();
    await Bridge.I.initFromCache();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const RootPage(),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 500)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.grad),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15)),
                child: const Icon(Icons.music_note, size: 72, color: Colors.white)),
              const SizedBox(height: 28),
              const Text('KuGou',
                  style: TextStyle(color: Colors.white, fontSize: 38,
                    fontWeight: FontWeight.w800, letterSpacing: 3)),
              const SizedBox(height: 8),
              Text('遇见更好的音乐',
                  style: TextStyle(color: Colors.white.withOpacity(0.7),
                    fontSize: 13, letterSpacing: 2)),
              const SizedBox(height: 50),
              const SizedBox(width: 28, height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5)),
            ],
          ),
        ),
      ),
    );
  }
}
