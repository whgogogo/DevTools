#!/usr/bin/env bash
# common.sh 单元测试

source "$(dirname "$0")/test_helper.bash"
source "$DEVTOOLS_ROOT_DIR/lib/common.sh"

setup

# --- 颜色函数测试 ---
echo "--- 测试: detect_arch ---"
arch=$(detect_arch)
if [[ "$arch" == "x86" || "$arch" == "arm" ]]; then
    echo "PASS: detect_arch 返回 $arch"
else
    echo "FAIL: detect_arch 返回未知值 $arch"
fi

# --- gen_timestamp 测试 ---
echo "--- 测试: gen_timestamp ---"
ts=$(gen_timestamp)
if [[ "$ts" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
    echo "PASS: gen_timestamp 格式正确 $ts"
else
    echo "FAIL: gen_timestamp 格式错误 $ts"
fi

# --- format_size 测试 ---
echo "--- 测试: format_size ---"
result=$(format_size 1073741824)
assert_contains "$result" "GB" "1GB格式化"
echo "PASS: format_size 1GB -> $result"

result=$(format_size 1048576)
assert_contains "$result" "MB" "1MB格式化"
echo "PASS: format_size 1MB -> $result"

result=$(format_size 1024)
assert_contains "$result" "KB" "1KB格式化"
echo "PASS: format_size 1KB -> $result"

echo ""
echo "=== common_test.sh 全部完成 ==="
