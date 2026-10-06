import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bridge.dart';
import '../mode_manager.dart';
import '../updater.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _S();
}

class _S extends State<SettingsPage> {
  late final TextEditingController _c;
  bool _saving = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: ModeManager.I.cookie);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ModeManager.I.setCookie(_c.text);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cookie 已保存')));
  }

  Future<void> _clear() async {
    await ModeManager.I.clearCookie();
    if (!mounted) return;
    setState(() => _c.text = '');
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清除，进入游客模式')));
  }

  Future<void> _checkEngine() async {
    setState(() => _checking = true);
    await Updater.I.check();
    final ok = await Bridge.I.refresh();
    if (!mounted) return;
    setState(() => _checking = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '引擎已更新到 v${Bridge.I.version}' : '更新失败')));
  }

  @override
  Widget build(BuildContext context) {
    final mgr = context.watch<ModeManager>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ListTile(
          leading: Icon(mgr.isLite ? Icons.diamond_outlined : Icons.music_note_outlined),
          title: Text(mgr.isLite ? '概念版' : '普通版'),
          subtitle: Text(mgr.isGuest ? '游客模式（无 Cookie）' : '已登录'),
          trailing: Switch(value: mgr.isLite, onChanged: (v) async {
            await mgr.switchMode(v ? KuGouMode.lite : KuGouMode.standard);
            setState(() => _c.text = mgr.cookie);
          }),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: mgr.isGuest ? Colors.orange.withValues(alpha: 0.15)
                : Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(mgr.isGuest ? Icons.person_outline : Icons.verified_user,
                color: mgr.isGuest ? Colors.orange : Colors.green),
            const SizedBox(width: 10),
            Expanded(child: Text(
              mgr.isGuest ? '游客模式 —— 免费歌曲可听'
                  : '已登录 —— 当前模式 Cookie 已生效',
              style: const TextStyle(fontSize: 12.5))),
          ]),
        ),
        const SizedBox(height: 20),
        Text('${mgr.isLite ? "概念版" : "普通版"} Cookie',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _c,
          maxLines: 5,
          style: const TextStyle(fontSize: 12.5),
          decoration: const InputDecoration(
            hintText: '粘贴 Cookie（kg_mid=...; kg_dfid=...; token=...）'),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save), label: const Text('保存'))),
          const SizedBox(width: 12),
          if (!mgr.isGuest)
            OutlinedButton.icon(onPressed: _clear,
              icon: const Icon(Icons.delete_outline), label: const Text('清除')),
        ]),
        const SizedBox(height: 32),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.cloud_sync),
          title: const Text('更新引擎'),
          subtitle: Text('当前引擎 v${Bridge.I.version}'),
          trailing: _checking
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
          onTap: _checking ? null : _checkEngine,
        ),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('版本'),
          subtitle: Text('v10.0.0'),
        ),
        const SizedBox(height: 24),
        const Center(child: Text('⚠️ 仅供个人学习研究，请尊重版权',
            style: TextStyle(color: Colors.orange, fontSize: 12))),
      ]),
    );
  }
}
