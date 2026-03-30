#!/bin/bash
# 一键安装脚本（需要 sudo 权限）
# 功能：安装 systemd 服务 + 配置登录自动代理
# 可在任意目录下运行，所有路径自动推导

set -e

SERVER_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SERVER_DIR/scripts/common.sh"

CLASH_BIN=$(get_clash_bin) || exit 1
CLASH_BIN_PATH="$SERVER_DIR/bin/$CLASH_BIN"
CONF_DIR="$SERVER_DIR/conf"
AUTO_PROXY_SCRIPT="$SERVER_DIR/scripts/auto_proxy.sh"
BASHRC="$HOME/.bashrc"

echo "============================================"
echo "  Clash for Linux 安装程序"
echo "  项目目录: $SERVER_DIR"
echo "  CPU 架构: $(get_cpu_arch)"
echo "  二进制:   $CLASH_BIN"
echo "============================================"
echo ""

# 检查必要文件
if [ ! -x "$CLASH_BIN_PATH" ]; then
    chmod +x "$CLASH_BIN_PATH" 2>/dev/null || {
        log_err "二进制文件不存在或无法执行: $CLASH_BIN_PATH"
        exit 1
    }
fi

if [ ! -f "$CONF_DIR/config.yaml" ]; then
    log_warn "配置文件不存在，请先运行 start.sh 下载订阅配置"
    read -p "是否现在运行 start.sh？(y/N): " run_start
    if [[ "$run_start" =~ ^[yY]$ ]]; then
        bash "$SERVER_DIR/start.sh"
    else
        exit 1
    fi
fi

# ===== 步骤 1: 关闭已有的 Clash 进程 =====
echo ""
echo "[1/3] 清理已有 Clash 进程..."
if is_clash_running; then
    sudo kill $(pgrep -f 'clash-linux-a') 2>/dev/null
    sleep 1
    if is_clash_running; then
        sudo kill -9 $(pgrep -f 'clash-linux-a') 2>/dev/null
    fi
    log_ok "已清理旧进程"
else
    echo "    无需清理"
fi

# ===== 步骤 2: 安装 systemd 服务 =====
echo ""
echo "[2/3] 安装 systemd 服务..."

# 动态生成 service 文件（不使用模板中的硬编码路径）
sudo tee /etc/systemd/system/clash.service > /dev/null <<EOF
[Unit]
Description=Clash Proxy Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${CLASH_BIN_PATH} -d ${CONF_DIR}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable clash.service
sudo systemctl start clash.service

sleep 2

if systemctl is-active clash.service &>/dev/null; then
    log_ok "systemd 服务安装成功，已设为开机自启"
else
    log_err "服务启动失败，请检查: journalctl -u clash.service"
    exit 1
fi

# ===== 步骤 3: 配置登录自动代理 =====
echo ""
echo "[3/3] 配置登录自动代理..."

# 标记行，用于识别和清理
MARKER="# >>> clash-for-linux auto-proxy >>>"
MARKER_END="# <<< clash-for-linux auto-proxy <<<"

# 先清理旧的配置（如果存在）
if grep -q "$MARKER" "$BASHRC" 2>/dev/null; then
    # 删除旧的 marker 之间的内容
    sed -i "/$MARKER/,/$MARKER_END/d" "$BASHRC"
    log_warn "已清理旧的自动代理配置"
fi

# 写入新配置
cat >> "$BASHRC" <<EOF

${MARKER}
if [ -f "${AUTO_PROXY_SCRIPT}" ]; then
    source "${AUTO_PROXY_SCRIPT}"
fi
${MARKER_END}
EOF

log_ok "已添加到 $BASHRC"

# ===== 完成 =====
echo ""
echo "============================================"
echo "  安装完成！"
echo "============================================"
echo ""
echo "  管理命令："
echo "    sudo systemctl status clash    # 查看状态"
echo "    sudo systemctl restart clash   # 重启服务"
echo "    sudo systemctl stop clash      # 停止服务"
echo "    sudo systemctl disable clash   # 取消开机自启"
echo ""
echo "  代理控制："
echo "    proxy_on                       # 开启代理"
echo "    proxy_off                      # 关闭代理"
echo ""
echo "  节点选择："
echo "    bash $SERVER_DIR/scripts/proxy-select.sh"
echo ""
echo "  立即生效（不用重新登录）："
echo "    source ~/.bashrc"
echo ""
