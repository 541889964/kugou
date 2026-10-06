import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mode_manager.dart';

class Device {
  static String mid = '', dfid = '', uuid = '';
  static Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    mid = sp.getString('mid') ?? _r(32);
    dfid = sp.getString('dfid') ?? _r(32);
    uuid = sp.getString('uuid') ?? _u();
    await sp.setString('mid', mid);
    await sp.setString('dfid', dfid);
    await sp.setString('uuid', uuid);
  }
  static String _r(int n) {
    const c = '0123456789abcdef';
    final s = DateTime.now().microsecondsSinceEpoch;
    return List.generate(n, (i) => c[(s >> i) & 15]).join();
  }
  static String _u() => '${_r(8)}-${_r(4)}-${_r(4)}-${_r(4)}-${_r(12)}';
}

class Bridge {
  static final Bridge I = Bridge._();
  Bridge._();

  JavascriptRuntime? _rt;
  bool ready = false;
  bool backendOnline = false;
  int version = 0;
  final Map<String, Map<String, dynamic>> _mem = {};

  static List<String> _backendUrls = [];

  /// 获取后端地址（可从设置自定义）
  Future<List<String>> _candidates() async {
    final sp = await SharedPreferences.getInstance();
    final custom = sp.getString('custom_backend');
    return <String>{
      if (custom != null && custom.isNotEmpty) custom,
      'http://127.0.0.1:3000',
      ...(sp.getStringList('backend_urls') ?? []),
    }.toList();
  }

  Future<void> _discover() async {
    for (final base in await _candidates()) {
      try {
        final r = await Dio().get('$base/discover',
            options: Options(
              responseType: ResponseType.json,
              sendTimeout: const Duration(seconds: 2),
              receiveTimeout: const Duration(seconds: 2)));
        if (r.data is Map && r.data['urls'] is List) {
          final urls = (r.data['urls'] as List)
              .map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
          if (urls.isNotEmpty) {
            _backendUrls = urls;
            backendOnline = true;
            final sp = await SharedPreferences.getInstance();
            await sp.setStringList('backend_urls', urls);
            print('[Bridge] 后端在线: $urls');
            return;
          }
        }
      } catch (_) { continue; }
    }
    backendOnline = false;
  }

  /// 启动流程：先找后端，找不到不用缓存
  Future<void> initFromCache() async {
    final sp = await SharedPreferences.getInstance();
    await _discover();

    // 后端在线 → 拉真引擎
    if (_backendUrls.isNotEmpty) {
      final ok = await _pullFromBackend();
      if (ok) {
        print('[Bridge] 从后端加载 v$version');
        return;
      }
    }

    // 后端不可用 → 用缓存兜底
    final cached = sp.getString('cloud_js');
    if (cached != null && cached.isNotEmpty && _eval(cached)) {
      version = sp.getInt('engine_ver') ?? 0;
      print('[Bridge] 后端不可达，使用缓存 v$version');
      return;
    }

    // 都没 → 未初始化状态
    ready = false;
    version = 0;
    print('[Bridge] 未初始化');
  }

  Future<bool> _pullFromBackend() async {
    for (final base in _backendUrls) {
      try {
        final r = await Dio().get('$base/engine',
            options: Options(
              responseType: ResponseType.plain,
              receiveTimeout: const Duration(seconds: 10)));
        final js = r.data.toString();
        if (js.contains('function handle') && _eval(js)) {
          final sp = await SharedPreferences.getInstance();
          await sp.setString('cloud_js', js);
          // 从后端 meta 拿真实版本
          try {
            final mr = await Dio().get('$base/meta',
                options: Options(
                  responseType: ResponseType.json,
                  receiveTimeout: const Duration(seconds: 5)));
            if (mr.data is Map) {
              version = int.tryParse(
                  '${mr.data['version'] ?? 0}') ?? version;
              await sp.setInt('engine_ver', version);
            }
          } catch (_) {}
          return true;
        }
      } catch (_) { continue; }
    }
    return false;
  }

