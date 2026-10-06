import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// 生成 KuGouMusicApi 后端一键部署脚本
class BackendGenerator {
  static Future<(bool, String)> generate() async {
    try {
      var status = await Permission.storage.status;
      if (!status.isGranted) status = await Permission.storage.request();
      if (!status.isGranted) {
        var m = await Permission.manageExternalStorage.status;
        if (!m.isGranted) m = await Permission.manageExternalStorage.request();
        if (!m.isGranted) return (false, '需要存储权限');
      }

      const dir = '/storage/emulated/0/Download';
      final f = File('$dir/kugou-backend.sh');
      await f.writeAsString(_script);
      return (true, '$dir/kugou-backend.sh');
    } catch (e) {
      return (false, '生成失败: $e');
    }
  }

  static const String _script = r'''#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  KuGou 后端 · 双实例部署（普通版 3000 + 概念版 3001）
#  只需运行一次
# ============================================================
set -e
G='\033[0;32m'; R='\033[0;31m'; Y='\033[1;33m'; C='\033[0;36m'; M='\033[0;35m'; N='\033[0m'
ok(){ echo -e "${G}✓${N} $1"; }
err(){ echo -e "${R}✗${N} $1"; }
warn(){ echo -e "${Y}!${N} $1"; }
say(){ echo -e "${C}▸${N} $1"; }
step(){ echo ""; echo -e "${M}━━━ $1 ━━━${N}"; }

clear
echo -e "${M}"
cat <<'BANNER'
 ╔════════════════════════════════════════════════════╗
 ║   🎵 KuGou 后端 · 双实例部署                        ║
 ║   普通版 :3000 + 概念版 :3001                       ║
 ╚════════════════════════════════════════════════════╝
BANNER
echo -e "${N}"

# ============================================================
# 1. 依赖
# ============================================================
step "安装依赖"
for pkg in nodejs-lts git curl python; do
  if ! command -v $pkg >/dev/null 2>&1 && [ "$pkg" != "nodejs-lts" ]; then
    say "安装 $pkg…"
    pkg install -y $pkg >/dev/null 2>&1 || true
  fi
done
command -v node >/dev/null 2>&1 || { pkg install -y nodejs-lts >/dev/null 2>&1; }
ok "Node $(node -v)"

# ============================================================
# 2. 清理旧进程
# ============================================================
step "清理旧进程"
pkill -f "node.*KuGouMusicApi" 2>/dev/null && warn "已停旧 Node" || true
pkill -f "python.*server.py" 2>/dev/null && warn "已停旧 Python" || true
sleep 1
ok "干净"

# ============================================================
# 3. 下载 KuGouMusicApi
# ============================================================
step "下载 KuGouMusicApi"

cd ~
[ -d KuGouMusicApi-src ] && rm -rf KuGouMusicApi-src

SUCCESS=0
for url in \
  "https://ghproxy.net/https://github.com/MakcRe/KuGouMusicApi/archive/refs/heads/main.zip" \
  "https://gh-proxy.com/https://github.com/MakcRe/KuGouMusicApi/archive/refs/heads/main.zip" \
  "https://github.akams.cn/https://github.com/MakcRe/KuGouMusicApi/archive/refs/heads/main.zip" \
  "https://github.com/MakcRe/KuGouMusicApi/archive/refs/heads/main.zip"
do
  say "尝试: ${url:0:60}…"
  if curl -fsSL --max-time 120 -o /tmp/kugou-api.zip "$url"; then
    SUCCESS=1
    break
  fi
done

if [ "$SUCCESS" != "1" ]; then
  err "下载失败"
  echo "  请手动下载:"
  echo "  https://github.com/MakcRe/KuGouMusicApi/archive/refs/heads/main.zip"
  echo "  放到 /storage/emulated/0/Download/kugou-api.zip"
  echo "  然后重新运行本脚本"
  exit 1
fi
ok "下载完成"

say "解压…"
unzip -q /tmp/kugou-api.zip -d ~/
mv ~/KuGouMusicApi-main ~/KuGouMusicApi-src
cd ~/KuGouMusicApi-src

# 精简
rm -rf .git .github docs test *.md 2>/dev/null || true

ok "源码就绪"

# ============================================================
# 4. 复制两份
# ============================================================
step "部署双实例"

for mode in standard lite; do
  target="$HOME/KuGouMusicApi-$mode"
  say "部署 $mode…"
  [ -d "$target" ] && rm -rf "$target"
  cp -r ~/KuGouMusicApi-src "$target"
  cd "$target"

  # 安装依赖（只在第一次）
  if [ ! -d node_modules ]; then
    say "  npm install（约 2 分钟）…"
    npm install --production >/dev/null 2>&1
  fi

  # 写 .env
  if [ "$mode" = "lite" ]; then
    printf 'platform=lite\nPORT=3001\n' > .env
  else
    printf 'platform=standard\nPORT=3000\n' > .env
  fi
  ok "$mode 就绪"
done

# ============================================================
# 5. 启动
# ============================================================
step "启动服务"

say "启动普通版 :3000…"
cd ~/KuGouMusicApi-standard
nohup npm run dev > ~/kugou-standard.log 2>&1 &
echo "  PID: $!"
sleep 1

say "启动概念版 :3001…"
cd ~/KuGouMusicApi-lite
nohup npm run dev > ~/kugou-lite.log 2>&1 &
echo "  PID: $!"

say "等待服务就绪（最多 30 秒）…"
STD_READY=0
LITE_READY=0
for i in $(seq 1 30); do
  sleep 1
  if [ "$STD_READY" = "0" ]; then
    curl -sf http://127.0.0.1:3000/ >/dev/null 2>&1 && STD_READY=1
  fi
  if [ "$LITE_READY" = "0" ]; then
    curl -sf http://127.0.0.1:3001/ >/dev/null 2>&1 && LITE_READY=1
  fi
  if [ "$STD_READY" = "1" ] && [ "$LITE_READY" = "1" ]; then
    break
  fi
  echo -ne "\r  等待中… ${i}s (普通:$STD_READY 概念:$LITE_READY)"
done
echo ""

[ "$STD_READY" = "1" ] && ok "普通版 :3000 就绪" || err "普通版启动失败"
[ "$LITE_READY" = "1" ] && ok "概念版 :3001 就绪" || err "概念版启动失败"

# ============================================================
# 6. 完成
# ============================================================
IP=$(python3 -c "
import socket
try:
    s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
    s.connect(('8.8.8.8',80))
    print(s.getsockname()[0])
    s.close()
except: print('')
" 2>/dev/null)

echo ""
echo -e "${G}╔════════════════════════════════════════════════════╗${N}"
echo -e "${G}║   🎉 双实例部署完成                                ║${N}"
echo -e "${G}╚════════════════════════════════════════════════════╝${N}"
echo ""
echo -e "  普通版: ${C}http://127.0.0.1:3000${N}"
echo -e "  概念版: ${C}http://127.0.0.1:3001${N}"
[ -n "$IP" ] && {
  echo ""
  echo -e "  局域网:"
  echo -e "    普通版: ${C}http://${IP}:3000${N}"
  echo -e "    概念版: ${C}http://${IP}:3001${N}"
}
echo ""
echo -e "  常用命令:"
echo -e "    ${C}tail -f ~/kugou-standard.log${N}   普通版日志"
echo -e "    ${C}tail -f ~/kugou-lite.log${N}       概念版日志"
echo -e "    ${C}pkill -f KuGouMusicApi${N}         停止全部"
echo ""
echo -e "  ${Y}现在打开 App，进设置页填 Cookie${N}"
echo ""
exit 0
''';
}
