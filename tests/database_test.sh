#!/usr/bin/env bash
source "$(dirname "$0")/test_helper.bash"
source "$DEVTOOLS_ROOT_DIR/lib/common.sh"

setup

# 覆盖 CONFIG_FILE 指向临时目录（必须在 source config.sh 之前设置）
CONFIG_FILE="$TEST_TMPDIR/test_config"
export CONFIG_FILE

source "$DEVTOOLS_ROOT_DIR/lib/config.sh"

cat > "$CONFIG_FILE" << 'CONFIG_EOF'
LANG=zh_CN
SSH_USER_PAAS=paas
SSH_PASS_PAAS=test123

[gaussv1]
KEYWORD=gaussdb-v1
CONNECT_CMD<<EOF
source /home/paas/gauss_env.sh
gsql -d mydb -p 5432
EOF

[carbon]
KEYWORD=carbon
CONNECT_CMD=beeline -u "jdbc:hive2://localhost:10000/mydb"
CONFIG_EOF

echo "--- 测试: config_get_db_sections ---"
sections=$(config_get_db_sections)
assert_contains "$sections" "gaussv1" "数据库列表"
assert_contains "$sections" "carbon" "数据库列表"
echo "PASS: 数据库列表: $sections"

echo "--- 测试: 获取单行连接命令 ---"
result=$(config_get_section "carbon" "CONNECT_CMD")
assert_contains "$result" "beeline" "单行连接命令"
echo "PASS: 单行命令: $result"

echo "--- 测试: 获取多行连接命令 ---"
result=$(config_get_section "gaussv1" "CONNECT_CMD")
assert_contains "$result" "source" "多行命令第一行"
assert_contains "$result" "gsql" "多行命令第二行"
echo "PASS: 多行命令正确"

echo ""
echo "=== database_test.sh 全部完成 ==="
