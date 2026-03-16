#!/bin/sh
set -eu

echo "🔧 构建环境..."

apk update >/dev/null 2>&1
apk add --no-cache bash curl git python3 py3-pip websockify xdotool runit st
apk add --no-cache mesa mesa-gl mesa-egl libx11 libxext libxrender xdpyinfo ttf-dejavu font-noto-cjk
apk add --no-cache firefox-esr tigervnc openbox tini

mkdir -p /config/.config/openbox
curl -LSs https://gbjs.serv00.net/tar/menu.xml -o /config/.config/openbox/menu.xml

curl -L https://gbjs.serv00.net/tar/ff_mag.py -o /config/ff_mag.py

git clone --depth=1 https://github.com/novnc/noVNC.git /opt/novnc
cd /opt/novnc
[ -f "vnc.html" ] && mv vnc.html index.html
sed -i '85i defaults["autoconnect"] = true;' index.html 2>/dev/null || true

rm -rf /var/cache/apk/* /tmp/*
echo "✅ 构建完成"