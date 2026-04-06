#!/usr/bin/env bash
# debug.sh - 功能3：一键开启远程Debug
# 支持两级端口转发、JDK8/21适配、防重复参数、健康检查禁用

DEBUG_STATE_FILE="/tmp/devtools_debug_state_$$"

do_debug() {
    echo ""
    keyword=$(read_input "$(msg 'search_keyword')")
    [[ -z "$keyword" ]] && return

    if ! search_select "$keyword"; then
        return
    fi

    local node="$SELECTED_NODE"
    local container="$SELECTED_CONTAINER"
    local ip="$SELECTED_IP"

    # 获取容器ID
    local container_id
    container_id=$(ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" \
        "docker ps --format '{{.ID}} {{.Names}}' | grep '$container' | awk '{print \$1}' | head -1")

    if [[ -z "$container_id" ]]; then
        print_red "未找到容器: $container"
        return
    fi

    # 配置三个端口
    echo ""
    print_cyan "$(msg 'debug_port_prompt')"
    local port_a port_b port_c
    port_a=$(read_input "$(msg 'debug_port_jump')" "5005")
    port_b=$(read_input "$(msg 'debug_port_node')" "5006")
    port_c=$(read_input "$(msg 'debug_port_container')" "5007")

    # 检测JDK版本
    print_cyan "$(msg 'debug_detect_jdk')"
    local java_ver_output
    java_ver_output=$(ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" \
        "docker exec $container_id java -version 2>&1" || true)

    local jdk_version="8"
    if echo "$java_ver_output" | grep -q "21\."; then
        jdk_version="21"
        print_green "$(msg 'debug_jdk21')"
    else
        print_green "$(msg 'debug_jdk8')"
    fi

    # 生成Debug JVM参数
    local debug_param
    if [[ "$jdk_version" == "21" ]]; then
        debug_param="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:${port_c}"
    else
        debug_param="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=${port_c}"
    fi

    # 防重复检查
    local existing_param
    existing_param=$(ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" \
        "docker exec $container_id grep -o 'agentlib:jdwp[^ ]*' /app/start.sh 2>/dev/null" || true)

    if [[ -n "$existing_param" ]]; then
        local existing_port
        existing_port=$(echo "$existing_param" | sed -n 's/.*address=\([0-9]*\).*/\1/p' | head -1)
        if [[ -z "$existing_port" ]]; then
            existing_port=$(echo "$existing_param" | sed -n 's/.*address=\*:\([0-9]*\).*/\1/p' | head -1)
        fi

        print_yellow "$(msg 'debug_exists')"
        echo "  $existing_param"
        echo ""
        echo "  [1] $(msg 'debug_use_existing') ($existing_port)"
        echo "  [2] $(msg 'debug_replace_param') ($port_c)"
        echo "  [0] $(msg 'debug_cancel')"
        echo ""
        dup_choice=$(read_input "$(msg 'select_prompt')")

        case "$dup_choice" in
            1)
                port_c="$existing_port"
                ;;
            2)
                local addr_prefix=""
                [[ "$jdk_version" == "21" ]] && addr_prefix="*:"
                ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" \
                    "docker exec $container_id sed -i 's/agentlib:jdwp[^ ]*/agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=${addr_prefix}${port_c}/' /app/start.sh"
                ;;
            0|*)
                return
                ;;
        esac
    else
        ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" \
            "docker exec $container_id sed -i '/^java /s/$/ ${debug_param}/' /app/start.sh"
    fi

    # 禁用健康检查
    print_cyan "$(msg 'debug_disabling_hc')"
    local hc_scripts
    hc_scripts=$(config_get_hc_scripts)
    for hc_script in $hc_scripts; do
        ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" \
            "docker exec $container_id bash -c 'if [ -f /app/${hc_script} ]; then sed -i \"1i exit 0\" /app/${hc_script}; fi'" 2>/dev/null || true
    done

    # 重启容器使参数生效
    ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" "docker restart $container_id"
    sleep 3

    # 建立端口映射
    print_cyan "$(msg 'debug_port_forward')"

    # 第一级: 容器端口 -> 节点端口 (socat, x86/arm通用)
    ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" \
        "nohup socat TCP-LISTEN:${port_b},fork,reuseaddr TCP:localhost:${port_c} > /dev/null 2>&1 & echo \$! > /tmp/devtools_socat_${port_b}.pid"

    # 第二级: 节点端口 -> 跳板机端口 (SSH端口转发)
    local ssh_pid
    ssh_pid=$(ssh_port_forward "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" "$port_a" "$port_b")

    # 保存状态用于清理
    local jump_ip
    jump_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
    cat > "$DEBUG_STATE_FILE" << STATE_EOF
NODE_IP=$ip
CONTAINER_ID=$container_id
PORT_A=$port_a
PORT_B=$port_b
PORT_C=$port_c
SSH_PID=$ssh_pid
HC_SCRIPTS=$hc_scripts
STATE_EOF

    # 输出连接信息
    echo ""
    print_green "$(msg 'debug_ready')"
    echo "  跳板机IP: $jump_ip"
    echo "  跳板机端口: $port_a"
    print_cyan "$(msg 'debug_idea_hint')"
    echo ""
    print_yellow "按 Enter 退出Debug模式并清理配置..."
    read -r

    _debug_cleanup
}

_debug_cleanup() {
    if [[ ! -f "$DEBUG_STATE_FILE" ]]; then
        return
    fi

    source "$DEBUG_STATE_FILE"
    print_cyan "$(msg 'debug_cleanup')"

    if [[ -n "$SSH_PID" ]]; then
        kill "$SSH_PID" 2>/dev/null || true
    fi

    ssh_exec "$SSH_USER_PAAS" "$NODE_IP" "$SSH_PASS_PAAS" \
        "kill \$(cat /tmp/devtools_socat_${PORT_B}.pid 2>/dev/null) 2>/dev/null; rm -f /tmp/devtools_socat_${PORT_B}.pid" 2>/dev/null || true

    for hc_script in $HC_SCRIPTS; do
        ssh_exec "$SSH_USER_PAAS" "$NODE_IP" "$SSH_PASS_PAAS" \
            "docker exec $CONTAINER_ID bash -c 'if [ -f /app/${hc_script} ]; then sed -i \"1d\" /app/${hc_script}; fi'" 2>/dev/null || true
    done

    ssh_exec "$SSH_USER_PAAS" "$NODE_IP" "$SSH_PASS_PAAS" \
        "docker exec $CONTAINER_ID sed -i 's/ -agentlib:jdwp[^ ]*//' /app/start.sh" 2>/dev/null || true

    ssh_exec "$SSH_USER_PAAS" "$NODE_IP" "$SSH_PASS_PAAS" "docker restart $CONTAINER_ID"

    rm -f "$DEBUG_STATE_FILE"
    print_green "$(msg 'debug_restored')"
}
