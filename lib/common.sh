#!/usr/bin/env bash
# common.sh - 公共函数：颜色输出、菜单渲染、SSH封装、kubectl封装
# 所有模块共享的基础函数库

# ============================================================
# 颜色定义
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 颜色输出函数
print_red()    { echo -e "${RED}$1${NC}"; }
print_green()  { echo -e "${GREEN}$1${NC}"; }
print_yellow() { echo -e "${YELLOW}$1${NC}"; }
print_blue()   { echo -e "${BLUE}$1${NC}"; }
print_cyan()   { echo -e "${CYAN}$1${NC}"; }
print_bold()   { echo -e "${BOLD}$1${NC}"; }

# ============================================================
# 菜单渲染
# ============================================================

# 渲染带框的标题
print_header() {
    local title="$1"
    echo ""
    print_bold "╔══════════════════════════════════════╗"
    print_bold "║       ${title}"
    print_bold "╠══════════════════════════════════════╣"
}

# 渲染菜单项
print_menu_item() {
    local num="$1" text="$2"
    printf "  ${CYAN}[%s]${NC}  %s\n" "$num" "$text"
}

# 渲染菜单底框
print_footer() {
    print_bold "╚══════════════════════════════════════╝"
}

# 读取用户选择（带默认值）
read_input() {
    local prompt="$1" default="${2:-}"
    if [[ -n "$default" ]]; then
        read -rp "$(echo -e "${CYAN}${prompt}${NC} [默认: ${default}]: ")" input
        echo "${input:-$default}"
    else
        read -rp "$(echo -e "${CYAN}${prompt}${NC}: ")" input
        echo "$input"
    fi
}

# 读取用户确认（y/n）
read_confirm() {
    local prompt="${1:-确认执行？}"
    local default="${2:-y}"
    local yn
    read -rp "$(echo -e "${YELLOW}${prompt} (y/n) [默认: ${default}]: ${NC}")" yn
    yn="${yn:-$default}"
    [[ "$yn" =~ ^[Yy]$ ]]
}

# ============================================================
# SSH 封装（使用 expect 自动输入密码）
# ============================================================

# expect 自动 SSH 执行远程命令
# 用法: ssh_exec <user> <host> <password> <command...>
ssh_exec() {
    local user="$1" host="$2" password="$3"
    shift 3
    expect -c "
        set timeout 30
        spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${user}@${host} $@
        expect {
            \"*assword*\" { send \"${password}\r\"; exp_continue }
            eof
        }
    " 2>/dev/null
}

# expect 自动 SSH 交互式登录
# 用法: ssh_login <user> <host> <password>
ssh_login() {
    local user="$1" host="$2" password="$3"
    shift 3
    expect -c "
        set timeout -1
        spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${user}@${host} $@
        expect {
            \"*assword*\" { send \"${password}\r\"; interact }
        }
    "
}

# expect 自动 SCP 传输文件
# 用法: scp_transfer <user> <password> <src_file> <host>:<dst_path>
scp_transfer() {
    local user="$1" password="$2" src="$3" dst="$4"
    expect -c "
        set timeout 60
        spawn scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${src} ${user}@${dst}
        expect {
            \"*assword*\" { send \"${password}\r\"; exp_continue }
            eof
        }
    " 2>/dev/null
}

# expect 自动 SSH 端口转发（后台运行）
# 用法: ssh_port_forward <user> <host> <password> <local_port> <remote_port>
ssh_port_forward() {
    local user="$1" host="$2" password="$3" local_port="$4" remote_port="$5"
    expect -c "
        set timeout -1
        spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -N -L ${local_port}:localhost:${remote_port} -f ${user}@${host}
        expect {
            \"*assword*\" { send \"${password}\r\"; exp_continue }
            eof
        }
    " 2>/dev/null
    echo $!
}

# ============================================================
# kubectl 封装
# ============================================================

# kubectl 命令路径（支持环境变量覆盖，默认 /opt/kubectl）
KUBECTL_BIN="${KUBECTL_BIN:-$(command -v kubectl 2>/dev/null || echo '/opt/kubectl')}"
KUBECTL_CMD="$KUBECTL_BIN --insecure-skip-tls-verify"

# 获取所有节点信息
# 输出格式: "节点名|节点IP|节点状态" 每行一条
kubectl_get_nodes() {
    "$KUBECTL_CMD" get nodes -o custom-columns=NAME:.metadata.name,IP:.status.addresses[0].address,STATUS:.status.conditions[-1].type --no-headers 2>/dev/null \
        | awk '{print $1"|"$2"|"$3}'
}

# 获取所有 Pod 信息
# 输出格式: "命名空间|Pod名|节点名|容器状态" 每行一条
kubectl_get_pods() {
    "$KUBECTL_CMD" get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase --no-headers 2>/dev/null \
        | awk '{print $1"|"$2"|"$3"|"$4}'
}

# 获取 Pod 中的容器列表
# 用法: kubectl_get_containers <pod_name> <namespace>
kubectl_get_containers() {
    local pod="$1" ns="${2:-default}"
    "$KUBECTL_CMD" get pod "$pod" -n "$ns" -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}{end}' 2>/dev/null
}

# ============================================================
# 架构检测
# ============================================================

# 检测当前系统架构
# 返回: x86 或 arm
detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) echo "x86" ;;
        aarch64|arm64) echo "arm" ;;
        *) echo "x86" ;; # 默认x86
    esac
}

# ============================================================
# 文件大小格式化
# ============================================================

# 将字节数转为人类可读格式
format_size() {
    local bytes="$1"
    if [[ $bytes -ge 1073741824 ]]; then
        echo "$(echo "scale=1; $bytes/1073741824" | bc)GB"
    elif [[ $bytes -ge 1048576 ]]; then
        echo "$(echo "scale=1; $bytes/1048576" | bc)MB"
    elif [[ $bytes -ge 1024 ]]; then
        echo "$(echo "scale=1; $bytes/1024" | bc)KB"
    else
        echo "${bytes}B"
    fi
}

# ============================================================
# 时间戳生成
# ============================================================

# 生成备份用的时间戳，格式: YYYYMMDD_HHMMSS
gen_timestamp() {
    date "+%Y%m%d_%H%M%S"
}
