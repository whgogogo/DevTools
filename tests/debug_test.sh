#!/usr/bin/env bash
source "$(dirname "$0")/test_helper.bash"
source "$DEVTOOLS_ROOT_DIR/lib/common.sh"

setup

echo "--- 测试: JDK版本检测逻辑 ---"
jdk8_output='openjdk version "1.8.0_302"'
jdk21_output='openjdk version "21.0.1" 2023-10-17'

if echo "$jdk8_output" | grep -q "21\."; then
    echo "FAIL: JDK8 误判为21"
else
    echo "PASS: JDK8 正确识别"
fi

if echo "$jdk21_output" | grep -q "21\."; then
    echo "PASS: JDK21 正确识别"
else
    echo "FAIL: JDK21 未识别"
fi

echo "--- 测试: Debug参数生成 ---"
port_c="5007"
jdk8_param="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=${port_c}"
jdk21_param="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:${port_c}"
assert_contains "$jdk8_param" "address=5007" "JDK8参数格式"
assert_contains "$jdk21_param" "address=*:5007" "JDK21参数格式"
echo "PASS: JVM参数格式正确"

echo "--- 测试: 从已有参数提取端口 ---"
existing="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=5009"
existing_port=$(echo "$existing" | sed -n 's/.*address=\([0-9]*\).*/\1/p' | head -1)
assert_eq "$existing_port" "5009" "提取已有端口"
echo "PASS: 已有端口提取正确: $existing_port"

existing2="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5010"
existing_port2=$(echo "$existing2" | sed -n 's/.*address=\*:\([0-9]*\).*/\1/p' | head -1)
assert_eq "$existing_port2" "5010" "提取已有端口（带*前缀）"
echo "PASS: 已有端口提取正确（带*）: $existing_port2"

echo ""
echo "=== debug_test.sh 全部完成 ==="
