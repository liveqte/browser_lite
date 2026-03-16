#!/bin/sh
set -eu

# ============ 环境变量1 ============
export HOME="/config"
export TMPDIR="$HOME/tmp"
echo 'export HOME="/config"' > /root/.bashrc
echo 'export TMPDIR="/config/tmp"' >> /root/.bashrc
[ -d "$TMPDIR" ] || mkdir -p "$TMPDIR"
[ -d "$HOME" ] || mkdir -p "$HOME"
apk add --no-cache curl bash 

# ============ 环境变量2 ============
FF_PORT="${FF_PORT:-${SERVER_PORT:-8080}}"
DISPLAY_NUM="${DISPLAY_NUM:-1}"
VNC_PORT=$((FF_PORT + DISPLAY_NUM))
FF_PASS="${FF_PASS:-}"
DISPLAY=":${DISPLAY_NUM}"
export DISPLAY

NOVNC_DIR="/opt/novnc"
SERVICE_DIR="/etc/service"
LOG_BASE="/var/log"

mkdir -p "${SERVICE_DIR}"

# ✅ 预创建日志目录
for svc in xvnc openbox firefox-esr websockify; do
  mkdir -p "${SERVICE_DIR}/${svc}/log"
  mkdir -p "${LOG_BASE}/${svc}"
done

echo "🚀 启动 Firefox + VNC + noVNC"
echo "📐 DISPLAY=${DISPLAY}, WEB_PORT=${FF_PORT}, VNC_PORT=${VNC_PORT}"

# ============ 生成 VNC 密码 ============
XVNC_AUTH="-SecurityTypes None"
if [ -n "$FF_PASS" ]; then
  mkdir -p ~/.vnc
  if command -v vncpasswd >/dev/null 2>&1; then
    printf "%s\n%s\n" "${FF_PASS:0:8}" "${FF_PASS:0:8}" | vncpasswd -f > ~/.vnc/passwd 2>/dev/null
  else
    printf "%s" "${FF_PASS:0:8}" > ~/.vnc/passwd
  fi
  chmod 600 ~/.vnc/passwd
  XVNC_AUTH="-SecurityTypes VncAuth -PasswordFile ~/.vnc/passwd"
  echo "✅ VNC 密码认证启用"
else
  echo "⚠️  VNC 无密码（建议设置 FF_PASS）"
fi

# ============ 创建 runit 服务 ============

# Xvnc
cat > "${SERVICE_DIR}/xvnc/run" << EOF
#!/bin/sh
exec Xvnc ${DISPLAY} -geometry 1920x1080 -rfbport ${VNC_PORT} ${XVNC_AUTH}
EOF
chmod +x "${SERVICE_DIR}/xvnc/run"

# Openbox
cat > "${SERVICE_DIR}/openbox/run" << EOF
#!/bin/sh
export DISPLAY=${DISPLAY}
exec openbox
EOF
chmod +x "${SERVICE_DIR}/openbox/run"

# Firefox（带 xdotool 窗口调整）
cat > "${SERVICE_DIR}/firefox-esr/run" << 'EOF'
#!/bin/sh
export DISPLAY=:1
export MOZ_DISABLE_GPU_SANDBOX=1
firefox-esr --no-sandbox --width=1280 --height=720 &
FFPID=$!
sleep 5
xdotool search --onlyvisible --class 'firefox' windowmove 0 0 2>/dev/null || true
wait $FFPID
EOF
chmod +x "${SERVICE_DIR}/firefox-esr/run"

# websockify
cat > "${SERVICE_DIR}/websockify/run" << EOF
#!/bin/sh
exec websockify --web ${NOVNC_DIR} ${FF_PORT} localhost:${VNC_PORT}
EOF
chmod +x "${SERVICE_DIR}/websockify/run"

# ✅ 日志服务（统一绝对路径）
for svc in xvnc openbox firefox-esr websockify; do
  cat > "${SERVICE_DIR}/${svc}/log/run" << EOF
#!/bin/sh
exec svlogd -tt ${LOG_BASE}/${svc}
EOF
  chmod +x "${SERVICE_DIR}/${svc}/log/run"
done

# ============ ✅ ff_mag 条件守护 ============
if [ "${FF_MAG:-}" = "1" ] && [ -f "/config/ff_mag.py" ]; then
  echo "🔌 ff_mag 启用（FF_MAG=1）"
  
  mkdir -p "${SERVICE_DIR}/ff_mag/log"
  mkdir -p "${LOG_BASE}/ff_mag"
  
  # 服务主脚本
  cat > "${SERVICE_DIR}/ff_mag/run" << 'EOF'
#!/bin/sh
export HOME="/config"
export TMPDIR="/config/tmp"
cd /config
exec python /config/ff_mag.py
EOF
  chmod +x "${SERVICE_DIR}/ff_mag/run"
  
  # 日志脚本
  cat > "${SERVICE_DIR}/ff_mag/log/run" << EOF
#!/bin/sh
exec svlogd -tt ${LOG_BASE}/ff_mag
EOF
  chmod +x "${SERVICE_DIR}/ff_mag/log/run"
else
  echo "⚠️  ff_mag 未启用（设置 FF_MAG=1 且确保 /config/ff_mag.py 存在）"
fi

# ============ 启动 runit（前台） ============
echo "🔁 启动 runit 服务管理器..."
echo "✅ 服务正在启动，请稍等"
echo "🔗 访问：http://0.0.0.0:${FF_PORT}/index.html"
[ -n "$FF_PASS" ] && echo "🔐 密码：${FF_PASS:0:8}"
echo ""
echo "📝 日志输出："
echo "-------------------------------------------"

exec runsvdir -P "${SERVICE_DIR}"