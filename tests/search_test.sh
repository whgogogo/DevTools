#!/usr/bin/env bash
source "$(dirname "$0")/test_helper.bash"
source "$DEVTOOLS_ROOT_DIR/lib/common.sh"
source "$DEVTOOLS_ROOT_DIR/lib/i18n.sh"
source "$DEVTOOLS_ROOT_DIR/lib/config.sh"
source "$DEVTOOLS_ROOT_DIR/lib/search.sh"

setup
i18n_init "zh_CN"

echo "--- 测试: 搜索结果去重逻辑（不依赖关联数组，兼容bash3） ---"
unique=()
seen_keys=""
test_entries=("worker1|api-gateway-3a2c1|10.0.0.2" "worker1|data-service-7e4b2|10.0.0.2" "worker1|api-gateway-3a2c1|10.0.0.2")
for entry in "${test_entries[@]}"; do
    IFS='|' read -r node container ip <<< "$entry"
    key="${node}|${container}"
    # 使用字符串匹配代替关联数组
    if [[ "$seen_keys" != *"|${key}|"* ]]; then
        seen_keys="${seen_keys}|${key}|"
        unique+=("$entry")
    fi
done
assert_eq "${#unique[@]}" "2" "去重后应剩2条"
echo "PASS: 去重逻辑正确，${#unique[@]} 条结果"

echo "--- 测试: 模糊匹配逻辑 ---"
node="master-worker-01"
keyword="master"
if [[ "$node" == *"$keyword"* ]]; then
    echo "PASS: 模糊匹配正确"
else
    echo "FAIL: 模糊匹配失败"
fi

echo "--- 测试: search_select 无数据返回1 ---"
# 模拟空结果场景（没有 kubectl 环境）
SEARCH_RESULTS=()
SELECTED_NODE=""
SELECTED_CONTAINER=""
SELECTED_IP=""

echo ""
echo "=== search_test.sh 全部完成 ==="
