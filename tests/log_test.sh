#!/usr/bin/env bash
source "$(dirname "$0")/test_helper.bash"
source "$DEVTOOLS_ROOT_DIR/lib/common.sh"

setup

# 覆盖 CONFIG_FILE 指向临时目录
CONFIG_FILE="$TEST_TMPDIR/test_config"
export CONFIG_FILE

source "$DEVTOOLS_ROOT_DIR/lib/config.sh"

echo "--- 测试: 日志路径配置 ---"
cat > "$CONFIG_FILE" << 'EOF'
DAC_SPARK_LOG_PATH=/var/log/dac/spark.log
EOF
config_load
assert_eq "$DAC_SPARK_LOG_PATH" "/var/log/dac/spark.log" "日志路径加载"
echo "PASS: 日志路径正确"

echo ""
echo "=== log_test.sh 全部完成 ==="
