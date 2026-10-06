import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../bridge.dart';
import '../mode_manager.dart';
import '../player.dart';
import '../updater.dart';
import '../backend_generator.dart';
import 'theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _cookie;
  late final TextEditingController _backend;
  bool _saving = false;
  bool _checking = false;
  bool _generating = false;
  List<String> _backendUrls = [];

  @override
  void initState() {
    super.initState();
    _cookie = TextEditingController(text: ModeManager.I.cookie);
    _backend = TextEditingController();
    _loadBackend();
    _refreshBackendUrls();
  }

  @override
  void dispose() {
    _cookie.dispose();
    _backend.dispose();
    super.dispose();
  }

  Future<void> _loadBackend() async {
    final c = await Bridge.I.getCustomBackend();
    if (mounted && c != null) _backend.text = c;
  }

  Future<void> _refreshBackendUrls() async {
    final urls = await Bridge.I.discoveredUrls();
    if (!mounted) return;
    setState(() => _backendUrls = urls);
  }

  Future<void> _saveCookie() async {
    setState(() => _saving = true);
    await ModeManager.I.setCookie(_cookie.text);
    if (!mounted) return;
    setState(() => _saving = false);
    _toast('Cookie 已保存');
  }

  Future<void> _clearCookie() async {
    await ModeManager.I.clearCookie();
    if (!mounted) return;
    setState(() => _cookie.text = '');
    _toast('已清除，回到游客模式');
  }

  Future<void> _checkEngine() async {
    setState(() => _checking = true);
    final ok = await Bridge.I.refresh();
    await _refreshBackendUrls();
    if (!mounted) return;
    setState(() => _checking = false);
    _toast(ok ? '引擎已更新到 v${Bridge.I.version}' : '更新失败');
  }

  Future<void> _clearCache() async {
    await Bridge.I.clearCache();
    if (!mounted) return;
    _toast('缓存已清除');
    await _checkEngine();
  }

  Future<void> _saveBackend() async {
    await Bridge.I.setCustomBackend(_backend.text);
    await _refreshBackendUrls();
    if (!mounted) return;
    _toast(_backendUrls.isEmpty ? '无法连接该后端' : '后端已连接');
  }

  Future<void> _generateBackend() async {
    setState(() => _generating = true);
    final (ok, msg) = await BackendGenerator.generate();
    if (!mounted) return;
    setState(() => _generating = false);
    if (ok) {
      _showBackendDialog(msg);
    } else {
      _toast(msg);
    }
  }

  void _showBackendDialog(String dir) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        Icon(Icons.check_circle, color: Colors.greenAccent),
        SizedBox(width: 10),
        Text('后端脚本已生成'),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('文件已保存到：', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black26,
              borderRadius: BorderRadius.circular(8)),
          child: SelectableText(dir, style: const TextStyle(
              fontFamily: 'monospace', fontSize: 11.5,
              color: Colors.greenAccent))),
        const SizedBox(height: 16),
        const Text('接下来的步骤：', style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        const Text(
          '1. 打开 Termux\n'
          '2. 执行：\n'
          '   bash /storage/emulated/0/Download/install-kugou-server.sh\n'
          '3. 回到 App 点「刷新后端连接」',
          style: TextStyle(fontSize: 12, height: 1.7,
              color: Colors.white70)),
      ]),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(const ClipboardData(
                text: 'bash /storage/emulated/0/Download/install-kugou-server.sh'));
            Navigator.pop(context);
            _toast('命令已复制');
          },
          child: const Text('复制命令')),
        FilledButton(onPressed: () => Navigator.pop(context),
            child: const Text('知道了')),
      ]));
  }

  void _showAbout() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('关于 KuGou'),
      content: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('版本：v10.0.0', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        Text('引擎版本：v${Bridge.I.version}',
            style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        const Text('模式：概念版 / 普通版',
            style: TextStyle(fontSize: 13)),
        const SizedBox(height: 16),
        const Text('⚠️ 仅供个人学习研究，请尊重版权',
            style: TextStyle(color: Colors.orange, fontSize: 12)),
      ]),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context),
            child: const Text('关闭')),
      ]));
  }

  void _toast(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(s),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final mgr = context.watch<ModeManager>();
    final player = context.watch<PlayerService>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ============ 账号 ============
          _sectionTitle('账号'),
          _card([
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: (mgr.isLite ? AppTheme.primary : AppTheme.secondary)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
                child: Icon(
                  mgr.isLite ? Icons.diamond_outlined
                      : Icons.music_note_outlined,
                  color: mgr.isLite ? AppTheme.primary : AppTheme.secondary,
                  size: 22)),
              title: Text(mgr.isLite ? '概念版' : '普通版',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(mgr.isGuest ? '游客模式' : '已登录',
                  style: const TextStyle(fontSize: 12)),
              value: mgr.isLite,
              onChanged: (v) async {
                await mgr.switchMode(v ? KuGouMode.lite : KuGouMode.standard);
                setState(() => _cookie.text = mgr.cookie);
              }),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                Icon(mgr.isGuest ? Icons.person_outline
                    : Icons.verified_user, size: 16,
                    color: mgr.isGuest ? Colors.orangeAccent
                        : Colors.greenAccent),
                const SizedBox(width: 6),
                Text(
                  mgr.isGuest ? '游客模式 · 免费歌曲可听'
                      : '已登录 · 解锁 VIP',
                  style: TextStyle(fontSize: 12,
                      color: mgr.isGuest ? Colors.orangeAccent
                          : Colors.greenAccent)),
              ])),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _cookie,
                maxLines: 4,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: '粘贴 Cookie（kg_mid=…; token=…）'))),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: FilledButton.icon(
                  onPressed: _saving ? null : _saveCookie,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('保存'))),
                const SizedBox(width: 10),
                if (!mgr.isGuest)
                  OutlinedButton.icon(
                    onPressed: _clearCookie,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('清除')),
              ])),
          ]),

          // ============ 引擎 ============
          const SizedBox(height: 22),
          _sectionTitle('引擎'),
          _card([
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
                child: _checking
                    ? const Padding(padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_sync,
                        color: AppTheme.primary, size: 22)),
              title: const Text('检查更新',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('当前 v${Bridge.I.version}',
                  style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _checking ? null : _checkEngine),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.cleaning_services_outlined,
                    color: Colors.orangeAccent, size: 22)),
              title: const Text('清除引擎缓存',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('重置为云端最新版本',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _clearCache),
          ]),

          // ============ 后端 ============
          const SizedBox(height: 22),
          _sectionTitle('后端服务'),
          _card([
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
                child: _generating
                    ? const Padding(padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_for_offline_outlined,
                        color: AppTheme.secondary, size: 22)),
              title: const Text('生成后端脚本',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('保存到下载目录，Termux 一键安装',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _generating ? null : _generateBackend),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('自定义后端地址',
                      style: TextStyle(fontSize: 12,
                          color: Colors.white.withOpacity(0.6))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _backend,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'http://192.168.1.100:3000')),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: FilledButton.icon(
                      onPressed: _saveBackend,
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('连接'))),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _refreshBackendUrls,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('刷新')),
                  ]),
                ])),
            if (_backendUrls.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.check_circle, size: 14,
                          color: Colors.greenAccent),
                      const SizedBox(width: 6),
                      Text('已连接后端',
                          style: TextStyle(fontSize: 12,
                              color: Colors.white.withOpacity(0.6))),
                    ]),
                    const SizedBox(height: 8),
                    ..._backendUrls.map((u) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        const Icon(Icons.circle, size: 6,
                            color: Colors.greenAccent),
                        const SizedBox(width: 8),
                        Expanded(child: Text(u,
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: Colors.greenAccent))),
                      ]),
                    )),
                  ])),
            ],
          ]),

          // ============ 播放 ============
          const SizedBox(height: 22),
          _sectionTitle('播放'),
          _card([
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
                child: Icon(_modeIcon(player.mode),
                    color: AppTheme.primary, size: 22)),
              title: const Text('播放模式',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_modeText(player.mode),
                  style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPlayModeDialog(context, player)),
          ]),

          // ============ 关于 ============
          const SizedBox(height: 22),
          _sectionTitle('关于'),
          _card([
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.info_outline,
                    color: AppTheme.primary, size: 22)),
              title: const Text('关于 KuGou',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('v10.0.0',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showAbout),
          ]),

          const SizedBox(height: 32),
          Center(child: Text(
            '⚠️ 仅供个人学习研究 · 请尊重版权',
            style: TextStyle(color: Colors.white.withOpacity(0.3),
                fontSize: 11))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  IconData _modeIcon(PlayMode m) {
    switch (m) {
      case PlayMode.order: return Icons.repeat;
      case PlayMode.shuffle: return Icons.shuffle;
      case PlayMode.single: return Icons.repeat_one;
    }
  }

  String _modeText(PlayMode m) {
    switch (m) {
      case PlayMode.order: return '顺序播放';
      case PlayMode.shuffle: return '随机播放';
      case PlayMode.single: return '单曲循环';
    }
  }

  void _showPlayModeDialog(BuildContext context, PlayerService player) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('播放模式'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final m in PlayMode.values)
          RadioListTile<PlayMode>(
            value: m,
            groupValue: player.mode,
            title: Text(_modeText(m)),
            onChanged: (v) {
              if (v != null) player.setMode(v);
              Navigator.pop(context);
            }),
      ])));
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
    child: Text(t, style: TextStyle(
      fontSize: 12, fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      color: Colors.white.withOpacity(0.5))));

  Widget _card(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.05))),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(children: children)));
}
