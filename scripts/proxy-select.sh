#!/bin/bash
# ─────────────────────────────────────────────
#  Clash 代理节点选择器
#  路径自动推导，可移植
# ─────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SERVER_DIR=$(dirname "$SCRIPT_DIR")

source "$SCRIPT_DIR/common.sh"
load_env "$SERVER_DIR"

api_url="http://localhost:${CLASH_API_PORT:-9090}"
Secret="${CLASH_SECRET:?Error: CLASH_SECRET not set in .env}"
DEFAULT_GROUP="${CLASH_GROUP:-Ghelper}"
modes=("Rule" "Global" "Direct")

# ── 样式 ──
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
MAGENTA='\033[35m'
BLUE='\033[34m'

# ── API 封装 ──
api_get() {
    curl -s -H "Authorization: Bearer ${Secret}" "$api_url$1" 2>/dev/null
}

api_put() {
    curl -s -o /dev/null -w "%{http_code}" -X PUT "$api_url$1" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${Secret}" \
        -d "$2" 2>/dev/null
}

api_patch() {
    curl -s -o /dev/null -w "%{http_code}" -X PATCH "$api_url$1" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${Secret}" \
        -d "$2" 2>/dev/null
}

# ── 查询当前状态 ──
get_current_mode() {
    api_get "/configs" | jq -r '.mode // "unknown"' 2>/dev/null
}

get_current_node() {
    api_get "/proxies" | jq -r ".proxies[\"$1\"].now // \"unknown\"" 2>/dev/null
}

get_proxy_list() {
    local group="${1:-$DEFAULT_GROUP}"
    proxies=()
    readarray -t proxies < <(api_get "/proxies" | jq -r ".proxies[\"${group}\"].all[]?" 2>/dev/null)
}

# ── 绘制 ──
draw_line() {
    printf '  '
    printf '%0.s-' $(seq 1 "${1:-45}")
    echo
}

show_status() {
    local mode current_node
    mode=$(get_current_mode)
    current_node=$(get_current_node "$DEFAULT_GROUP")

    echo ""
    echo -e "  ${BOLD}${CYAN}Clash Proxy Manager${RESET}"
    draw_line 45
    echo -e "  ${DIM}Mode${RESET}   ${BOLD}${mode}${RESET}"
    echo -e "  ${DIM}Node${RESET}   ${BOLD}${current_node}${RESET}"
    echo -e "  ${DIM}Group${RESET}  ${DEFAULT_GROUP}"
    draw_line 45
}

show_menu() {
    echo ""
    echo -e "  ${BOLD}1${RESET}  切换代理模式"
    echo -e "  ${BOLD}2${RESET}  切换代理节点"
    echo -e "  ${BOLD}q${RESET}  退出"
    echo ""
}

# ── 选择节点 ──
select_proxy() {
    local group="${1:-$DEFAULT_GROUP}"
    local current_node
    current_node=$(get_current_node "$group")

    get_proxy_list "$group"

    if [ ${#proxies[@]} -eq 0 ]; then
        log_warn "未找到节点，请检查策略组: $group"
        return
    fi

    echo ""
    echo -e "  ${BOLD}${MAGENTA}节点列表${RESET} ${DIM}($group)${RESET}"
    draw_line 45

    local i=1
    for proxy in "${proxies[@]}"; do
        if [ "$proxy" = "$current_node" ]; then
            printf "  ${GREEN}${BOLD}%3d  %-36s *${RESET}\n" "$i" "$proxy"
        else
            printf "  %3d  %s\n" "$i" "$proxy"
        fi
        i=$((i+1))
    done

    draw_line 45
    echo -e "  ${DIM}当前: ${current_node}${RESET}"
    echo ""
    read -p "  选择编号 (回车取消): " idx

    [ -z "$idx" ] && return

    if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -lt 1 ] || [ "$idx" -gt ${#proxies[@]} ]; then
        log_err "无效输入"
        return
    fi

    local selected="${proxies[$((idx-1))]}"
    # URL encode group name for API path
    local encoded_group
    encoded_group=$(printf '%s' "$group" | jq -sRr @uri 2>/dev/null || echo "$group")
    local code
    code=$(api_put "/proxies/${encoded_group}" "{\"name\":\"${selected}\"}")

    if [ "$code" = "204" ]; then
        log_ok "已切换到: $selected"
    else
        log_err "切换失败 (HTTP $code)"
    fi
}

# ── 选择模式 ──
select_mode() {
    local current_mode
    current_mode=$(get_current_mode)

    echo ""
    echo -e "  ${BOLD}${BLUE}代理模式${RESET}"
    draw_line 45

    local i=1
    for mode in "${modes[@]}"; do
        local lower
        lower=$(echo "$mode" | tr '[:upper:]' '[:lower:]')
        if [ "$lower" = "$current_mode" ]; then
            printf "  ${GREEN}${BOLD}%3d  %-36s *${RESET}\n" "$i" "$mode"
        else
            printf "  %3d  %s\n" "$i" "$mode"
        fi
        i=$((i+1))
    done

    draw_line 45
    echo ""
    read -p "  选择编号 (回车取消): " idx

    [ -z "$idx" ] && return

    if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -lt 1 ] || [ "$idx" -gt ${#modes[@]} ]; then
        log_err "无效输入"
        return
    fi

    local selected="${modes[$((idx-1))]}"
    local lower_mode
    lower_mode=$(echo "$selected" | tr '[:upper:]' '[:lower:]')

    local code
    code=$(api_patch "/configs" "{\"mode\":\"${lower_mode}\"}")

    if [ "$code" = "204" ]; then
        log_ok "模式已切换到: $selected"
        case "$selected" in
            Rule)   select_proxy "$DEFAULT_GROUP" ;;
            Global) select_proxy "GLOBAL" ;;
        esac
    else
        log_err "模式切换失败 (HTTP $code)"
    fi
}

# ── 主循环 ──
clear 2>/dev/null
while true; do
    show_status
    show_menu
    read -p "  > " choice
    case "$choice" in
        1) select_mode ;;
        2) select_proxy ;;
        q|Q|3) echo ""; break ;;
        *) log_err "无效输入" ;;
    esac
done
