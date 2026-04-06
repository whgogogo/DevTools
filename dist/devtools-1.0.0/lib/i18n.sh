#!/usr/bin/env bash
# i18n.sh - 国际化模块
# 根据 ~/.devtools/config 中 LANG 配置返回中/英文字符串

# 当前语言（默认中文）
I18N_LANG="zh_CN"

# 加载语言设置（由 config.sh 调用）
i18n_init() {
    I18N_LANG="${1:-zh_CN}"
}

# ============================================================
# 消息获取函数
# ============================================================

# 获取国际化消息
# 用法: msg "key"
msg() {
    local key="$1"
    if [[ "$I18N_LANG" == "en_US" ]]; then
        case "$key" in
            app_title)          echo "DevTools v1.0" ;;
            menu_search)        echo "Search Nodes/Containers" ;;
            menu_replace)       echo "Replace Jar Package" ;;
            menu_debug)         echo "Enable Remote Debug" ;;
            menu_database)      echo "Connect to Database" ;;
            menu_log)           echo "View DAC Spark Log" ;;
            menu_config)        echo "Configuration" ;;
            menu_help)          echo "Help" ;;
            menu_quit)          echo "Quit" ;;
            select_prompt)      echo "Please select" ;;
            search_keyword)     echo "Enter search keyword (node name or container name)" ;;
            search_empty)       echo "No results found, please try again" ;;
            search_header)      echo "No.   Node Name          Container Name                Node IP" ;;
            search_back)        echo "(0 Back to main menu)" ;;
            replace_select_jar) echo "Select jar to replace" ;;
            replace_found_jars) echo "Found following jars in /home/paas:" ;;
            replace_backup)     echo "Backing up original jar..." ;;
            replace_com_dir)    echo "Detected com directory, renaming..." ;;
            replace_transfer)   echo "Transferring jar to node..." ;;
            replace_chown)      echo "Changing file ownership..." ;;
            replace_docker_cp)  echo "Replacing jar in container..." ;;
            replace_cleanup)    echo "Cleaning up temp files..." ;;
            replace_restart)    echo "Restarting container..." ;;
            replace_done)       echo "Jar replaced, container restarted" ;;
            debug_port_prompt)  echo "Configure Debug ports" ;;
            debug_port_jump)    echo "Jump server port" ;;
            debug_port_node)    echo "Node port" ;;
            debug_port_container) echo "Container port" ;;
            debug_detect_jdk)   echo "Detecting JDK version..." ;;
            debug_jdk8)         echo "Detected JDK8" ;;
            debug_jdk21)        echo "Detected JDK21" ;;
            debug_exists)       echo "Found existing debug params in start.sh:" ;;
            debug_use_existing) echo "Use existing port and continue" ;;
            debug_replace_param) echo "Replace with new debug params" ;;
            debug_cancel)       echo "Cancel" ;;
            debug_disabling_hc) echo "Disabling health check..." ;;
            debug_port_forward) echo "Setting up port forwarding..." ;;
            debug_ready)        echo "Remote Debug ready!" ;;
            debug_idea_hint)    echo "In IDEA: Run -> Edit Configurations -> Remote JVM Debug" ;;
            debug_cleanup)      echo "Cleaning up debug config..." ;;
            debug_restored)     echo "Debug config cleaned, container restarted" ;;
            db_select)          echo "Select database to connect" ;;
            db_connecting)      echo "Connecting to database..." ;;
            log_searching)      echo "Searching for DAC node..." ;;
            log_viewing)        echo "Viewing logs..." ;;
            log_filter_prompt)  echo "Enter filter keyword (Enter for all)" ;;
            log_mode_prompt)    echo "View mode" ;;
            log_mode_follow)    echo "Follow (real-time)" ;;
            log_mode_recent)    echo "Recent 500 lines" ;;
            config_select)      echo "Select config item" ;;
            config_view)        echo "View current config" ;;
            config_lang)        echo "Change language setting" ;;
            config_ssh)         echo "Change SSH credentials" ;;
            config_hc)          echo "Change health check scripts" ;;
            config_db)          echo "Change database keywords and commands" ;;
            config_log_path)    echo "Change log path" ;;
            help_search)        echo "[1] Search: Fuzzy search nodes/containers by keyword, SSH jump on select" ;;
            help_replace)       echo "[2] Replace: Scan local jars, replace into container and restart" ;;
            help_debug)         echo "[3] Debug: Auto-configure JVM params, disable health check, two-level port forward" ;;
            help_database)      echo "[4] Database: Select DB type, auto-jump and execute connect command" ;;
            help_log)           echo "[5] Log: Search DAC node and view spark.log" ;;
            help_config)        echo "[c] Config: Manage SSH credentials, DB commands, health check scripts" ;;
            operation_confirm)  echo "Confirm?" ;;
            success)            echo "Operation succeeded" ;;
            failed)             echo "Operation failed" ;;
            back_to_menu)       echo "(0 Back)" ;;
            *)                  echo "$key" ;;
        esac
    else
        case "$key" in
            app_title)          echo "DevTools v1.0" ;;
            menu_search)        echo "搜索节点/容器并跳转" ;;
            menu_replace)       echo "一键更换Jar包" ;;
            menu_debug)         echo "一键开启远程Debug" ;;
            menu_database)      echo "连接数据库" ;;
            menu_log)           echo "查询DAC Spark日志" ;;
            menu_config)        echo "配置管理" ;;
            menu_help)          echo "帮助" ;;
            menu_quit)          echo "退出" ;;
            select_prompt)      echo "请选择" ;;
            search_keyword)     echo "请输入搜索关键词（节点名或容器名）" ;;
            search_empty)       echo "未找到匹配结果，请重新输入" ;;
            search_header)      echo "序号  节点名称          容器名称                    节点IP" ;;
            search_back)        echo "(0 返回主菜单)" ;;
            replace_select_jar) echo "请选择要替换的jar包" ;;
            replace_found_jars) echo "在 /home/paas 下发现以下jar包：" ;;
            replace_backup)     echo "正在备份原jar包..." ;;
            replace_com_dir)    echo "检测到com目录，正在改名..." ;;
            replace_transfer)   echo "正在传输jar包到节点..." ;;
            replace_chown)      echo "正在修改文件属组..." ;;
            replace_docker_cp)  echo "正在替换容器内jar包..." ;;
            replace_cleanup)    echo "正在清理临时文件..." ;;
            replace_restart)    echo "正在重启容器..." ;;
            replace_done)       echo "Jar包替换完成，容器已重启" ;;
            debug_port_prompt)  echo "请配置Debug端口" ;;
            debug_port_jump)    echo "跳板机端口" ;;
            debug_port_node)    echo "节点端口" ;;
            debug_port_container) echo "容器内端口" ;;
            debug_detect_jdk)   echo "正在检测JDK版本..." ;;
            debug_jdk8)         echo "检测到 JDK8" ;;
            debug_jdk21)        echo "检测到 JDK21" ;;
            debug_exists)       echo "检测到start.sh中已有Debug参数:" ;;
            debug_use_existing) echo "使用已有端口继续后续操作" ;;
            debug_replace_param) echo "替换为新的Debug参数" ;;
            debug_cancel)       echo "取消操作" ;;
            debug_disabling_hc) echo "正在禁用健康检查..." ;;
            debug_port_forward) echo "正在建立端口映射..." ;;
            debug_ready)        echo "远程Debug已就绪！" ;;
            debug_idea_hint)    echo "请在IDEA中配置: Run -> Edit Configurations -> Remote JVM Debug" ;;
            debug_cleanup)      echo "正在清理Debug配置..." ;;
            debug_restored)     echo "Debug配置已清理，容器已重启" ;;
            db_select)          echo "请选择要连接的数据库" ;;
            db_connecting)      echo "正在连接数据库..." ;;
            log_searching)      echo "正在搜索DAC节点..." ;;
            log_viewing)        echo "正在查看日志..." ;;
            log_filter_prompt)  echo "请输入过滤关键词（直接回车查看全部）" ;;
            log_mode_prompt)    echo "查看模式" ;;
            log_mode_follow)    echo "实时跟踪(follow)" ;;
            log_mode_recent)    echo "最近500行" ;;
            config_select)      echo "请选择配置项" ;;
            config_view)        echo "查看当前配置" ;;
            config_lang)        echo "修改语言设置" ;;
            config_ssh)         echo "修改SSH凭据" ;;
            config_hc)          echo "修改健康检查脚本列表" ;;
            config_db)          echo "修改数据库关键词与连接命令" ;;
            config_log_path)    echo "修改日志路径" ;;
            help_search)        echo "[1] 搜索: 通过关键词模糊搜索节点/容器，选中后一键SSH跳转" ;;
            help_replace)       echo "[2] 替换: 扫描本地jar包，选择后一键替换到容器内并重启" ;;
            help_debug)         echo "[3] Debug: 自动配置JVM参数、禁用健康检查、建立两级端口转发" ;;
            help_database)      echo "[4] 数据库: 选择数据库类型后自动跳转并执行连接命令" ;;
            help_log)           echo "[5] 日志: 搜索DAC节点并查看spark.log日志" ;;
            help_config)        echo "[c] 配置: 管理SSH凭据、数据库连接命令、健康检查脚本等" ;;
            operation_confirm)  echo "确认执行？" ;;
            success)            echo "操作成功" ;;
            failed)             echo "操作失败" ;;
            back_to_menu)       echo "(0 返回)" ;;
            *)                  echo "$key" ;;
        esac
    fi
}
