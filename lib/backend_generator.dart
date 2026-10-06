import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class BackendGenerator {
  static Future<(bool, String)> generate() async {
    try {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      if (!status.isGranted) {
        var manage = await Permission.manageExternalStorage.status;
        if (!manage.isGranted) {
          manage = await Permission.manageExternalStorage.request();
        }
        if (!manage.isGranted) {
          return (false, '需要存储权限才能保存脚本');
        }
      }

      const downloadDir = '/storage/emulated/0/Download';
      final file = File('$downloadDir/kugou-server.py');
      await file.writeAsString(_serverScript);

      final shFile = File('$downloadDir/install-kugou-server.sh');
      await shFile.writeAsString(_installScript);

      final cfgFile = File('$downloadDir/kugou-server-config.json');
      await cfgFile.writeAsString(_configJson);

      return (true, downloadDir);
    } catch (e) {
      return (false, '生成失败: $e');
    }
  }

  static const String _configJson = '''
{
  "port": 3000,
  "sources": [
    "https://raw.githubusercontent.com/541889964/kugou/main/cloud/cloud.js",
    "https://gitee.com/541889964/kugou/raw/main/cloud/cloud.js"
  ]
}
''';

  static const String _installScript = '''#!/data/data/com.termux/files/usr/bin/bash
set -e
G='\\033[0;32m'; C='\\033[0;36m'; N='\\033[0m'
echo -e "\${C}▸\${N} 安装依赖…"
pkg install -y python curl >/dev/null 2>&1 || true
mkdir -p ~/kugou-server/data
cp /storage/emulated/0/Download/kugou-server.py ~/kugou-server/server.py
cp /storage/emulated/0/Download/kugou-server-config.json ~/kugou-server/config.json
cd ~/kugou-server
cat > start.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
cd ~/kugou-server
pgrep -f "python.*server.py" >/dev/null && { echo "已在运行"; exit 0; }
nohup python server.py > data/stdout.log 2>&1 &
sleep 1
echo "✓ 后端已启动"
EOF2
cat > stop.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
pkill -f "python.*server.py" && echo "✓ 已停止" || echo "未运行"
EOF2
cat > status.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
pgrep -f "python.*server.py" >/dev/null && {
  echo "● 运行中"
  curl -s http://127.0.0.1:3000/ | python -m json.tool 2>/dev/null
} || echo "○ 未运行"
EOF2
cat > update.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
curl -s http://127.0.0.1:3000/refresh | python -m json.tool 2>/dev/null || echo "✗ 后端未运行"
EOF2
chmod +x *.sh
./start.sh
echo ""
echo -e "\${G}✓ 安装完成\${N}"
echo "  ~/kugou-server/start.sh    启动"
echo "  ~/kugou-server/update.sh   更新引擎"
echo "  ~/kugou-server/status.sh   状态"
echo "  ~/kugou-server/stop.sh     停止"
''';

  static const String _serverScript = '''#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""KuGou 个人后端 · 自动适配版"""
import os, json, socket, urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from datetime import datetime

BASE = os.path.dirname(os.path.abspath(__file__))
CFG = os.path.join(BASE, 'config.json')
DATA = os.path.join(BASE, 'data')
ENGINE = os.path.join(DATA, 'cloud.js')
META = os.path.join(DATA, 'meta.json')
LOG = os.path.join(DATA, 'update.log')

DEFAULT = {
    "port": 3000,
    "sources": [
        "https://raw.githubusercontent.com/541889964/kugou/main/cloud/cloud.js",
        "https://gitee.com/541889964/kugou/raw/main/cloud/cloud.js"
    ]
}

def log(m):
    line = f"[{datetime.now().strftime('%H:%M:%S')}] {m}"
    print(line, flush=True)
    try:
        open(LOG, 'a', encoding='utf-8').write(line + '\\n')
    except: pass

def ips():
    r = ['127.0.0.1']
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        if ip and ip not in r: r.append(ip)
    except: pass
    return r

def load_cfg():
    if not os.path.exists(CFG):
        json.dump(DEFAULT, open(CFG, 'w'), indent=2, ensure_ascii=False)
    return json.load(open(CFG, encoding='utf-8'))

def load_meta():
    if os.path.exists(META):
        try: return json.load(open(META, encoding='utf-8'))
        except: pass
    return {"version": 0, "updated_at": None, "source_used": None}

def save_meta(m):
    json.dump(m, open(META, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)

def fetch(url, t=20):
    req = urllib.request.Request(url, headers={'User-Agent': 'KuGouServer/1.0'})
    return urllib.request.urlopen(req, timeout=t).read().decode('utf-8')

def extract_ver(js):
    for l in js.split('\\n'):
        s = l.strip()
        if s.startswith('var ENGINE_VERSION'):
            try: return int(''.join(c for c in s.split('=')[1] if c.isdigit()))
            except: pass
    return 0

def inject(js, port):
    urls = [f'http://{ip}:{port}' for ip in ips()]
    hint = f'\\n// === 后端注入 ===\\nvar BACKEND_URLS = {json.dumps(urls)};\\n// === 结束 ===\\n'
    return hint + js

def update_engine():
    cfg = load_cfg()
    meta = load_meta()
    old = int(meta.get('version', 0))
    port = int(cfg.get('port', 3000))
    log("=" * 40)
    log(f"更新引擎 (v{old})")
    for url in cfg.get('sources', []):
        try:
            log(f"  尝试: {url[:60]}…")
            js = fetch(url)
            if 'function handle' not in js:
                log("  ✗ 无效"); continue
            js = inject(js, port)
            new = extract_ver(js)
            open(ENGINE, 'w', encoding='utf-8').write(js)
            meta.update(version=new, updated_at=datetime.now().isoformat(), source_used=url)
            save_meta(meta)
            log(f"  ✓ v{old} → v{new}")
            return True, new
        except Exception as e:
            log(f"  ✗ {e}")
    log("✗ 全部失败")
    return False, old

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def _j(self, c, o):
        b = json.dumps(o, ensure_ascii=False).encode()
        self.send_response(c)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Cache-Control', 'no-cache')
        self.send_header('Content-Length', str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def _t(self, c, s, cache=False):
        b = s.encode()
        self.send_response(c)
        self.send_header('Content-Type', 'text/plain; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Cache-Control', 'max-age=60' if cache else 'no-cache')
        self.send_header('Content-Length', str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        p = self.path.split('?')[0]
        cfg = load_cfg()
        port = int(cfg.get('port', 3000))
        if p == '/discover':
            self._j(200, {'service': 'KuGou',
                'urls': [f'http://{i}:{port}' for i in ips()], 'port': port}); return
        if p == '/health':
            self._j(200, {'ok': True, 'engine_version': load_meta().get('version', 0)}); return
        if p == '/':
            m = load_meta()
            self._j(200, {'service': 'KuGou', 'engine_version': m.get('version', 0),
                'updated_at': m.get('updated_at'),
                'urls': [f'http://{i}:{port}' for i in ips()]}); return
        if p == '/engine':
            if os.path.exists(ENGINE):
                self._t(200, open(ENGINE, encoding='utf-8').read(), cache=True)
            else:
                self._t(404, '// not ready')
            return
        if p == '/meta': self._j(200, load_meta()); return
        if p == '/refresh':
            ok, v = update_engine()
            self._j(200, {'ok': ok, **load_meta()}); return
        if p == '/log':
            if os.path.exists(LOG):
                self._t(200, ''.join(open(LOG, encoding='utf-8').readlines()[-100:]))
            else:
                self._t(200, 'no log')
            return
        self._t(404, 'not found')

    def do_POST(self):
        if self.path.split('?')[0] == '/refresh':
            ok, v = update_engine()
            self._j(200, {'ok': ok, **load_meta()}); return
        self._t(404, 'not found')

if __name__ == '__main__':
    os.makedirs(DATA, exist_ok=True)
    log("=" * 50)
    log("KuGou 后端 · 自动适配版")
    cfg = load_cfg()
    port = int(cfg.get('port', 3000))
    for ip in ips():
        log(f"  → http://{ip}:{port}")
    if not os.path.exists(ENGINE):
        log("首次启动，拉取引擎…")
        update_engine()
    log(f"服务已启动 :{port}")
    HTTPServer(('0.0.0.0', port), H).serve_forever()
''';
}
