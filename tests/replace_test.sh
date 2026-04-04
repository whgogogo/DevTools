#!/usr/bin/env bash
source "$(dirname "$0")/test_helper.bash"
source "$DEVTOOLS_ROOT_DIR/lib/common.sh"

setup

echo "--- 测试: jar包扫描逻辑 ---"
mkdir -p "$TEST_TMPDIR/paas/zhangsan" "$TEST_TMPDIR/paas/lisi"
touch "$TEST_TMPDIR/paas/app.jar"
touch "$TEST_TMPDIR/paas/zhangsan/gateway.jar"
touch "$TEST_TMPDIR/paas/lisi/service.jar"

result=$(find "$TEST_TMPDIR/paas" -maxdepth 2 -name "*.jar" -type f | sort)
count=$(echo "$result" | grep -c ".jar")
assert_eq "$count" "3" "应找到3个jar包"
echo "PASS: jar包扫描找到 $count 个文件"

echo "--- 测试: format_size ---"
result=$(format_size 52428800)
assert_contains "$result" "MB" "50MB文件"
echo "PASS: 50MB -> $result"

echo ""
echo "=== replace_test.sh 全部完成 ==="
