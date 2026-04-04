#!/usr/bin/env bash
# log.sh - 功能5：查询DAC Spark日志

do_log() {
    echo ""

    print_cyan "$(msg 'log_searching')"
    if ! search_select "dac" --allow-empty; then
        print_red "未找到DAC节点"
        return
    fi

    local ip="$SELECTED_IP"
    local log_path="${DAC_SPARK_LOG_PATH:-/var/log/dac/spark.log}"

    echo ""
    print_menu_item "1" "$(msg 'log_mode_follow')"
    print_menu_item "2" "$(msg 'log_mode_recent')"
    choice=$(read_input "$(msg 'log_mode_prompt')")
    [[ -z "$choice" ]] && return

    case "$choice" in
        1)
            filter=$(read_input "$(msg 'log_filter_prompt')")
            if [[ -n "$filter" ]]; then
                ssh_login "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" \
                    -t "tail -f $log_path | grep --color=always '$filter'"
            else
                ssh_login "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" \
                    -t "tail -f $log_path"
            fi
            ;;
        2)
            filter=$(read_input "$(msg 'log_filter_prompt')")
            if [[ -n "$filter" ]]; then
                ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" \
                    "tail -n 500 $log_path | grep --color=always '$filter'"
            else
                ssh_exec "$SSH_USER_PAAS" "$ip" "$SSH_PASS_PAAS" \
                    "tail -n 500 $log_path"
            fi
            ;;
    esac
}
