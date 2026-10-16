# Antigravity Login Scripts (agy 多账号认证切换脚本)

一套专为 [Antigravity CLI (`agy`)](https://github.com/google/antigravity) 设计的多账号与认证方式一键无缝切换脚本工具集。

---

## 📌 背景与设计原理

Antigravity CLI 默认支持三种核心认证方式：
1. **Google 个人账户 (OAuth Consumer)**
2. **GCP / Agent Platform (企业/开发平台)**
3. **Gemini API Key (自定义 API Key 与代理网关)**

### 为什么需要这套脚本？
Antigravity CLI 默认会将所有登录凭据保存在固定的 `~/.gemini/antigravity-cli/antigravity-oauth-token`、`settings.json` 以及缓存中。当开发者需要在**个人 Google 账号**与 **企业 GCP/Agent Platform 账号**之间频繁切换，或者临时需要使用 **Gemini API Key** 时，常常会遇到：
* 切换模式导致原有 Token 被覆盖，下次切换回去必须重新走网页扫码登录；
* 运行期间 OAuth 凭据自动刷新后未及时持久化；
* 终端仿真器（例如 WindTerm、部分终端）遇到高吞吐流式输出时卡顿或 ANSI 转义序列异常。

### 核心实现原理：
* **独立 Profile 隔离机制**：在 `~/.gemini/antigravity-cli/profiles/` 下分别为 `google` 和 `ap` 建立独立快照。每次启动时，若检测到模式切换，自动将当前最新凭据存档并载入目标模式凭据。
* **双向 Trap 实时回写**：监听 `EXIT`、`INT`、`TERM`、`HUP` 信号，在进程退出或中断时将最新刷新的 `refresh_token` 回写到对应 Profile，保障凭据永不过期失效。
* **API Key 动态沙箱注入**：启动 `agy-api` 时仅临时向 `settings.json` 注入 `modelProvider: "gemini"`，退出时自动还原，丝毫不影响现有的 Google / AP 登录凭据。
* **参数透明透传**：所有命令行参数（如 `--resume`、`-m`、指定工作区等）原样透传至底层 `agy` 命令。
* **终端兼容优化**：预置流式传输优化变量与流控设置，防止终端丢包或卡死。

---

## 📂 文件结构

```text
Antigravity-login-script/
├── agy-google.sh       # Google 个人账号 (OAuth Consumer) 登录与启动脚本
├── agy-ap.sh           # GCP / Agent Platform 登录与启动脚本
├── agy-api.sh          # Gemini API Key 登录与启动脚本
├── install.sh          # 一键安装脚本（自动创建 ~/.local/bin 软链接）
├── .gitignore          # Git 忽略配置（防泄露敏感密钥）
└── README.md           # 项目使用说明
```

---

## 🚀 快速安装

### 方式 1：一键安装（推荐）
在仓库目录下执行安装脚本，自动将脚本软链接至 `~/.local/bin/`：

```bash
chmod +x *.sh
./install.sh
```

### 方式 2：手动创建软链接
```bash
chmod +x *.sh
ln -sf "$(pwd)/agy-google.sh" ~/.local/bin/agy-google
ln -sf "$(pwd)/agy-ap.sh" ~/.local/bin/agy-ap
ln -sf "$(pwd)/agy-api.sh" ~/.local/bin/agy-api
```

> 确保 `~/.local/bin` 已包含在你的 `PATH` 环境变量中（一般 Linux/macOS 默认已包含）。

---

## 🛠️ 使用说明

### 1. `agy-google` (个人 Google 账号)
切换并启动 Google 个人账户登录的 Antigravity：
```bash
agy-google
```
* **首次使用**：若尚未登录，启动后在 agy 交互界面中选择 Google 账户登录，后续运行将自动记忆。
* **支持参数**：如 `agy-google --resume` 或 `agy-google /path/to/project`。

---

### 2. `agy-ap` (GCP / Agent Platform 账号)
切换并启动 Agent Platform 认证模式：
```bash
agy-ap
```
* **首次使用**：启动后在 agy 界面中选择 GCP / Agent Platform 完成授权，凭据将自动持久化至 `profiles/ap`。

---

### 3. `agy-api` (Gemini API Key 模式)
使用 Gemini API Key 调用，支持自定义反向代理或官方 Base URL：
```bash
agy-api
```

#### API Key 配置方式（优先级由高到低）：
1. **环境变量**：
   ```bash
   export GEMINI_API_KEY="你的_GEMINI_API_KEY"
   ```
2. **当前目录或工作区配置文件**：
   创建 `gemini_key.env` 并写入：
   ```bash
   export GEMINI_API_KEY="你的_GEMINI_API_KEY"
   ```
3. **全局文件保存（免输入）**：
   ```bash
   echo "你的_GEMINI_API_KEY" > ~/.gemini/api_key
   chmod 600 ~/.gemini/api_key
   ```

#### 自定义 API Base URL（可选）：
如果使用了 Gemini API 反代或中转网关：
```bash
# 方式 1：环境变量
export GOOGLE_GEMINI_BASE_URL="https://your-custom-proxy.com"

# 方式 2：写入配置文件
echo "https://your-custom-proxy.com" > ~/.gemini/base_url
```

---

## ⚠️ 注意事项与安全性

1. **凭据安全**：
   * 脚本本身不含任何硬编码密钥或 Token。
   * 请**切勿**将包含真实密钥的 `gemini_key.env`、`~/.gemini/api_key` 或 `antigravity-oauth-token` 提交至公开仓库。本项目 `.gitignore` 已默认忽略所有敏感文件。
2. **依赖环境**：
   * 需已安装 Bash、Python 3 以及 Antigravity CLI (`agy`)。
