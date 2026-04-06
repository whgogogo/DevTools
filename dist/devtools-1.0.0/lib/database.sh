#!/usr/bin/env bash
# database.sh - 功能4：数据库连接
# 从配置文件动态读取数据库类型，搜索定位节点，执行连接命令

do_database() {
    echo ""

    local sections
    sections=$(config_get_db_sections)

    if [[ -z "$sections" ]]; then
        print_red "未在配置文件中找到数据库配置"
        return
    fi

    local section_arr=()
    local idx=1
    while IFS= read -r section; do
        [[ -z "$section" ]] && continue
        section_arr+=("$section")
        print_menu_item "$idx" "$section"
        ((idx++))
    done <<< "$sections"

    echo ""
    print_yellow "$(msg 'back_to_menu')"
    choice=$(read_input "$(msg 'db_select')")
    [[ "$choice" == "0" || -z "$choice" ]] && return

    if [[ ! "$choice" =~ ^[0-9]+$ || "$choice" -lt 1 || "$choice" -gt ${#section_arr[@]} ]]; then
        print_red "无效选择"
        return
    fi

    local selected_section="${section_arr[$((choice-1))]}"

    local keyword
    keyword=$(config_get_section "$selected_section" "KEYWORD")
    if [[ -z "$keyword" ]]; then
        print_red "未找到 $selected_section 的 KEYWORD 配置"
        return
    fi

    local connect_cmd
    connect_cmd=$(config_get_section "$selected_section" "CONNECT_CMD")
    if [[ -z "$connect_cmd" ]]; then
        print_red "未找到 $selected_section 的 CONNECT_CMD 配置"
        return
    fi

    print_cyan "$(msg 'db_connecting')"
    if ! search_select "$keyword" --allow-empty; then
        print_red "未找到匹配的节点/容器"
        return
    fi

    local ip="$SELECTED_IP"

    print_green "正在连接 $selected_section @ $ip ..."
    echo ""
    ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" "$connect_cmd"
}
