#!/usr/bin/env bash
# 测试辅助函数
# 用法: source tests/test_helper.bash

export DEVTOOLS_ROOT_DIR="${DEVTOOLS_ROOT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
export TEST_TMPDIR=""

setup() {
    TEST_TMPDIR=$(mktemp -d)
    export DEVTOOLS_CONFIG_DIR="$TEST_TMPDIR/config"
    export DEVTOOLS_HOME="$TEST_TMPDIR"
    mkdir -p "$DEVTOOLS_CONFIG_DIR"
}

teardown() {
    [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"
}

# 断言两个字符串相等
assert_eq() {
    local expected="$1" actual="$2" msg="${3:-assertion failed}"
    if [[ "$expected" != "$actual" ]]; then
        echo "FAIL: $msg"
        echo "  expected: '$expected'"
        echo "  actual:   '$actual'"
        return 1
    fi
}

# 断言字符串包含子串
assert_contains() {
    local haystack="$1" needle="$2" msg="${3:-assertion failed}"
    if [[ "$haystack" != *"$needle"* ]]; then
        echo "FAIL: $msg"
        echo "  haystack: '$haystack'"
        echo "  needle:   '$needle'"
        return 1
    fi
}

# 断言命令成功（退出码0）
assert_exit_code() {
    local expected="$1" actual="$2" msg="${3:-exit code mismatch}"
    if [[ "$expected" != "$actual" ]]; then
        echo "FAIL: $msg"
        echo "  expected exit code: $expected"
        echo "  actual exit code:   $actual"
        return 1
    fi
}

# 运行单个测试文件
run_test_file() {
    local file="$1"
    echo "=== Running: $file ==="
    source "$file"
    echo "=== Passed: $file ==="
}
