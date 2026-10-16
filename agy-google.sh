#!/usr/bin/env bash
# ==============================================================================
# agy-google: 启动 Antigravity CLI 并自动切换为 Google 账户 (OAuth) 认证
# 无论当前处于哪种认证模式，运行此脚本都会自动切为 Google 配置并启动 agy。
# ==============================================================================

set -e

AGY_DIR="$HOME/.gemini/antigravity-cli"
PROFILE_DIR="$AGY_DIR/profiles"
TOKEN_FILE="$AGY_DIR/antigravity-oauth-token"
SETTINGS_FILE="$AGY_DIR/settings.json"
ONBOARDING_FILE="$AGY_DIR/cache/onboarding.json"
KEYRING_MARKER="$AGY_DIR/cache/antigravity-keyring-unavailable"

# 1. 寻找真实 agy 二进制路径
AGY_BIN="$(command -v agy || true)"
if [ -z "$AGY_BIN" ]; then
    if [ -x "$HOME/.local/bin/agy" ]; then
        AGY_BIN="$HOME/.local/bin/agy"
    else
        echo -e "\033[31m[错误] 未找到 agy 命令！请确认 Antigravity CLI 已安装。\033[0m" >&2
        exit 1
    fi
fi

# 2. 初始化目录并跳过系统 Keyring（确保纯文件 Token 切换生效）
mkdir -p "$PROFILE_DIR/google" "$PROFILE_DIR/ap" "$AGY_DIR/cache"
touch "$KEYRING_MARKER"

get_current_auth() {
    if [ -f "$TOKEN_FILE" ]; then
        grep -o '"auth_method":[[:space:]]*"[^"]*"' "$TOKEN_FILE" 2>/dev/null | cut -d'"' -f4 || echo "unknown"
    else
        echo "none"
    fi
}

CURRENT_AUTH="$(get_current_auth)"

# 3. 如果当前处于 AP 模式 (gcp)，先将 AP 最新凭据备份回 profiles/ap
if [ "$CURRENT_AUTH" = "gcp" ]; then
    cp -pf "$TOKEN_FILE" "$PROFILE_DIR/ap/antigravity-oauth-token"
    [ -f "$SETTINGS_FILE" ] && cp -pf "$SETTINGS_FILE" "$PROFILE_DIR/ap/settings.json"
    [ -f "$ONBOARDING_FILE" ] && cp -pf "$ONBOARDING_FILE" "$PROFILE_DIR/ap/onboarding.json"
fi

# 4. 如果当前已经是 consumer 但 profiles/google 尚未记录，自动初始化备份
if [ "$CURRENT_AUTH" = "consumer" ] && [ ! -f "$PROFILE_DIR/google/antigravity-oauth-token" ]; then
    cp -pf "$TOKEN_FILE" "$PROFILE_DIR/google/antigravity-oauth-token"
    [ -f "$SETTINGS_FILE" ] && cp -pf "$SETTINGS_FILE" "$PROFILE_DIR/google/settings.json"
    [ -f "$ONBOARDING_FILE" ] && cp -pf "$ONBOARDING_FILE" "$PROFILE_DIR/google/onboarding.json"
fi

# 5. 如果当前不是 consumer，则恢复 Google 账户配置
if [ "$CURRENT_AUTH" != "consumer" ]; then
    if [ -f "$PROFILE_DIR/google/antigravity-oauth-token" ]; then
        cp -pf "$PROFILE_DIR/google/antigravity-oauth-token" "$TOKEN_FILE"
        [ -f "$PROFILE_DIR/google/settings.json" ] && cp -pf "$PROFILE_DIR/google/settings.json" "$SETTINGS_FILE"
        [ -f "$PROFILE_DIR/google/onboarding.json" ] && cp -pf "$PROFILE_DIR/google/onboarding.json" "$ONBOARDING_FILE"
        chmod 600 "$TOKEN_FILE"
    else
        rm -f "$TOKEN_FILE"
        # 移除 settings.json 中的 gcp 配置，避免干扰个人 Google 账户
        if [ -f "$SETTINGS_FILE" ]; then
            python3 -c "
import json
p = '$SETTINGS_FILE'
try:
    with open(p, 'r', encoding='utf-8') as f:
        data = json.load(f)
    if 'gcp' in data:
        del data['gcp']
        with open(p, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
except Exception:
    pass
"
        fi
        echo -e "\033[33m[提示] 尚未检测到 Google 账户登录凭据，首次启动请在 agy 界面中选择 Google 账户登录...\033[0m"
    fi
fi

# 6. 退出/中断时自动同步最新 Google 凭据（防止运行中 refresh_token 刷新后未保存）
sync_google_on_exit() {
    if [ -f "$TOKEN_FILE" ]; then
        local auth
        auth="$(get_current_auth)"
        if [ "$auth" = "consumer" ]; then
            cp -pf "$TOKEN_FILE" "$PROFILE_DIR/google/antigravity-oauth-token"
            [ -f "$SETTINGS_FILE" ] && cp -pf "$SETTINGS_FILE" "$PROFILE_DIR/google/settings.json"
            [ -f "$ONBOARDING_FILE" ] && cp -pf "$ONBOARDING_FILE" "$PROFILE_DIR/google/onboarding.json"
        fi
    fi
}
trap sync_google_on_exit EXIT INT TERM HUP

# 7. 清理环境干扰变量与终端兼容性设置
unset AGY_ADC_AUTH
export AGY_CLI_DISABLE_ESCAPE_SEQUENCE_OPTIMIZATIONS=1
export AGY_CLI_DISABLE_LATEX=1
export AGY_CLI_DISABLE_INLINE_MERMAID=1
stty -ixon 2>/dev/null || true

# 8. 启动 agy 并透传所有命令行参数
"$AGY_BIN" "$@"
