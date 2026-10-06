import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../client.dart';
import '../mode_manager.dart';
import '../backend_generator.dart';
import 'theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _cookie;
  bool _saving = false;
  bool _testing = false;
  bool _generating = false;
  bool _backendOnline = false;

  @override
  void initState() {
    super.initState();
    _cookie = TextEditingController(text: ModeManager.I.cookie);
    _checkBackend();
  }

  @override
  void dispose() {
    _cookie.dispose();
    super.dispose();
  }

  Future<void> _checkBackend() async {
    final ok = await KuGouClient.I.checkBackend();
    if (!mounted) return;
    setState(() => _backendOnline = ok);
  }

  Future<void> _saveCookie() async {
    final text = _cookie.text.trim();
    if (text.isEmpty) {
      _toast('Cookie 不能为空');
      return;
    }
    if (!text.contains('userid=') || !text.contains('token=')) {
      _toast('Cookie 格式错误：需要 userid 和 token');
      return;
    }
    final tm = RegExp(r'token=([^;\s]+)').firstMatch(text);
    if (tm == null || tm!.group(1)!.length < 20) {
      _toast('token 长度不够');
      return;
    }

    setState(() => _saving = true);
    await ModeManager.I.setCookie(text);
    _toast('正在验证…');

    final ok = await KuGouClient.I.verifyCookie();
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      _toast('✓ Cookie 有效，已登录');
    } else {
      await ModeManager.I.clearCookie();
      if (!mounted) return;
      setState(() => _cookie.text = '');
      _showInvalid();
    }
  }

  Future<void> _clearCookie() async {
    await ModeManager.I.clearCookie();
    if (!mounted) return;
    setState(() => _cookie.text = '');
    _toast('已清除，回到游客');
  }

  Future<void> _testBackend() async {
    setState(() => _testing = true);
    final ok = await KuGouClient.I.checkBackend();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _backendOnline = ok;
    });
    _toast(ok ? '✓ 后端在线 (${ModeManager.I.baseUrl})' : '✗ 后端不可达');
  }

  Future<void> _generateBackend() async {
    setState(() => _generating = true);
    final (ok, msg) = await BackendGenerator.generate();
    if (!mounted) return;
    setState(() => _generating = false);
    if (ok) {
      _showGenerated(msg);
    } else {
      _toast(msg);
    }
  }

  void _showGenerated(String path) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.greenAccent),
          SizedBox(width: 10),
          Text('后端脚本已生成'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('脚本已保存到:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(path,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      color: Colors.greenAccent)),
            ),
            const SizedBox(height: 16),
            const Text('接下来:',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            const Text(
              '1. 打开 Termux\n'
              '2. 粘贴并执行以下命令\n'
              '3. 首次运行约 3-5 分钟\n'
              '4. 服务会同时启动普通版+概念版',
              style:
                  TextStyle(fontSize: 12, height: 1.7, color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SelectableText(
                'bash /storage/emulated/0/Download/kugou-backend.sh',
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: Colors.amber),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(const ClipboardData(
                  text:
                      'bash /storage/emulated/0/Download/kugou-backend.sh'));
              Navigator.pop(context);
              _toast('命令已复制');
            },
            child: const Text('复制命令'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showInvalid() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.orangeAccent),
          SizedBox(width: 10),
          Text('Cookie 无效'),
        ]),
        content: const Text(
          '该 Cookie 已失效或格式错误。\n\n'
          '已自动回到游客模式。\n\n'
          '如需 VIP，请重新登录酷狗复制新 Cookie。',
          style: TextStyle(fontSize: 13, height: 1.7),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('关于 KuGou'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本: v11.0.0', style: TextStyle(fontSize: 13)),
            SizedBox(height: 8),
            Text('后端: KuGouMusicApi (Node.js)',
                style: TextStyle(fontSize: 13)),
            SizedBox(height: 8),
            Text('支持: 概念版 + 普通版',
                style: TextStyle(fontSize: 13)),
            SizedBox(height: 16),
            Text('⚠️ 仅供个人学习研究，请尊重版权',
                style: TextStyle(color: Colors.orange, fontSize: 12)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _toast(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(s),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mgr = context.watch<ModeManager>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 模式
          _section('版本'),
          _card([
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (mgr.isLite ? AppTheme.primary : AppTheme.secondary)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  mgr.isLite
                      ? Icons.diamond_outlined
                      : Icons.music_note_outlined,
                  color: mgr.isLite ? AppTheme.primary : AppTheme.secondary,
                  size: 22,
                ),
              ),
              title: Text(mgr.isLite ? '概念版' : '普通版',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                mgr.isLite ? 'http://127.0.0.1:3001' : 'http://127.0.0.1:3000',
                style: const TextStyle(fontSize: 12),
              ),
              value: mgr.isLite,
              onChanged: (v) async {
                await mgr.switchMode(v ? KuGouMode.lite : KuGouMode.standard);
                setState(() => _cookie.text = mgr.cookie);
                _checkBackend();
              },
            ),
          ]),

          // Cookie
          const SizedBox(height: 22),
          _section('账号'),
          _card([
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                Icon(
                  mgr.isGuest ? Icons.person_outline : Icons.verified_user,
                  size: 16,
                  color: mgr.isGuest
                      ? Colors.orangeAccent
                      : Colors.greenAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  mgr.isGuest ? '游客模式 · 免费歌曲可听' : '已登录 · 解锁 VIP',
                  style: TextStyle(
                    fontSize: 12,
                    color: mgr.isGuest
                        ? Colors.orangeAccent
                        : Colors.greenAccent,
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _cookie,
                maxLines: 4,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: '粘贴 Cookie（必须含 userid= 和 token=）',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveCookie,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('保存并验证'),
                  ),
                ),
                const SizedBox(width: 10),
                if (!mgr.isGuest)
                  OutlinedButton.icon(
                    onPressed: _clearCookie,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('清除'),
                  ),
              ]),
            ),
          ]),

          // 后端
          const SizedBox(height: 22),
          _section('后端服务'),
          _card([
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (_backendOnline ? Colors.green : Colors.orange)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _backendOnline ? Icons.cloud_done : Icons.cloud_off,
                  color: _backendOnline ? Colors.green : Colors.orange,
                  size: 22,
                ),
              ),
              title: Text(
                _backendOnline ? '后端在线' : '后端不可达',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                ModeManager.I.baseUrl,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: _testing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _testBackend,
                    ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _generating
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_for_offline_outlined,
                        color: AppTheme.secondary, size: 22),
              ),
              title: const Text('生成后端脚本',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('保存到下载目录，Termux 一键部署',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _generating ? null : _generateBackend,
            ),
          ]),

          // 关于
          const SizedBox(height: 22),
          _section('关于'),
          _card([
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.info_outline,
                    color: AppTheme.primary, size: 22),
              ),
              title: const Text('关于 KuGou',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('v11.0.0',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showAbout,
            ),
          ]),

          const SizedBox(height: 32),
          Center(
            child: Text(
              '⚠️ 仅供个人学习研究 · 请尊重版权',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontSize: 11),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
        child: Text(
          t,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(children: children),
        ),
      );
}
