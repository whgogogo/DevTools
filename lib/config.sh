#!/usr/bin/env bash
# config.sh - 配置管理模块
# 负责读写 ~/.devtools/config 配置文件

CONFIG_FILE="${CONFIG_FILE:-${HOME}/.devtools/config}"

# ============================================================
# 配置加载
# ============================================================

# 加载配置文件（仅全局变量部分，不含 section）
# 用法: config_load
config_load() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        return 1
    fi
    # 读取非 section 部分（非 [xxx] 开头，非 CONNECT_CMD<<EOF 块）
    local in_heredoc=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        # 跳过空行和注释
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # 检测 heredoc 开始（使用通配匹配避免 << 的正则解析问题）
        if [[ "$line" == *"<<EOF" ]]; then
            in_heredoc=1
            continue
        fi
        # 检测 heredoc 结束
        if [[ "$in_heredoc" -eq 1 && "$line" == "EOF" ]]; then
            in_heredoc=0
            continue
        fi
        if [[ "$in_heredoc" -eq 1 ]]; then
            continue
        fi
        # 跳过 section 标题
        [[ "$line" =~ ^\[ ]] && continue
        # 解析 KEY=VALUE
        if [[ "$line" =~ ^([A-Z_]+)=(.*) ]]; then
            local key="${BASH_REMATCH[1]}"
            local val="${BASH_REMATCH[2]}"
            # 去除前后空白
            val=$(echo "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            export "$key=$val"
        fi
    done < "$CONFIG_FILE"
    return 0
}

# ============================================================
# 配置读取
# ============================================================

# 获取全局配置值
# 用法: config_get "KEY"
config_get() {
    local key="$1"
    echo "${!key}"
}

# 获取数据库 section 中的值
# 用法: config_get_section <section> <key>
config_get_section() {
    local section="$1" key="$2"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        return 1
    fi
    local in_section=0 in_heredoc=0
    local heredoc_key=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        # 处理 heredoc 结束
        if [[ "$in_heredoc" -eq 1 && "$line" == "EOF" ]]; then
            in_heredoc=0
            heredoc_key=""
            continue
        fi
        if [[ "$in_heredoc" -eq 1 ]]; then
            continue
        fi
        # 检测 heredoc 开始（在 section 内，使用通配匹配避免 << 的正则解析问题）
        if [[ "$in_section" -eq 1 && "$line" == *"<<EOF" ]]; then
            heredoc_key=$(echo "$line" | sed 's/<<EOF$//' | sed 's/^[[:space:]]*//')
            if [[ "$heredoc_key" == "$key" ]]; then
                # 读取多行命令直到 EOF
                local cmd_lines=()
                while IFS= read -r cmd_line && [[ "$cmd_line" != "EOF" ]]; do
                    cmd_lines+=("$cmd_line")
                done
                printf '%s\n' "${cmd_lines[@]}"
                return 0
            fi
            in_heredoc=1
            continue
        fi
        # 检测 section 开始
        if [[ "$line" == "[$section]" ]]; then
            in_section=1
            continue
        fi
        # 检测 section 结束
        if [[ "$in_section" -eq 1 && "$line" =~ ^\[ ]] && [[ "$line" != "[$section]" ]]; then
            break
        fi
        # 读取 section 内的 KEY=VALUE
        if [[ "$in_section" -eq 1 && "$line" =~ ^${key}=(.*) ]]; then
            echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            return 0
        fi
    done < "$CONFIG_FILE"
    return 1
}

# ============================================================
# 配置写入
# ============================================================

# 设置全局配置值
# 用法: config_set "KEY" "VALUE"
config_set() {
    local key="$1" value="$2"
    if [[ -f "$CONFIG_FILE" ]]; then
        if grep -q "^${key}=" "$CONFIG_FILE"; then
            sed -i.bak "s|^${key}=.*|${key}=${value}|" "$CONFIG_FILE"
            rm -f "${CONFIG_FILE}.bak"
        else
            echo "${key}=${value}" >> "$CONFIG_FILE"
        fi
    fi
}

# ============================================================
# 获取所有数据库 section 名称
# ============================================================

# 返回配置文件中所有 section 名称
config_get_db_sections() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        return 1
    fi
    grep '^\[' "$CONFIG_FILE" | tr -d '[]' | sort
}

# ============================================================
# 获取健康检查脚本列表（逗号分隔转数组）
# ============================================================

config_get_hc_scripts() {
    local scripts="${HEALTH_CHECK_SCRIPTS:-}"
    echo "${scripts//,/ }"
}
