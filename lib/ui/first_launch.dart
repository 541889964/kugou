import 'package:flutter/material.dart';
import '../bridge.dart';
import '../mode_manager.dart';
import 'theme.dart';
import 'home.dart';

class FirstLaunchPage extends StatefulWidget {
  const FirstLaunchPage({super.key});
  @override
  State<FirstLaunchPage> createState() => _F();
}

class _F extends State<FirstLaunchPage> {
  List _modes = [];
  String? _sel;
  final _cookie = TextEditingController();
  bool _saving = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _cookie.dispose(); super.dispose(); }

  void _load() {
    final r = Bridge.I.call('list_modes', '', {});
    if (r is List) {
      setState(() {
        _modes = r;
        _sel = r.isNotEmpty ? (r[0] as Map)['id']?.toString() : 'standard';
      });
    }
  }

  Future<void> _enter() async {
    if (_sel == null) return;
    setState(() => _saving = true);
    await ModeManager.I.switchMode(_sel == 'lite' ? KuGouMode.lite : KuGouMode.standard);
    if (_cookie.text.trim().isNotEmpty) {
      await ModeManager.I.setCookie(_cookie.text.trim());
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.grad),
        child: SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 20),
            const Icon(Icons.download_for_offline, color: Colors.white, size: 64),
            const SizedBox(height: 20),
            const Text('欢迎使用 KuGou', style: TextStyle(color: Colors.white,
              fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('先选一个版本，再填 Cookie（可跳过）',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 30),
            ..._modes.map((m) {
              final mm = m as Map;
              final s = mm['id']?.toString() == _sel;
              return GestureDetector(
                onTap: () => setState(() => _sel = mm['id']?.toString()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: s ? Colors.white : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: s ? Colors.white : Colors.white30, width: 2),
                  ),
                  child: Row(children: [
                    Icon(mm['id'] == 'lite' ? Icons.diamond_outlined : Icons.music_note_outlined,
                      color: s ? const Color(0xFF7C4DFF) : Colors.white, size: 32),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(mm['name']?.toString() ?? '', style: TextStyle(fontSize: 17,
                        fontWeight: FontWeight.bold, color: s ? Colors.black87 : Colors.white)),
                      const SizedBox(height: 4),
                      Text(mm['desc']?.toString() ?? '', style: TextStyle(fontSize: 12.5,
                        color: s ? Colors.black54 : Colors.white70)),
                    ])),
                    if (s) const Icon(Icons.check_circle, color: Color(0xFF7C4DFF)),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 16),
            const Text('Cookie（可选）', style: TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _cookie,
              maxLines: 4,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: '粘贴小号 Cookie 解锁 VIP（不填也能听歌）',
                fillColor: Colors.white.withValues(alpha: 0.92),
                hintStyle: const TextStyle(color: Colors.black38),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: _saving ? null : _enter,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF7C4DFF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('进入 App', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            )),
          ]),
        )),
      ),
    );
  }
}
