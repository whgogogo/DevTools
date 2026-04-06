#!/usr/bin/env bash
# replace.sh - 功能2：一键更换Jar包

do_replace() {
    echo ""
    keyword=$(read_input "$(msg 'search_keyword')")
    [[ -z "$keyword" ]] && return

    # 搜索选择目标容器
    if ! search_select "$keyword"; then
        return
    fi

    local node="$SELECTED_NODE"
    local container="$SELECTED_CONTAINER"
    local ip="$SELECTED_IP"

    # 扫描 /home/paas 下的 jar 包
    print_cyan "$(msg 'replace_found_jars')"
    echo ""

    local jars=()
    local jar_sizes=()
    local jar_paths=()

    while IFS= read -r -d '' jar_file; do
        local rel_path="${jar_file#/home/paas/}"
        local size
        size=$(stat -c%s "$jar_file" 2>/dev/null || stat -f%z "$jar_file" 2>/dev/null)
        local human_size
        human_size=$(format_size "$size")
        jars+=("$rel_path")
        jar_sizes+=("$human_size")
        jar_paths+=("$jar_file")
    done < <(find /home/paas -maxdepth 2 -name "*.jar" -type f -print0 2>/dev/null | sort -z)

    if [[ ${#jars[@]} -eq 0 ]]; then
        print_red "在 /home/paas 下未找到任何jar包"
        return
    fi

    printf "  %-4s  %-45s  %-10s\n" "序号" "文件名" "大小"
    printf "  %-4s  %-45s  %-10s\n" "----" "─────────────────────────────────────────" "─────"
    local idx=1
    for i in "${!jars[@]}"; do
        printf "  %-4s  %-45s  %-10s\n" "$idx" "${jars[$i]}" "${jar_sizes[$i]}"
        ((idx++))
    done
    echo ""
    print_yellow "$(msg 'back_to_menu')"

    choice=$(read_input "$(msg 'replace_select_jar')")
    [[ "$choice" == "0" || -z "$choice" ]] && return

    if [[ ! "$choice" =~ ^[0-9]+$ || "$choice" -lt 1 || "$choice" -gt ${#jars[@]} ]]; then
        print_red "无效选择"
        return
    fi

    local selected_idx=$((choice-1))
    local jar_path="${jar_paths[$selected_idx]}"
    local jar_name
    jar_name=$(basename "$jar_path")

    if ! read_confirm "$(msg 'operation_confirm')"; then
        return
    fi

    # 获取容器ID
    local container_id
    container_id=$(ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" \
        "docker ps --format '{{.ID}} {{.Names}}' | grep '$container' | awk '{print \$1}' | head -1")

    if [[ -z "$container_id" ]]; then
        print_red "未找到容器: $container"
        return
    fi

    local timestamp
    timestamp=$(gen_timestamp)

    # Step 1: 备份容器内原jar包
    print_cyan "$(msg 'replace_backup')"
    ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" \
        "docker exec $container_id bash -c 'jar_files=\$(find / -maxdepth 4 -name \"*.jar\" -path \"*/app/*\" 2>/dev/null | head -1); if [ -n \"\$jar_files\" ]; then cp \$jar_files \${jar_files}.bak.$timestamp; fi'" 2>/dev/null || true

    # Step 2: 处理 com 目录
    print_cyan "$(msg 'replace_com_dir')"
    ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" \
        "docker exec $container_id bash -c 'com_dirs=\$(find / -maxdepth 4 -type d -name \"com\" -path \"*/app/*\" 2>/dev/null | head -1); if [ -n \"\$com_dirs\" ]; then mv \$com_dirs \${com_dirs}.bak.$timestamp; fi'" 2>/dev/null || true

    # Step 3: SCP传输到节点（paas用户，保持原始文件名）
    print_cyan "$(msg 'replace_transfer')"
    scp_transfer "$SSH_USER_PAAS" "$SSH_PASS_PAAS" "$jar_path" "${ip}:/home/paas/${jar_name}"

    # Step 4: 修改属组
    print_cyan "$(msg 'replace_chown')"
    ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" \
        "docker exec $container_id bash -c 'target_dir=\$(dirname \$(find / -maxdepth 4 -name \"*.jar\" -path \"*/app/*\" 2>/dev/null | head -1)); target_user=\$(stat -c \"%U\" \$target_dir 2>/dev/null || echo root); chown \$target_user:\$target_user /home/paas/${jar_name}'"

    # Step 5: docker cp 替换
    print_cyan "$(msg 'replace_docker_cp')"
    ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" \
        "target_path=\$(docker exec $container_id find / -maxdepth 4 -name \"*.jar\" -path \"*/app/*\" 2>/dev/null | head -1); docker cp /home/paas/${jar_name} $container_id:\$target_path"

    # Step 6: 清理临时文件
    print_cyan "$(msg 'replace_cleanup')"
    ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" "rm -f /home/paas/${jar_name}"

    # Step 7: 重启容器
    print_cyan "$(msg 'replace_restart')"
    ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" "docker restart $container_id"

    print_green "$(msg 'replace_done')"
}
