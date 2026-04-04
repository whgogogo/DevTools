#!/usr/bin/env bash
source "$(dirname "$0")/test_helper.bash"
source "$DEVTOOLS_ROOT_DIR/lib/common.sh"

setup

# 覆盖 CONFIG_FILE 指向临时目录（注意不能与 test_helper 创建的 config 目录同名）
CONFIG_FILE="$TEST_TMPDIR/test_config"
export CONFIG_FILE

source "$DEVTOOLS_ROOT_DIR/lib/config.sh"

# 创建测试配置文件
cat > "$CONFIG_FILE" << 'CONFIG_EOF'
LANG=zh_CN
SSH_USER_PAAS=paas
SSH_PASS_PAAS=test123
HEALTH_CHECK_SCRIPTS=health_check.sh,check_health.sh
DAC_SPARK_LOG_PATH=/var/log/dac/spark.log

[gaussv1]
KEYWORD=gaussdb-v1
CONNECT_CMD<<EOF
source /home/paas/gauss_env.sh
gsql -d mydb -p 5432
EOF

[gaussv3]
KEYWORD=gaussdb-v3
CONNECT_CMD=gsql -d mydb -p 5432

[carbon]
KEYWORD=carbon
CONNECT_CMD<<EOF
export JAVA_HOME=/opt/java
beeline -u "jdbc:hive2://localhost:10000/mydb"
EOF
CONFIG_EOF

echo "--- 测试: config_load ---"
config_load
assert_eq "$SSH_USER_PAAS" "paas" "加载SSH用户"
assert_eq "$SSH_PASS_PAAS" "test123" "加载SSH密码"
echo "PASS: config_load 正确加载全局变量"

echo "--- 测试: config_get ---"
result=$(config_get "LANG")
assert_eq "$result" "zh_CN" "获取LANG"
echo "PASS: config_get 正确获取值"

echo "--- 测试: config_get_section 单行值 ---"
result=$(config_get_section "gaussv3" "KEYWORD")
assert_eq "$result" "gaussdb-v3" "获取section单行值"
echo "PASS: section单行值正确"

echo "--- 测试: config_get_section 多行命令 ---"
result=$(config_get_section "gaussv1" "CONNECT_CMD")
assert_contains "$result" "source /home/paas/gauss_env.sh" "多行命令第一行"
assert_contains "$result" "gsql -d mydb -p 5432" "多行命令第二行"
echo "PASS: section多行命令正确"

echo "--- 测试: config_get_db_sections ---"
sections=$(config_get_db_sections)
assert_contains "$sections" "gaussv1" "数据库section列表"
assert_contains "$sections" "carbon" "数据库section列表包含carbon"
echo "PASS: 数据库section列表正确: $sections"

echo "--- 测试: config_get_hc_scripts ---"
scripts=$(config_get_hc_scripts)
assert_contains "$scripts" "health_check.sh" "健康检查脚本列表"
assert_contains "$scripts" "check_health.sh" "健康检查脚本列表"
echo "PASS: 健康检查脚本列表正确: $scripts"

echo "--- 测试: config_set ---"
config_set "LANG" "en_US"
result=$(grep "^LANG=" "$CONFIG_FILE")
assert_eq "$result" "LANG=en_US" "修改配置值"
echo "PASS: config_set 正确修改"

echo ""
echo "=== config_test.sh 全部完成 ==="
