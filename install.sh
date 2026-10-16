#!/usr/bin/env bash
# ==============================================================================
# Antigravity Login Scripts - 一键安装/修复软链接脚本
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BIN_DIR="$HOME/.local/bin"

mkdir -p "$TARGET_BIN_DIR"

echo "==> 赋予执行权限..."
chmod +x "$SCRIPT_DIR/agy-google.sh" "$SCRIPT_DIR/agy-ap.sh" "$SCRIPT_DIR/agy-api.sh"

echo "==> 创建/更新软链接至 $TARGET_BIN_DIR ..."
ln -sf "$SCRIPT_DIR/agy-google.sh" "$TARGET_BIN_DIR/agy-google"
ln -sf "$SCRIPT_DIR/agy-ap.sh" "$TARGET_BIN_DIR/agy-ap"
ln -sf "$SCRIPT_DIR/agy-api.sh" "$TARGET_BIN_DIR/agy-api"

echo "==> 软链接创建成功："
ls -l "$TARGET_BIN_DIR"/agy-*

echo -e "\n[完成] 现在你可以在终端任何位置直接运行："
echo "  - agy-google  (Google 个人账户)"
echo "  - agy-ap      (Agent Platform / GCP 认证)"
echo "  - agy-api     (Gemini API Key 认证)"
