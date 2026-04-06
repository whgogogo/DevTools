#!/usr/bin/env bash
# make_package.sh - 一键打包发布脚本
# 生成 devtools-<版本号>.tar.gz，仅包含部署所需文件

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="1.0.0"
PKG_NAME="devtools-${VERSION}"
DIST_DIR="${SCRIPT_DIR}/dist"

echo ""
echo "=========================================="
echo "  DevTools 打包工具 v${VERSION}"
echo "=========================================="
echo ""

# 清理旧包
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# 创建打包目录
PKG_DIR="${DIST_DIR}/${PKG_NAME}"
mkdir -p "$PKG_DIR"

# 复制部署所需文件（排除开发产物）
echo "正在打包..."
cp -r "${SCRIPT_DIR}/bin" "$PKG_DIR/"
cp -r "${SCRIPT_DIR}/lib" "$PKG_DIR/"
cp -r "${SCRIPT_DIR}/conf" "$PKG_DIR/"
cp "${SCRIPT_DIR}/install.sh" "$PKG_DIR/"
cp "${SCRIPT_DIR}/uninstall.sh" "$PKG_DIR/"

# 设置权限
chmod +x "${PKG_DIR}/install.sh" "${PKG_DIR}/uninstall.sh"
chmod +x "${PKG_DIR}/bin/devtools"

# 打包
cd "$DIST_DIR"
tar czf "${PKG_NAME}.tar.gz" "${PKG_NAME}/"

# 输出结果
PKG_SIZE=$(du -sh "${PKG_NAME}.tar.gz" | awk '{print $1}')
echo ""
echo "=========================================="
echo "  打包完成！"
echo "=========================================="
echo ""
echo "  文件: dist/${PKG_NAME}.tar.gz"
echo "  大小: ${PKG_SIZE}"
echo ""
echo "  使用方法:"
echo "  1. 上传到跳板机:"
echo "     scp dist/${PKG_NAME}.tar.gz <跳板机>:/home/paas/"
echo ""
echo "  2. 在跳板机上执行:"
echo "     cd /home/paas"
echo "     tar xzf ${PKG_NAME}.tar.gz"
echo "     cd ${PKG_NAME}"
echo "     bash install.sh"
echo ""
