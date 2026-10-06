#!/data/data/com.termux/files/usr/bin/bash
set -e
G='\033[0;32m'; R='\033[0;31m'; C='\033[0;36m'; N='\033[0m'
ok(){ echo -e "${G}✓${N} $1"; }
say(){ echo -e "${C}▸${N} $1"; }
pkg install -y nodejs-lts curl unzip >/dev/null 2>&1 || true
pkill -f KuGouMusicApi 2>/dev/null || true
sleep 1
cd ~
[ -d KuGouMusicApi-src ] || {
  for u in "https://gh-proxy.com/https://github.com/MakcRe/KuGouMusicApi/archive/refs/heads/main.zip" \
    "https://ghfast.top/https://github.com/MakcRe/KuGouMusicApi/archive/refs/heads/main.zip" \
    "https://github.com/MakcRe/KuGouMusicApi/archive/refs/heads/main.zip"; do
    curl -fL --retry 2 -o kugou.zip "$u" 2>/dev/null && unzip -tq kugou.zip >/dev/null 2>&1 && break
    rm -f kugou.zip
  done
  unzip -q kugou.zip
  mv KuGouMusicApi-main KuGouMusicApi-src
  rm -rf KuGouMusicApi-src/.git KuGouMusicApi-src/.github KuGouMusicApi-src/docs kugou.zip
}
for m in lite standard; do
  t="$HOME/KuGouMusicApi-$m"
  [ -d "$t" ] && rm -rf "$t"
  cp -r ~/KuGouMusicApi-src "$t"
  cd "$t"
  [ -d node_modules ] || { npm config set registry https://registry.npmmirror.com >/dev/null 2>&1; npm install --production --no-audit --no-fund 2>&1 | tail -1; }
  if [ "$m" = "lite" ]; then printf 'platform=lite\nPORT=3000\n' > .env; else printf 'platform=standard\nPORT=3001\n' > .env; fi
  ok "$m 就绪"
done
cd ~/KuGouMusicApi-lite
nohup node app.js > ~/kugou-lite.log 2>&1 &
sleep 1
cd ~/KuGouMusicApi-standard
nohup node app.js > ~/kugou-standard.log 2>&1 &
L=0; S=0
for i in $(seq 1 30); do
  sleep 1
  [ "$L" = "0" ] && curl -sf http://127.0.0.1:3000/ >/dev/null 2>&1 && L=1
  [ "$S" = "0" ] && curl -sf http://127.0.0.1:3001/ >/dev/null 2>&1 && S=1
  [ "$L" = "1" ] && [ "$S" = "1" ] && break
done
echo ""
[ "$L" = "1" ] && ok "概念版 :3000" || echo "概念版失败"
[ "$S" = "1" ] && ok "普通版 :3001" || echo "普通版失败"
echo "  停止: bash /storage/emulated/0/Download/kugou-backend-stop.sh"
