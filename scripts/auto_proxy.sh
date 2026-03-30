#!/bin/bash
# 登录时自动启动代理环境
# 使用方法: 在 ~/.bashrc 中添加 source /path/to/clash-for-linux/scripts/auto_proxy.sh
# 路径从脚本自身位置动态推导，无需手动修改

# 推导项目目录
_AUTO_PROXY_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)
CLASH_DIR=$(dirname "$_AUTO_PROXY_DIR")
unset _AUTO_PROXY_DIR

source "$CLASH_DIR/scripts/common.sh"

# 检查 Clash 是否在运行，未运行则启动
if ! is_clash_running; then
    log_warn "Clash 未运行，正在启动..."
    if systemctl is-enabled clash.service &>/dev/null 2>&1; then
        sudo systemctl start clash.service 2>/dev/null
    else
        local_bin=$(get_clash_bin)
        if [ -n "$local_bin" ] && [ -x "$CLASH_DIR/bin/$local_bin" ]; then
            nohup "$CLASH_DIR/bin/$local_bin" -d "$CLASH_DIR/conf" &> "$CLASH_DIR/logs/clash.log" &
        fi
    fi
    sleep 2
fi

# 检查 Clash API 是否可用
if wait_clash_api 3; then
    export http_proxy=http://127.0.0.1:7890
    export https_proxy=http://127.0.0.1:7890
    export HTTP_PROXY=http://127.0.0.1:7890
    export HTTPS_PROXY=http://127.0.0.1:7890
    export no_proxy=127.0.0.1,localhost
    export NO_PROXY=127.0.0.1,localhost
    log_ok "Clash 代理已自动开启"

    # 交互式 shell 中提示节点选择（仅首次）
    if [[ $- == *i* ]] && [ -z "$CLASH_NODE_SELECTED" ]; then
        export CLASH_NODE_SELECTED=1
        echo ""
        read -t 5 -p "是否选择代理节点？(y/N, 5秒后自动跳过): " select_node
        echo ""
        if [[ "$select_node" =~ ^[yY]$ ]]; then
            bash "$CLASH_DIR/scripts/proxy-select.sh"
        fi
    fi
else
    log_err "Clash 服务未就绪，代理未开启"
fi

# proxy_on / proxy_off 快捷函数
proxy_on() {
    export http_proxy=http://127.0.0.1:7890
    export https_proxy=http://127.0.0.1:7890
    export HTTP_PROXY=http://127.0.0.1:7890
    export HTTPS_PROXY=http://127.0.0.1:7890
    export no_proxy=127.0.0.1,localhost
    export NO_PROXY=127.0.0.1,localhost
    echo -e "\033[32m[√] 已开启代理\033[0m"
}

proxy_off() {
    unset http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY
    echo -e "\033[31m[×] 已关闭代理\033[0m"
}