  Future<bool> refresh() async {
    if (!backendOnline) await _discover();
    if (await _pullFromBackend()) return true;

    // 兜底：GitHub
    for (final url in const [
      'https://raw.githubusercontent.com/541889964/kugou/main/cloud/cloud.js',
    ]) {
      try {
        final r = await Dio().get(url, options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 15)));
        final js = r.data.toString();
        if (js.contains('function handle') && _eval(js)) {
          final sp = await SharedPreferences.getInstance();
          await sp.setString('cloud_js', js);
          return true;
        }
      } catch (_) { continue; }
    }
    return false;
  }

  Future<List<String>> discoveredUrls() async {
    if (_backendUrls.isEmpty) await _discover();
    return _backendUrls;
  }

  Future<void> setCustomBackend(String url) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('custom_backend', url.trim());
    _backendUrls = [];
    await _discover();
  }

  Future<String?> getCustomBackend() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('custom_backend');
  }

  Future<void> clearCache() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('cloud_js');
    await sp.remove('engine_ver');
    await sp.remove('backend_urls');
    _backendUrls = [];
    _mem.clear();
    ready = false;
    version = 0;
  }

  bool _eval(String js) {
    try {
      final rt = getJavascriptRuntime();
      _rt = rt;
      rt.onMessage('md5', (a) => md5.convert(utf8.encode(_a(a))).toString());
      rt.onMessage('sha1', (a) => sha1.convert(utf8.encode(_a(a))).toString());
      rt.onMessage('b64decode', (a) {
        try { return utf8.decode(base64.decode(_a(a))); } catch (_) { return ''; }
      });
      rt.onMessage('now', (_) =>
          DateTime.now().millisecondsSinceEpoch.toString());
      rt.onMessage('device', (_) => jsonEncode({
        'mid': Device.mid, 'dfid': Device.dfid, 'uuid': Device.uuid}));
      rt.onMessage('cookie', (_) => ModeManager.I.cookie);
      rt.onMessage('mode', (_) => ModeManager.I.modeId);
      rt.onMessage('cacheGet', (a) {
        final k = _a(a);
        final raw = _mem[k];
        if (raw == null) return '';
        if (raw['expire'] < DateTime.now().millisecondsSinceEpoch) {
          _mem.remove(k); return '';
        }
        return raw['v'].toString();
      });
      rt.onMessage('cacheSet', (a) {
        try {
          final m = jsonDecode(_a(a));
          _mem[m['k'].toString()] = {
            'v': m['v'].toString(),
            'expire': DateTime.now().millisecondsSinceEpoch +
                (int.tryParse('${m['ttl'] ?? 600}') ?? 600) * 1000,
          };
        } catch (_) {}
        return 'ok';
      });
      rt.onMessage('log', (a) {
        try {
          final m = jsonDecode(_a(a));
          print('[JS][${m['l']}] ${m['m']}');
        } catch (_) {}
        return 'ok';
      });
      rt.evaluate(js);
      final chk = rt.evaluate(
          'typeof ENGINE_VERSION!=="undefined"?ENGINE_VERSION:0');
      final v = int.tryParse(chk.stringResult) ?? 0;
      if (v <= 0) return false;
      version = v;
      ready = true;
      return true;
    } catch (_) { ready = false; return false; }
  }

  String _a(dynamic a) {
    if (a == null) return '';
    if (a is List && a.isNotEmpty) return a[0].toString();
    return a.toString();
  }

  dynamic call(String op, String stage, dynamic p) {
    if (!ready || _rt == null) return null;
    try {
      final j = jsonEncode(p ?? {});
      final r = _rt!.evaluate('JSON.stringify(handle("$op","$stage",$j))');
      if (r.isError) return null;
      final s = r.stringResult;
      if (s.isEmpty || s == 'undefined' || s == 'null') return null;
      return jsonDecode(s);
    } catch (_) { return null; }
  }
}
