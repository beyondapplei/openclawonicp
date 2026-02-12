# OpenClaw on ICP（最小可用子集）


后端Canister 是一个活的Agent

拥有自己的钱包，私钥在子网手里。控制权在Agent手里。



这是一个将 OpenClaw 的部分“核心体验”迁移到 Internet Computer（ICP）上的示例项目：

- 后端：Motoko canister（会话/历史、技能仓库、有限工具、LLM HTTPS outcalls）
- 前端：Vite + React 的 WebChat，并在右上角支持中英文切换

说明：原版 OpenClaw 是“本地网关 + 多渠道 + 本机能力 + UI”的完整系统；ICP canister 环境无法原样复刻本地网关/设备权限/多渠道接入，因此本项目实现的是可在 canister 上落地的最小子集。

## 功能

- `sessions_*`：按 Principal 隔离会话，支持创建/列表/历史/重置/发送
- `skills_*`：简化版技能仓库（写入/读取/列表/删除），发送时可选择注入到 system prompt
- `tools_*`：链上安全的极简工具（KV 读写、取当前时间）
- LLM：支持 OpenAI / Anthropic 的 HTTPS outcalls（`sessions_send` 内部调用）
- LLM：支持 OpenAI / Anthropic / Google (Gemini, AI Studio) 的 HTTPS outcalls（`sessions_send` 内部调用）
- WebChat：网页聊天 UI，可选择 provider/model、填写 API Key、查看历史、重置会话
- 钱包：主界面“钱包”按钮可查看后端 canister 的 ICP/ETH 接受地址，并支持发送 ICP
- 钱包：支持发送 ETH（Ethereum Mainnet / Base Mainnet）
	- ETH 发送流程已改为后端执行：后端查 nonce/gas -> 后端签名 -> 后端广播
- 钱包：支持发送 ICRC1 Token（传入 Ledger Principal + 目标 Principal + amount + 可选 fee）
- 钱包：支持发送 ERC20（后端构造 `transfer(address,uint256)` 并签名广播）
- 钱包：支持余额查询（ICP / ICRC1 / ETH / ERC20）
- 钱包：`wallet_eth_address()` 由后端返回 Agent ETH 地址（前端不再本地推导）
- 钱包：后端自动判断 ICP Ledger 网络（本地可用则走本地 ledger，否则回退主网 ledger）
- 架构：业务逻辑后端化（签名、转账、余额与地址计算都在 canister），前端仅负责 UI 与调用
- 语言切换：右上角按钮切换中文/英文（仅切换界面文案）

## 目录结构

- 后端主入口：backend/app.mo
- 后端模块：backend/openclaw/
	- Types.mo：对外 Candid 类型
	- Store.mo：状态与升级序列化
	- Sessions.mo / Skills.mo / Tools.mo：核心业务
	- Llm.mo：OpenAI/Anthropic 请求构造与 outcall
	- Json.mo：JSON escape + 定向解析（抽取 content/text）
	- TokenTransfer.mo：ICRC1/ICP 转账
	- WalletIcp.mo：ICP/ICRC1 钱包能力（发币、余额、本地/主网 ledger 自动判断）
	- WalletEvm.mo：EVM 钱包能力（ETH/ERC20 地址、发送、余额）
	- EthTx.mo：ETH 构造、签名与广播
- 前端：frontend/
	- index.html：React 挂载点
	- src/App.jsx：聊天 UI + 中英文切换

## 使用方式

### 依赖

- dfx（建议与本项目一致的版本或更高）
- Node.js（用于 Vite/React 前端构建）

### 本地运行（开发）

1. 启动本地 replica

	 dfx start --background

2. 安装依赖并构建前端

	 npm install
	 npm run build

3. 创建并部署 canisters

	 dfx canister create --all
	 dfx deploy

4. 打开前端

	 `dfx deploy` 输出里会给出前端 canister URL。

注意：本地 replica 对 HTTPS outcalls 可能不可用/受限；如果你需要调用 OpenAI/Anthropic，建议部署到主网并确保 canister 有足够 cycles。

### 主网部署（提示）

- HTTPS outcalls 会消耗 cycles
- 本项目当前把 API Key 作为 `sessions_send` 参数从前端传入（最简单，但 key 会出现在 canister 调用参数中）；生产环境建议改为更安全的密钥管理方案
- Google (Gemini) 的 key 可从 AI Studio 获取；本项目通过 Generative Language API `v1beta/models/{model}:generateContent` 调用
	- 模型名需要是具体 id（例如 `gemini-1.5-flash`、`gemini-1.5-pro`）；本项目也会把简写 `gemini` 自动归一化为 `gemini-1.5-flash`

## 后端 API（概览）

