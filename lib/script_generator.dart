import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class ScriptGenerator {
  static const String scriptPath = '/storage/emulated/0/Download/update-kugou.sh';
  static const String command = 'bash /storage/emulated/0/Download/update-kugou.sh';

  static Future<(bool, String)> generate() async {
    try {
      var s = await Permission.storage.status;
      if (!s.isGranted) s = await Permission.storage.request();
      if (!s.isGranted) {
        var m = await Permission.manageExternalStorage.status;
        if (!m.isGranted) m = await Permission.manageExternalStorage.request();
        if (!m.isGranted) return (false, '需要存储权限');
      }
      await File(scriptPath).writeAsString(_script);
      return (true, scriptPath);
    } catch (e) {
      return (false, '生成失败: $e');
    }
  }

  static Future<bool> exists() async {
    try { return await File(scriptPath).exists(); } catch (_) { return false; }
  }

  static const String _script = r'''#!/data/data/com.termux/files/usr/bin/bash
set -e
G='\033[0;32m'; R='\033[0;31m'; C='\033[0;36m'; N='\033[0m'
OUT="/storage/emulated/0/Download/kugou-signature.json"
BASE="https://raw.githubusercontent.com/541889964/kugou/main/cloud/signature.json"
echo -e "${C}▸${N} 下载最新配置…"
for u in "$BASE" \
  "https://gh-proxy.com/$BASE" \
  "https://ghfast.top/$BASE" \
  "https://ghproxy.net/$BASE" \
  "https://github.moeyy.xyz/$BASE"
do
  echo "  尝试: ${u:0:60}…"
  if curl -fL --retry 2 --max-time 30 -o "$OUT.tmp" "$u" 2>/dev/null; then
    if python3 -c "import json;json.load(open('$OUT.tmp'))" 2>/dev/null; then
      mv "$OUT.tmp" "$OUT"
      V=$(python3 -c "import json;print(json.load(open('$OUT')).get('version','?'))")
      echo -e "${G}✓${N} 更新成功 v$V"
      echo "  回到 App → 设置 → 重载配置"
      exit 0
    fi
  fi
  rm -f "$OUT.tmp"
done
echo -e "${R}✗${N} 全部失败"
exit 1
''';
}
