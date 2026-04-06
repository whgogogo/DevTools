#!/usr/bin/env bash
# search.sh - 功能1：节点/容器搜索与跳转
# 核心能力模块，其他功能模块依赖此模块

# ============================================================
# 内部：构建搜索结果列表
# 结果存储在全局数组 SEARCH_RESULTS 中
# 格式: "节点名|容器名|节点IP"
# ============================================================

SEARCH_RESULTS=()

# 解析 kubectl 输出，构建搜索结果
_build_search_results() {
    SEARCH_RESULTS=()

    # 获取节点信息（名称|IP|状态）
    local nodes_raw
    nodes_raw=$(kubectl_get_nodes)
    # 获取 pod 信息（命名空间|Pod名|节点名|状态）
    local pods_raw
    pods_raw=$(kubectl_get_pods)

    # 构建节点IP查找表
    declare -A node_ip_map
    while IFS='|' read -r name ip status; do
        [[ -n "$name" && -n "$ip" ]] && node_ip_map["$name"]="$ip"
    done <<< "$nodes_raw"

    # 遍历 pod，构建搜索结果
    while IFS='|' read -r ns pod node status; do
        [[ -z "$pod" ]] && continue
        local node_ip="${node_ip_map[$node]:-$node}"
        SEARCH_RESULTS+=("${node}|${pod}|${node_ip}")
    done <<< "$pods_raw"
}

# ============================================================
# 搜索并展示结果
# 用法: do_search
# ============================================================

do_search() {
    while true; do
        keyword=$(read_input "$(msg 'search_keyword')")
        [[ -z "$keyword" ]] && return

        # 构建搜索结果
        _build_search_results

        # 过滤匹配结果
        local matched=()
        for entry in "${SEARCH_RESULTS[@]}"; do
            IFS='|' read -r node container ip <<< "$entry"
            if [[ "$node" == *"$keyword"* || "$container" == *"$keyword"* ]]; then
                matched+=("$entry")
            fi
        done

        # 去重（按 节点名+容器名 组合）
        local unique=()
        declare -A seen
        for entry in "${matched[@]}"; do
            IFS='|' read -r node container ip <<< "$entry"
            local key="${node}|${container}"
            if [[ -z "${seen[$key]}" ]]; then
                seen["$key"]=1
                unique+=("$entry")
            fi
        done

        # 结果为空
        if [[ ${#unique[@]} -eq 0 ]]; then
            print_yellow "$(msg 'search_empty')"
            continue
        fi

        # 展示结果
        echo ""
        printf "  %-4s  %-18s  %-30s  %-16s\n" "序号" "节点名称" "容器名称" "节点IP"
        printf "  %-4s  %-18s  %-30s  %-16s\n" "----" "──────────" "──────────────────────" "────────"
        local idx=1
        for entry in "${unique[@]}"; do
            IFS='|' read -r node container ip <<< "$entry"
            printf "  %-4s  %-18s  %-30s  %-16s\n" "$idx" "$node" "$container" "$ip"
            ((idx++))
        done
        echo ""
        print_yellow "$(msg 'search_back')"
        echo ""

        # 用户选择
        choice=$(read_input "$(msg 'select_prompt')")
        [[ "$choice" == "0" || -z "$choice" ]] && return

        if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le ${#unique[@]} ]]; then
            local selected="${unique[$((choice-1))]}"
            IFS='|' read -r node container ip <<< "$selected"
            print_green "正在跳转到 ${node} ..."
            ssh_login "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS"
        else
            print_red "无效选择"
        fi
    done
}

# ============================================================
# 供其他模块调用的搜索函数
# 设置全局变量: SELECTED_NODE, SELECTED_CONTAINER, SELECTED_IP
# 用法: search_select <keyword> [--allow-empty]
# 返回: 0=选中, 1=取消/空结果
# ============================================================

search_select() {
    local keyword="$1"
    local allow_empty=false
    [[ "${2:-}" == "--allow-empty" ]] && allow_empty=true

    _build_search_results

    local matched=()
    for entry in "${SEARCH_RESULTS[@]}"; do
        IFS='|' read -r node container ip <<< "$entry"
        if [[ "$node" == *"$keyword"* || "$container" == *"$keyword"* ]]; then
            matched+=("$entry")
        fi
    done

    # 去重
    local unique=()
    declare -A seen
    for entry in "${matched[@]}"; do
        IFS='|' read -r node container ip <<< "$entry"
        local key="${node}|${container}"
        if [[ -z "${seen[$key]}" ]]; then
            seen["$key"]=1
            unique+=("$entry")
        fi
    done

    if [[ ${#unique[@]} -eq 0 ]]; then
        $allow_empty && return 1
        print_yellow "$(msg 'search_empty')"
        return 1
    fi

    # 展示
    echo ""
    printf "  %-4s  %-18s  %-30s  %-16s\n" "序号" "节点名称" "容器名称" "节点IP"
    printf "  %-4s  %-18s  %-30s  %-16s\n" "----" "──────────" "──────────────────────" "────────"
    local idx=1
    for entry in "${unique[@]}"; do
        IFS='|' read -r node container ip <<< "$entry"
        printf "  %-4s  %-18s  %-30s  %-16s\n" "$idx" "$node" "$container" "$ip"
        ((idx++))
    done
    echo ""
    print_yellow "$(msg 'search_back')"

    choice=$(read_input "$(msg 'select_prompt')")
    [[ "$choice" == "0" || -z "$choice" ]] && return 1

    if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le ${#unique[@]} ]]; then
        local selected="${unique[$((choice-1))]}"
        IFS='|' read -r node container ip <<< "$selected"
        SELECTED_NODE="$node"
        SELECTED_CONTAINER="$container"
        SELECTED_IP="$ip"
        return 0
    fi
    return 1
}
