import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../har_parser.dart';
import '../kugou.dart';
import '../mode_manager.dart';
import '../script_generator.dart';
import '../signature_manager.dart';
import '../updater.dart';
import 'theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _verifying = false;
  bool _importing = false;
  bool _generating = false;
  bool _hasScript = false;
  String _verifyMsg = '';

  @override
  void initState() {
    super.initState();
    _checkScript();
  }

  Future<void> _checkScript() async {
    final e = await ScriptGenerator.exists();
    if (mounted) setState(() => _hasScript = e);
  }

  Future<void> _pickFile() async {
    setState(() => _importing = true);
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        dialogTitle: '选择 Reqable 导出的 .har 文件',
      );
      if (r == null || r.files.isEmpty || r.files.single.path == null) {
        setState(() => _importing = false);
        return;
      }
      await _parseAndSave(r.files.single.path!);
    } catch (e) {
      setState(() => _importing = false);
      _toast('选择失败: $e');
    }
  }

  Future<void> _manualPath() async {
    final c = TextEditingController();
    final p = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('输入文件完整路径'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('例如:',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
            const SizedBox(height: 4),
            SelectableText('/storage/emulated/0/Download/xxx.har',
                style: TextStyle(fontSize: 11, fontFamily: 'monospace',
                    color: Colors.white.withOpacity(0.5))),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              maxLines: 2,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                  hintText: '/storage/emulated/0/Download/…'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: const Text('确定')),
        ],
      ),
    );
    if (p == null || p.isEmpty) return;
    setState(() => _importing = true);
    await _parseAndSave(p);
  }

  Future<void> _parseAndSave(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) {
        setState(() => _importing = false);
        _toast('文件不存在');
        return;
      }
      final content = await f.readAsString();
      if (content.isEmpty) {
        setState(() => _importing = false);
        _toast('文件为空');
        return;
      }
      final m = HarParser.parse(content);
      if (m.isEmpty) {
        setState(() => _importing = false);
        _showResult(path, m, '未从 HAR 里找到 Cookie 字段');
        return;
      }
      if (!HarParser.isValid(m)) {
        setState(() => _importing = false);
        _showResult(path, m, '找到字段但不完整（token≥20 且 userid 非空）');
        return;
      }
      await SignatureManager.I.updateUser(m);
      setState(() => _importing = false);
      _showResult(path, m, '✓ 导入成功');
    } catch (e) {
      setState(() => _importing = false);
      _toast('解析失败: $e');
    }
  }

  void _showResult(String path, Map<String, String> m, String status) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(
            status.startsWith('✓')
                ? Icons.check_circle
                : (m.isEmpty ? Icons.error : Icons.warning_amber),
            color: status.startsWith('✓')
                ? Colors.greenAccent
                : (m.isEmpty ? Colors.redAccent : Colors.orangeAccent),
          ),
          const SizedBox(width: 10),
          Flexible(child: Text(status, style: const TextStyle(fontSize: 15))),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('文件:', style: TextStyle(fontSize: 12)),
              SelectableText(path,
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace',
                      color: Colors.white.withOpacity(0.6))),
              const SizedBox(height: 12),
              const Text('提取结果:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  HarParser.describe(m),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.greenAccent,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了')),
        ],
      ),
    );
  }

  Future<void> _verify() async {
    setState(() { _verifying = true; _verifyMsg = ''; });
    final ok = await KuGouApi.I.verifyCookie();
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _verifyMsg = ok ? '✓ 账号有效' : '✗ 账号无效或未导入';
    });
  }

  Future<void> _generateScript() async {
    setState(() => _generating = true);
    final (ok, msg) = await ScriptGenerator.generate();
    if (!mounted) return;
    setState(() => _generating = false);
    if (ok) {
      setState(() => _hasScript = true);
      _showScriptDialog();
    } else {
      _toast(msg);
    }
  }

  void _showScriptDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.greenAccent),
          SizedBox(width: 10),
          Text('脚本已生成'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('打开 Termux 执行:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                ScriptGenerator.command,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.amber,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('执行完回本页点「重载配置」',
                style: TextStyle(fontSize: 12,
                    color: Colors.white.withOpacity(0.6))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: ScriptGenerator.command));
              Navigator.pop(context);
              _toast('命令已复制');
            },
            child: const Text('复制命令'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了')),
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
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mgr = context.watch<ModeManager>();
    final up = context.watch<Updater>();
    final u = SignatureManager.I.config?['user'] as Map?;
    final hasToken = ((u?['token'] ?? '') as String).isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _s('账号'),
          _c([
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: (hasToken ? Colors.green : Colors.orange).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(hasToken ? Icons.person : Icons.person_outline,
                    color: hasToken ? Colors.green : Colors.orange, size: 22),
              ),
              title: Text(
                hasToken ? 'userid: ${u?['userid'] ?? "?"}' : '未导入账号',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              subtitle: Text(
                hasToken
                    ? 'token: ${(u?['token'] as String).substring(0, 12)}…'
                    : '点下面「导入 HAR 文件」',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              trailing: _verifying
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      icon: const Icon(Icons.verified_user),
                      onPressed: _verify),
            ),
            if (_verifyMsg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(_verifyMsg,
                    style: TextStyle(
                        fontSize: 12,
                        color: _verifyMsg.startsWith('✓')
                            ? Colors.greenAccent
                            : Colors.redAccent)),
              ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _importing
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.file_upload_outlined,
                        color: AppTheme.primary, size: 22),
              ),
              title: const Text('导入 HAR 文件',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('从 Reqable 导出的 .har 提取 Cookie',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _importing ? null : _pickFile,
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.keyboard,
                    color: Colors.blueGrey, size: 22),
              ),
              title: const Text('手动输入路径',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('备用方案：选择器打不开时用',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _importing ? null : _manualPath,
            ),
          ]),

          const SizedBox(height: 22),
          _s('版本'),
          _c([
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: (mgr.isLite ? AppTheme.primary : AppTheme.secondary)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                    mgr.isLite ? Icons.diamond_outlined : Icons.music_note_outlined,
                    color: mgr.isLite ? AppTheme.primary : AppTheme.secondary,
                    size: 22),
              ),
              title: Text(mgr.isLite ? '概念版' : '普通版',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              value: mgr.isLite,
              onChanged: (v) async {
                await mgr.switchMode(v ? KuGouMode.lite : KuGouMode.standard);
              }),
          ]),

          const SizedBox(height: 22),
          _s('签名配置'),
          _c([
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.description_outlined,
                    color: AppTheme.primary, size: 22),
              ),
              title: Text('当前 v${SignatureManager.I.version}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('来源: ${_srcLabel(SignatureManager.I.source)}',
                  style: const TextStyle(fontSize: 12)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: up.checking
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_download_outlined,
                        color: Colors.green, size: 22),
              ),
              title: const Text('检查云端更新',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(up.status.isEmpty ? '点击检查' : up.status,
                  style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: up.checking ? null : () => Updater.I.check(),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _generating
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.terminal, color: Colors.amber, size: 22),
              ),
              title: const Text('生成更新脚本',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                _hasScript ? '已生成 · 点此重新生成' : '生成到下载目录',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _generating ? null : _generateScript,
            ),
            if (_hasScript) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Termux 执行命令:',
                        style: TextStyle(fontSize: 12,
                            color: Colors.white.withOpacity(0.6))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              ScriptGenerator.command,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(
                                  text: ScriptGenerator.command));
                              _toast('已复制');
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('在 Termux 里粘贴执行，完成后点下方「重载配置」',
                        style: TextStyle(fontSize: 11,
                            color: Colors.white.withOpacity(0.5))),
                  ],
                ),
              ),
            ],
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.refresh,
                    color: Colors.orange, size: 22),
              ),
              title: const Text('重载配置',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Termux 更新后点这里',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final ok = await Updater.I.reload();
                _toast(ok
                    ? '✓ v${SignatureManager.I.version}'
                    : '未找到新配置');
              },
            ),
          ]),

          const SizedBox(height: 22),
          _s('关于'),
          _c([
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('KuGou App'),
              subtitle: Text('v15.0.0 · HAR 导入版'),
            ),
          ]),

          const SizedBox(height: 32),
          Center(
            child: Text('⚠️ 仅供个人学习研究',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 11)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _srcLabel(String s) {
    switch (s) {
      case 'private': return '私有目录';
      case 'imported': return '已从下载导入';
      default: return '内置';
    }
  }

  Widget _s(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
        child: Text(t,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Colors.white.withOpacity(0.5))),
      );

  Widget _c(List<Widget> ch) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(children: ch),
        ),
      );
}
