import 'dart:convert';

/// HAR / Reqable / Charles 抓包解析器
class HarParser {
  static const List<String> keys = [
    'token', 'userid', 'dfid', 'mid', 'uuid',
    'appid', 'clientver', 'kg-fake', 'kg_fake',
  ];

  static Map<String, String> parse(String content) {
    final out = <String, String>{};
    try {
      final j = _tryJson(content);
      if (j != null) _walkJson(j, out);
    } catch (_) {}
    _scanText(content, out);

    final norm = <String, String>{};
    out.forEach((k, v) {
      var nk = k.toLowerCase();
      if (nk == 'kg-fake') nk = 'kg_fake';
      if (v.isNotEmpty && v != 'null' && v != 'undefined' && v != '0') {
        norm[nk] = v;
      }
    });
    if ((norm['kg_fake'] ?? '').isEmpty && (norm['userid'] ?? '').isNotEmpty) {
      norm['kg_fake'] = norm['userid']!;
    }
    return norm;
  }

  static dynamic _tryJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      final start = s.indexOf('{');
      final end = s.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          return jsonDecode(s.substring(start, end + 1));
        } catch (_) {}
      }
    }
    return null;
  }

  static void _walkJson(dynamic node, Map<String, String> out) {
    if (node == null) return;
    if (node is Map) {
      final name = node['name']?.toString();
      final value = node['value']?.toString();
      if (name != null && value != null) {
        final ln = name.toLowerCase();
        if (ln == 'cookie') {
          _scanCookieString(value, out);
        } else if (keys.contains(ln) && !out.containsKey(ln)) {
          out[ln] = value;
        }
      }
      if (node.containsKey('cookies') && node['cookies'] is List) {
        for (final c in node['cookies']) {
          if (c is Map) {
            final n = c['name']?.toString().toLowerCase();
            final v = c['value']?.toString();
            if (n != null && v != null && keys.contains(n) && !out.containsKey(n)) {
              out[n] = v;
            }
          }
        }
      }
      final url = node['url']?.toString();
      if (url != null) _scanUrl(url, out);
      final post = node['postData'];
      if (post is Map) {
        final text = post['text']?.toString();
        if (text != null) _scanText(text, out);
        final params = post['params'];
        if (params is List) {
          for (final p in params) {
            if (p is Map) {
              final n = p['name']?.toString().toLowerCase();
              final v = p['value']?.toString();
              if (n != null && v != null && keys.contains(n) && !out.containsKey(n)) {
                out[n] = v;
              }
            }
          }
        }
      }
      for (final v in node.values) {
        if (v is Map || v is List) _walkJson(v, out);
      }
    } else if (node is List) {
      for (final v in node) {
        if (v is Map || v is List) _walkJson(v, out);
      }
    }
  }

  static void _scanCookieString(String cookieStr, Map<String, String> out) {
    for (final pair in cookieStr.split(';')) {
      final t = pair.trim();
      final eq = t.indexOf('=');
      if (eq <= 0) continue;
      final k = t.substring(0, eq).trim().toLowerCase();
      final v = t.substring(eq + 1).trim();
      if (keys.contains(k) && v.isNotEmpty && !out.containsKey(k)) {
        out[k] = v;
      }
    }
  }

  static void _scanUrl(String url, Map<String, String> out) {
    if (!url.startsWith('http') && !url.startsWith('/')) return;
    try {
      final u = Uri.parse(url.startsWith('http') ? url : 'https://x$url');
      for (final e in u.queryParameters.entries) {
        final k = e.key.toLowerCase();
        if (keys.contains(k) && !out.containsKey(k)) {
          out[k] = e.value;
        }
      }
    } catch (_) {}
  }

  static void _scanText(String text, Map<String, String> out) {
    for (final k in keys) {
      if (out.containsKey(k)) continue;
      final re = RegExp(
        '(?<![a-zA-Z0-9_])${RegExp.escape(k)}=([^;&\\s"\'<>,\\}\\]\\[]+)',
        caseSensitive: false,
      );
      final m = re.firstMatch(text);
      if (m != null) {
        final v = m.group(1)!.trim();
        if (v.isNotEmpty && v != 'null' && v != 'undefined') {
          out[k] = v;
        }
      }
    }
  }

  static bool isValid(Map<String, String> m) {
    final t = m['token'] ?? '';
    final u = m['userid'] ?? '';
    return t.length >= 20 && u.isNotEmpty;
  }

  static String describe(Map<String, String> m) {
    if (m.isEmpty) return '（未找到任何字段）';
    final buf = StringBuffer();
    for (final k in ['token', 'userid', 'dfid', 'mid', 'uuid', 'appid', 'clientver', 'kg_fake']) {
      if (m.containsKey(k)) {
        final v = m[k]!;
        final d = v.length > 30
            ? '${v.substring(0, 14)}…${v.substring(v.length - 6)}'
            : v;
        buf.writeln('$k = $d');
      }
    }
    return buf.toString().trim();
  }
}
