#!/bin/bash

Server_Dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$Server_Dir/scripts/common.sh"

if systemctl is-active clash.service &>/dev/null 2>&1; then
    sudo systemctl stop clash.service
    log_ok "Clash 服务已通过 systemd 关闭"
else
    if is_clash_running; then
        kill $(pgrep -f 'clash-linux-a') 2>/dev/null
        sleep 1
        is_clash_running && kill -9 $(pgrep -f 'clash-linux-a') 2>/dev/null
        log_ok "Clash 服务已关闭"
    else
        log_warn "Clash 服务未在运行"
    fi
fi

> /etc/profile.d/clash.sh 2>/dev/null
echo -e "请执行以下命令关闭系统代理: proxy_off\n"
