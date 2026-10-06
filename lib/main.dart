import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:provider/provider.dart';
import 'mode_manager.dart';
import 'player.dart';
import 'playlist.dart';
import 'ui/theme.dart';
import 'ui/splash.dart';

@pragma("vm:entry-point")
void overlayMain() {
  runApp(const _OverlayApp());
}

class _OverlayApp extends StatefulWidget {
  const _OverlayApp();
  @override
  State<_OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<_OverlayApp> {
  String _cur = '', _next = '', _title = '';

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map) {
        setState(() {
          _cur = event['cur']?.toString() ?? '';
          _next = event['next']?.toString() ?? '';
          _title = event['title']?.toString() ?? '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => FlutterOverlayWindow.shareData('open_player'),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(_cur, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.bold)),
              if (_next.isNotEmpty)
                Text(_next, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  if (FlutterOverlayWindow.isActive()) {
    runApp(const _OverlayApp());
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KuGouApp());
}

class KuGouApp extends StatelessWidget {
  const KuGouApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: PlayerService.I),
        ChangeNotifierProvider.value(value: ModeManager.I),
        ChangeNotifierProvider.value(value: PlaylistService.I),
      ],
      child: MaterialApp(
        title: 'KuGou',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const SplashPage(),
      ),
    );
  }
}
