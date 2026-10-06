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
  static const sources = [
    'https://raw.githubusercontent.com/541889964/kugou/main/cloud/cloud.js',
  ];
  JavascriptRuntime? _rt;
  bool ready = false;
  int version = 0;
  final Map<String, Map<String, dynamic>> _mem = {};

  Future<void> initFromCache() async {
    final sp = await SharedPreferences.getInstance();
    final cached = sp.getString('cloud_js');
    if (cached != null && _eval(cached)) {
      version = sp.getInt('engine_ver') ?? 0;
      return;
    }
    await refresh();
  }

  Future<bool> refresh() async {
    for (final url in sources) {
      try {
        final r = await Dio().get(url, options: Options(responseType: ResponseType.plain));
        final js = r.data.toString();
        if (!js.contains('function handle')) continue;
        if (_eval(js)) {
          final sp = await SharedPreferences.getInstance();
          await sp.setString('cloud_js', js);
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<bool> reload() async {
    final sp = await SharedPreferences.getInstance();
    final js = sp.getString('cloud_js');
    if (js == null || js.isEmpty) return false;
    return _eval(js);
  }

  bool _eval(String js) {
    try {
      final rt = getJavascriptRuntime();
      _rt = rt;
      rt.onMessage('md5', (a) => md5.convert(utf8.encode(_a(a))).toString());
      rt.onMessage('sha1', (a) => sha1.convert(utf8.encode(_a(a))).toString());
      rt.onMessage('b64decode', (a) { try { return utf8.decode(base64.decode(_a(a))); } catch (_) { return ''; } });
      rt.onMessage('now', (_) => DateTime.now().millisecondsSinceEpoch.toString());
      rt.onMessage('device', (_) => jsonEncode({'mid': Device.mid, 'dfid': Device.dfid, 'uuid': Device.uuid}));
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
        try { final m = jsonDecode(_a(a)); print('[JS][${m['l']}] ${m['m']}'); } catch (_) {}
        return 'ok';
      });
      rt.evaluate(js);
      final chk = rt.evaluate('typeof ENGINE_VERSION!=="undefined"?ENGINE_VERSION:0');
      final v = int.tryParse(chk.stringResult) ?? 0;
      if (v <= 0) return false;
      version = v; ready = true; return true;
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
