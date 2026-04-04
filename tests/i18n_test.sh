#!/usr/bin/env bash
source "$(dirname "$0")/test_helper.bash"
source "$DEVTOOLS_ROOT_DIR/lib/common.sh"
source "$DEVTOOLS_ROOT_DIR/lib/i18n.sh"

setup

echo "--- 测试: 中文默认语言 ---"
i18n_init "zh_CN"
result=$(msg "menu_search")
assert_eq "$result" "搜索节点/容器并跳转" "中文菜单搜索"
echo "PASS: 中文输出正确"

echo "--- 测试: 英文语言 ---"
i18n_init "en_US"
result=$(msg "menu_search")
assert_eq "$result" "Search Nodes/Containers" "英文菜单搜索"
echo "PASS: 英文输出正确"

echo "--- 测试: 不存在的key返回key本身 ---"
i18n_init "zh_CN"
result=$(msg "nonexistent_key_xyz")
assert_eq "$result" "nonexistent_key_xyz" "不存在的key"
echo "PASS: 不存在的key返回原值"

echo "--- 测试: 默认语言 ---"
i18n_init ""
result=$(msg "menu_quit")
assert_eq "$result" "退出" "默认中文退出"
echo "PASS: 默认语言为中文"

echo ""
echo "=== i18n_test.sh 全部完成 ==="
