#!/usr/bin/env bash
# install.sh - 一键安装脚本
# 在跳板机上执行，自动分发到集群所有节点

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="/opt/devtools"
CONFIG_DIR="${HOME}/.devtools"
CONFIG_FILE="${CONFIG_DIR}/config"

echo ""
echo "=========================================="
echo "  DevTools 一键安装"
echo "=========================================="
echo ""

# kubectl 路径（跳板机上可能不在默认 PATH 中）
KUBECTL_CMD="${KUBECTL_CMD:-$(command -v kubectl 2>/dev/null || echo '/opt/kubectl')}"
if [[ ! -x "$KUBECTL_CMD" ]]; then
    echo "错误: 找不到 kubectl，请设置 KUBECTL_CMD 环境变量"
    exit 1
fi

# 检查依赖
for cmd in expect ssh scp; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "错误: 缺少依赖 $cmd，请先安装"
        exit 1
    fi
done

# expect SSH/SCP 封装函数（与 lib/common.sh 保持一致）
expect_ssh_exec() {
    local user="$1" host="$2" password="$3"
    shift 3
    expect -c "
        set timeout 30
        spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${user}@${host} $@
        expect {
            \"*assword*\" { send \"${password}\r\"; exp_continue }
            eof
        }
    " 2>/dev/null
}

expect_scp() {
    local user="$1" password="$2" src="$3" dst="$4"
    expect -c "
        set timeout 60
        spawn scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${src} ${user}@${dst}
        expect {
            \"*assword*\" { send \"${password}\r\"; exp_continue }
            eof
        }
    " 2>/dev/null
}

# 检测架构
arch=$(uname -m)
echo "系统架构: $arch"

# 获取集群节点列表
echo "正在获取集群节点列表..."
node_lines=$("$KUBECTL_CMD" get nodes -o custom-columns=NAME:.metadata.name,IP:.status.addresses[0].address --no-headers 2>/dev/null)
if [[ -z "$node_lines" ]]; then
    echo "错误: 无法获取节点列表，请检查 kubectl 配置"
    exit 1
fi

node_ips=()
while IFS= read -r line; do
    ip=$(echo "$line" | awk '{print $2}')
    [[ -n "$ip" ]] && node_ips+=("$ip")
done <<< "$node_lines"

echo "发现 ${#node_ips[@]} 个节点: ${node_ips[*]}"
echo ""

read -rp "请输入 paas 用户密码: " -s paas_pass
echo ""
read -rp "请输入 root 用户密码: " -s root_pass
echo ""

# 安装到本机
echo "正在安装到本机..."
sudo mkdir -p "$INSTALL_DIR"
sudo cp -r "${SCRIPT_DIR}/bin" "${SCRIPT_DIR}/lib" "${SCRIPT_DIR}/conf" "$INSTALL_DIR/"
sudo chmod +x "${INSTALL_DIR}/bin/devtools"
sudo ln -sf "${INSTALL_DIR}/bin/devtools" /usr/local/bin/devtools
echo "本机安装完成"

# 分发到各节点
echo ""
echo "正在分发到集群节点..."
for ip in "${node_ips[@]}"; do
    echo "  -> $ip ..."
    expect_ssh_exec "root" "$ip" "$root_pass" "mkdir -p ${INSTALL_DIR}"

    expect_scp "root" "$root_pass" "${SCRIPT_DIR}/bin" "root@${ip}:${INSTALL_DIR}/"
    expect_scp "root" "$root_pass" "${SCRIPT_DIR}/lib" "root@${ip}:${INSTALL_DIR}/"
    expect_scp "root" "$root_pass" "${SCRIPT_DIR}/conf" "root@${ip}:${INSTALL_DIR}/"

    expect_ssh_exec "root" "$ip" "$root_pass" "chmod +x ${INSTALL_DIR}/bin/devtools && ln -sf ${INSTALL_DIR}/bin/devtools /usr/local/bin/devtools"

    echo "  $ip 安装完成"
done

# 生成配置文件
echo ""
echo "正在生成配置文件..."
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_FILE" ]]; then
    cp "${SCRIPT_DIR}/conf/config.template" "$CONFIG_FILE"
    sed -i.bak "s/SSH_PASS_PAAS=your_paas_password/SSH_PASS_PAAS=${paas_pass}/" "$CONFIG_FILE"
    sed -i.bak "s/SSH_PASS_ROOT=your_root_password/SSH_PASS_ROOT=${root_pass}/" "$CONFIG_FILE"
    rm -f "${CONFIG_FILE}.bak"
    chmod 600 "$CONFIG_FILE"
    echo "配置文件已生成: $CONFIG_FILE"
else
    echo "配置文件已存在，跳过: $CONFIG_FILE"
fi

echo ""
echo "=========================================="
echo "  安装完成！"
echo "  安装路径: $INSTALL_DIR"
echo "  配置文件: $CONFIG_FILE"
echo "  执行 'devtools' 启动工具"
echo "=========================================="
echo ""