- sessions
	- `sessions_create(sessionId)`
	- `sessions_list()`
	- `sessions_history(sessionId, limit)`
	- `sessions_reset(sessionId)`
	- `sessions_send(sessionId, message, opts)`
- skills
	- `skills_put(name, markdown)`
	- `skills_get(name)`
	- `skills_list()`
	- `skills_delete(name)`
- tools
	- `tools_list()`
	- `tools_invoke(name, args)`
- wallet
	- `canister_principal()`
	- `agent_wallet()`
	- `wallet_eth_address()`
	- `wallet_send_icp(toPrincipalText, amountE8s)`
	- `wallet_send_icrc1(ledgerPrincipalText, toPrincipalText, amount, fee)`
	- `wallet_send_eth_raw(network, rpcUrl, rawTxHex)`
	- `wallet_send_eth(network, rpcUrl, toAddress, amountWei)`
	- `wallet_send_erc20(network, rpcUrl, tokenAddress, toAddress, amount)`
	- `wallet_balance_icp()`
	- `wallet_balance_icrc1(ledgerPrincipalText)`
	- `wallet_balance_eth(network, rpcUrl)`
	- `wallet_balance_erc20(network, rpcUrl, tokenAddress)`
	- `ecdsa_public_key(derivationPath, keyName)`
	- `sign_with_ecdsa(messageHash, derivationPath, keyName)`

说明：`wallet_send_eth` 使用后端 canister 直接调用系统 `ecdsa_public_key/sign_with_ecdsa` 完成签名与广播，不依赖 Chain Fusion Signer；前端关闭后，后端接口仍可由其他调用方触发。当前钱包相关能力（地址计算/余额查询/转账）均由后端执行。

## LLM 调用钱包接口（自然语言触发）

本项目已打通 `sessions_send` -> LLM -> 后端工具执行链路，可由自然语言触发 `wallet_send_icp`。

- 当前支持工具：`wallet_send_icp`
- 触发目标：当用户表达“给某个 Principal 转 ICP”时，模型会输出内部工具指令并由后端执行。

### 用法示例

- 你对 LLM 说：`发给 xxxxxxx 1 ICP`
- 后端流程：
	1. LLM 生成工具调用行（内部格式）
	2. `Sessions.mo` 解析为 `wallet_send_icp(to_principal, amount_e8s)`
	3. `app.mo` 中工具执行器调用 `WalletIcp.sendIcp(...)`
	4. 返回链上结果（成功时含区块号）

### 说明

- 金额按 e8s 执行：`1 ICP = 100000000 e8s`
- 若 Principal 无效、余额不足、权限不满足，会返回错误信息

## Telegram 接入（Bot Webhook）

本项目支持把 Telegram 当作“聊天入口”：你在 Telegram 里给 bot 发消息，后端 canister 会在链上调用 LLM 生成回复，并通过 Telegram `sendMessage` 回写。

### 1) 创建 Bot

用 BotFather 创建 bot 并拿到 `BOT_TOKEN`。

### 2) 在 canister 配置 Telegram + LLM

在 `dfx` 或你自己的管理脚本里调用：

- `admin_set_tg(botToken, secretToken)`：设置 bot token（建议同时设置 secret）
- `admin_set_llm_opts(opts)`：设置 Telegram 通道使用的默认 LLM 配置（provider/model/apiKey 等）

说明：为了让你能直接在 Telegram 控制它，这里的 token / LLM apiKey 会存到 canister 状态里；生产环境请谨慎处理密钥与访问控制。

### 3) 设置 Webhook

你需要一个公网可访问的 canister URL（主网）：

- `https://<canister-id>.icp0.io/tg/webhook`

然后调用：

- `admin_tg_set_webhook("https://<canister-id>.icp0.io/tg/webhook")`

如果你在 `admin_set_tg` 里设置了 `secretToken`，Telegram 会在请求头 `X-Telegram-Bot-Api-Secret-Token` 带上该值，后端会校验。

### 4) 使用

在 Telegram 里给 bot 发消息即可。会话按 chat id 隔离：`sessionId = "tg:<chatId>"`。



### 2. 管理页面（Telegram + LLM）

- 管理页支持调用以下后端管理接口：
	- `tg_status`
	- `admin_set_tg`
	- `admin_set_llm_opts`
	- `admin_tg_set_webhook`
- 支持配置并保存：
	- Telegram Bot Token
	- Secret Token（可选）
	- 默认 LLM provider/model/apiKey/system prompt
	- Webhook URL





### 5. Identity + 后端签名钱包

- 前端接入 Internet Identity 登录（II），登录后显示当前 Principal。
- ETH 地址通过后端调用系统接口 `ecdsa_public_key` 获取公钥并派生地址（前端只做展示）。
