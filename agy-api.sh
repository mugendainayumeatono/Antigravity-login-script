#!/usr/bin/env bash
# ==============================================================================
# agy-api: Launch Antigravity CLI with Gemini API Key authentication
# Does not affect or invalidate existing Google Account OAuth credentials.
# ==============================================================================

set -e

SETTINGS_FILE="$HOME/.gemini/antigravity-cli/settings.json"
API_KEY_FILE="$HOME/.gemini/api_key"
BASE_URL_FILE="$HOME/.gemini/base_url"

# Locate the real agy binary
AGY_BIN="$(command -v agy || true)"
if [ -z "$AGY_BIN" ]; then
    if [ -x "$HOME/.local/bin/agy" ]; then
        AGY_BIN="$HOME/.local/bin/agy"
    else
        echo -e "\033[31m[错误] 未找到 agy 命令！请确认 Antigravity CLI 已安装。\033[0m" >&2
        exit 1
    fi
fi

# Terminal compatibility fixes for WindTerm / high-throughput streaming
export AGY_CLI_DISABLE_ESCAPE_SEQUENCE_OPTIMIZATIONS=1
export AGY_CLI_DISABLE_LATEX=1
export AGY_CLI_DISABLE_INLINE_MERMAID=1
stty -ixon 2>/dev/null || true

# 1. Load API Key: check environment, then $SCRIPT_DIR/gemini_key.env, then ~/.gemini/api_key
if [ -z "$GEMINI_API_KEY" ] && [ -z "$GOOGLE_API_KEY" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/gemini_key.env" ]; then
        source "$SCRIPT_DIR/gemini_key.env"
    elif [ -f "$API_KEY_FILE" ]; then
        export GEMINI_API_KEY=$(cat "$API_KEY_FILE" | tr -d '\r\n[:space:]')
    fi
fi

# 2. Check Base URL: check environment first, then ~/.gemini/base_url
if [ -z "$GOOGLE_GEMINI_BASE_URL" ] && [ -f "$BASE_URL_FILE" ]; then
    export GOOGLE_GEMINI_BASE_URL=$(cat "$BASE_URL_FILE" | tr -d '\r\n[:space:]')
fi

# 3. Validate that an API key is available
if [ -z "$GEMINI_API_KEY" ] && [ -z "$GOOGLE_API_KEY" ]; then
    echo -e "\033[31m[错误] 未检测到 API Key！\033[0m" >&2
    echo "请通过以下任一方式配置 API Key：" >&2
    echo "  方式 1 (临时/当前终端): export GEMINI_API_KEY=\"你的API_KEY\"" >&2
    echo "  方式 2 (永久免输保存):   echo \"你的API_KEY\" > ~/.gemini/api_key" >&2
    exit 1
fi

# 4. Cleanup function to restore settings.json (remove modelProvider)
cleanup() {
    python3 -c "
import json
p = '$SETTINGS_FILE'
try:
    with open(p, 'r', encoding='utf-8') as f:
        data = json.load(f)
    if 'modelProvider' in data:
        del data['modelProvider']
        with open(p, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
except Exception:
    pass
"
}

# Ensure cleanup is executed on exit or interruption
trap cleanup EXIT INT TERM HUP

# 5. Inject modelProvider: "gemini" into settings.json
python3 -c "
import json, os
p = '$SETTINGS_FILE'
os.makedirs(os.path.dirname(p), exist_ok=True)
data = {}
if os.path.exists(p):
    try:
        with open(p, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception:
        data = {}
data['modelProvider'] = 'gemini'
with open(p, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
"

# 6. Run original agy binary with all passed arguments
EXIT_CODE=0
"$AGY_BIN" "$@" || EXIT_CODE=$?

exit $EXIT_CODE
