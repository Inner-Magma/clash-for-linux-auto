#!/bin/bash

Server_Dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$Server_Dir/scripts/common.sh"

# 关闭
echo -e "\n正在关闭 Clash 服务..."
bash "$Server_Dir/shutdown.sh"
sleep 2

# 启动
echo -e "正在重新启动 Clash 服务..."

if systemctl is-enabled clash.service &>/dev/null 2>&1; then
    sudo systemctl start clash.service
    log_ok "服务已通过 systemd 重新启动"
else
    CLASH_BIN=$(get_clash_bin) || exit 1
    nohup "$Server_Dir/bin/$CLASH_BIN" -d "$Server_Dir/conf" &> "$Server_Dir/logs/clash.log" &
    if [ $? -eq 0 ]; then
        log_ok "服务启动成功"
    else
        log_err "服务启动失败"
        exit 1
    fi
fi
