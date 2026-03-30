#!/bin/bash
# 公共函数库 - 所有脚本共享，避免重复代码

# 颜色输出
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
RESET='\033[0m'

log_ok()   { echo -e "${GREEN}[√] $*${RESET}"; }
log_err()  { echo -e "${RED}[×] $*${RESET}"; }
log_warn() { echo -e "${YELLOW}[!] $*${RESET}"; }

# 获取项目根目录（从任意脚本调用均可）
get_server_dir() {
    local script_path="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
    local script_dir
    script_dir=$(cd "$(dirname "$script_path")" && pwd)
    # 如果脚本在 scripts/ 目录下，往上一级
    if [[ "$(basename "$script_dir")" == "scripts" ]]; then
        dirname "$script_dir"
    else
        echo "$script_dir"
    fi
}

# 获取 CPU 架构
get_cpu_arch() {
    local arch
    arch=$(uname -m 2>/dev/null)
    if [[ -z "$arch" ]]; then
        arch=$(arch 2>/dev/null)
    fi
    echo "$arch"
}

# 根据 CPU 架构返回对应的二进制文件名
get_clash_bin() {
    local arch
    arch=$(get_cpu_arch)
    case "$arch" in
        x86_64|amd64)    echo "clash-linux-amd64" ;;
        aarch64|arm64)   echo "clash-linux-arm64" ;;
        armv7*)          echo "clash-linux-armv7" ;;
        *)
            log_err "不支持的 CPU 架构: $arch"
            return 1
            ;;
    esac
}

# 检查 Clash 是否在运行
is_clash_running() {
    pgrep -f 'clash-linux-a' &>/dev/null
}

# 等待 Clash API 就绪
wait_clash_api() {
    local timeout=${1:-10}
    local i=0
    while [ $i -lt $timeout ]; do
        if curl -s -o /dev/null -w "%{http_code}" -m 1 "http://127.0.0.1:${CLASH_API_PORT:-9090}" 2>/dev/null | grep -q '[2345][0-9][0-9]'; then
            return 0
        fi
        sleep 1
        i=$((i+1))
    done
    return 1
}

# 加载 .env 配置
load_env() {
    local server_dir="$1"
    if [ -f "$server_dir/.env" ]; then
        source "$server_dir/.env"
    else
        log_err ".env 文件不存在: $server_dir/.env"
        return 1
    fi
}
