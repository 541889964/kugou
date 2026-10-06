import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class SignatureManager {
  static final SignatureManager I = SignatureManager._();
  SignatureManager._();
  Map<String, dynamic>? _config;
  String _source = 'assets';
  Map<String, dynamic>? get config => _config;
  String get source => _source;
  int get version => (_config?['version'] as num?)?.toInt() ?? 0;
  static const String importPath = '/storage/emulated/0/Download/kugou-signature.json';

  Future<File> _pf() async {
    final d = await getApplicationSupportDirectory();
    return File('${d.path}/signature.json');
  }

  Future<void> init() async {
    try {
      final f = await _pf();
      if (await f.exists()) {
        final m = jsonDecode(await f.readAsString());
        if (m is Map<String, dynamic> && m['version'] != null) {
          _config = m;
          _source = 'private';
          await tryImport();
          return;
        }
      }
    } catch (_) {}
    if (await tryImport()) return;
    try {
      final raw = await rootBundle.loadString('assets/signature.json');
      _config = jsonDecode(raw) as Map<String, dynamic>;
      _source = 'assets';
      await _save();
    } catch (_) {}
  }

  Future<bool> tryImport() async {
    try {
      final f = File(importPath);
      if (!await f.exists()) return false;
      final m = jsonDecode(await f.readAsString());
      if (m is! Map<String, dynamic>) return false;
      final nv = (m['version'] as num?)?.toInt() ?? 0;
      if (nv <= version) return false;
      _config = m;
      _source = 'imported';
      await _save();
      return true;
    } catch (_) { return false; }
  }

  Future<void> _save() async {
    try { await (await _pf()).writeAsString(jsonEncode(_config)); } catch (_) {}
  }

  Future<void> updateUser(Map<String, String> u) async {
    if (_config == null) return;
    final cur = Map<String, dynamic>.from((_config!['user'] as Map?) ?? {});
    u.forEach((k, v) { if (v.isNotEmpty) cur[k] = v; });
    if ((cur['kg_fake'] ?? '').toString().isEmpty) {
      cur['kg_fake'] = cur['userid'] ?? '';
    }
    _config!['user'] = cur;
    await _save();
  }

  Future<bool> reload() async {
    if (await tryImport()) return true;
    try {
      final f = await _pf();
      if (await f.exists()) {
        _config = jsonDecode(await f.readAsString());
        _source = 'private';
        return true;
      }
    } catch (_) {}
    return false;
  }
}
