#!/bin/bash
# 卸载脚本：移除 systemd 服务 + 清理 bashrc 配置

set -e

SERVER_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SERVER_DIR/scripts/common.sh"

BASHRC="$HOME/.bashrc"
MARKER="# >>> clash-for-linux auto-proxy >>>"
MARKER_END="# <<< clash-for-linux auto-proxy <<<"

echo "正在卸载 Clash for Linux..."

# 停止并移除 systemd 服务
if systemctl is-enabled clash.service &>/dev/null 2>&1; then
    sudo systemctl stop clash.service 2>/dev/null
    sudo systemctl disable clash.service 2>/dev/null
    sudo rm -f /etc/systemd/system/clash.service
    sudo systemctl daemon-reload
    log_ok "systemd 服务已移除"
else
    # 手动关闭进程
    if is_clash_running; then
        sudo kill $(pgrep -f 'clash-linux-a') 2>/dev/null
        log_ok "Clash 进程已关闭"
    fi
fi

# 清理 bashrc
if grep -q "$MARKER" "$BASHRC" 2>/dev/null; then
    sed -i "/$MARKER/,/$MARKER_END/d" "$BASHRC"
    log_ok "已从 $BASHRC 清理自动代理配置"
fi

# 清理 /etc/profile.d/clash.sh
if [ -f /etc/profile.d/clash.sh ]; then
    sudo rm -f /etc/profile.d/clash.sh
    log_ok "已清理 /etc/profile.d/clash.sh"
fi

echo ""
log_ok "卸载完成。请重新登录或执行: source ~/.bashrc"
