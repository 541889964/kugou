import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'mode_manager.dart';
import 'player.dart';
import 'playlist.dart';
import 'downloader.dart';
import 'updater.dart';
import 'ui/theme.dart';
import 'ui/splash.dart';

void main() {
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
        ChangeNotifierProvider.value(value: Downloader.I),
        ChangeNotifierProvider.value(value: Updater.I),
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
