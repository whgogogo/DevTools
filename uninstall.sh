#!/usr/bin/env bash
# uninstall.sh - 卸载脚本

set -euo pipefail

INSTALL_DIR="/opt/devtools"
CONFIG_DIR="${HOME}/.devtools"

echo ""
echo "=========================================="
echo "  DevTools 卸载"
echo "=========================================="
echo ""

echo "正在获取集群节点列表..."
node_ips=()
while IFS= read -r ip; do
    [[ -n "$ip" ]] && node_ips+=("$ip")
done < <(kubectl get nodes -o custom-columns=IP:.status.addresses[0].address --no-headers 2>/dev/null)

if [[ ${#node_ips[@]} -eq 0 ]]; then
    echo "警告: 无法获取节点列表"
    echo "将仅清理本机"
fi

read -rp "请输入 root 用户密码: " -s root_pass
echo ""

for ip in "${node_ips[@]}"; do
    echo "  -> 卸载 $ip ..."
    sshpass -p "$root_pass" ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "root@${ip}" "rm -rf ${INSTALL_DIR} && rm -f /usr/local/bin/devtools" 2>/dev/null
    echo "  $ip 卸载完成"
done

echo "正在卸载本机..."
sudo rm -rf "$INSTALL_DIR"
sudo rm -f /usr/local/bin/devtools
echo "本机卸载完成"

echo ""
read -rp "是否删除配置文件 ${CONFIG_DIR}？(y/n) [默认: n]: " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    rm -rf "$CONFIG_DIR"
    echo "配置文件已删除"
else
    echo "配置文件已保留: $CONFIG_DIR"
fi

echo ""
echo "卸载完成！"
echo ""
