# AgentOnICP（当前实现）

这个仓库是 OpenClaw 在 Internet Computer（ICP）canister 环境下的最小可运行实现。

- 后端：Motoko canister（会话、技能、Hooks、结构化工具调用、钱包能力、Webhook 通道）
- 前端：Vite + React（聊天页、管理页、钱包页）

说明：README 已按当前代码实现更新（以 `backend/app.mo` 与 `src/declarations/backend/backend.did` 为准）。

## 当前架构文档

- 最新架构与功能说明（中文）：`/Users/wangbinmac/gith/agentonicp/ARCHITECTURE_CURRENT_ZH.md`

## 近期功能更新

- 项目对外名称统一为 `AgentOnICP`
- 钱包新增 Uniswap V3 兑换工具链：`wallet_buy_erc20_uniswap`、`wallet_swap_uniswap`
- 钱包新增自动买 UNI：`wallet_buy_uni`（余额检查、报价、自动授权）
- 新增 Polymarket 研究能力：`polymarket_research`
- 开发窗口支持查看发送/接收的大模型完整文本
- 钱包 ECDSA 衍生路径统一为：`[canister_id, "agentonicp"]`（请求可显式覆盖，空值时回退默认）
- 修复 `sign_with_ecdsa` / `ecdsa_public_key` 的 0 cycles 问题（管理调用已附带 cycles）
- 钱包交易记录支持 EVM：ETH 在各 EVM 链可查看本应用发起的交易历史
- 钱包新增 EVM 手动添加代币合约地址（ERC20），添加后自动展示余额并可直接发起转账

## 功能说明

- 会话：`sessions_*`，按 Principal 维度隔离，支持历史、重置、发送
- 技能：`skills_*`，可在发送时注入 system prompt
- Hooks：命令触发/关键词触发，可回复文本或调用工具
- LLM：OpenAI / Anthropic / Google(Gemini) HTTPS outcall
- 结构化工具调用（function/tool calling）+ 工具后第二轮总结
- 工具策略路由：按会话前缀动态筛选可见工具（`tg:` 默认 messaging，`dc:` 默认 minimal）
- 钱包：
  - ICP / ICRC1 转账与余额
  - ETH / ERC20 转账与余额（后端签名+广播）
  - Uniswap V3 ERC20 兑换（`exactInputSingle`）
  - 自动买 UNI（检查 ETH/USDC/USDT、自动选输入币、自动授权）
- 研究：
  - Polymarket 市场候选 + 新闻头条聚合（下注分析输入）
- 多渠道：
  - Telegram webhook（`/tg/webhook`）
  - Discord webhook（`/discord/webhook`）
- 前端页面：
  - 聊天页 `index.html`
  - 管理页 `admin.html`
  - 钱包页 `wallet.html`
  - 开发窗口 `dev.html`（实时查看发送/接收全文日志）
- 对话显示：
  - 聊天页消息按全文显示（不做摘要截断）
  - 发送后与收到回复后，完整文本会同步到开发窗口（跨窗口实时更新）
- 身份与权限：
  - Internet Identity 登录
  - owner 模型（首次 owner 绑定后，仅 owner 可调用绝大多数公开接口）

对应主流程是：`sessions_send` -> 模型推理 -> （可选）工具执行 -> 二轮总结回复；渠道消息（Telegram/Discord）会复用同一套会话与工具编排能力。

## 架构对齐（参照 OpenClaw）

当前后端已按 OpenClaw 的主干分层做了同构改造（在 ICP 约束下保留可行子集）：

- `gateway/server-methods`：按功能分拆 API 方法实现（sessions/skills/hooks/tools/models）
- `auto_reply/Dispatch`：统一入站消息分发（Web/API 都走同一会话发送链路）
- `channels/plugins/PluginRegistry`：统一渠道插件注册与路由装配
- `channels/ChannelDock`：渠道轻量元信息（webhook 前缀、session 前缀）
- `core/ + llm/ + wallet/`：分别承载会话状态、模型与工具、链上钱包能力

详细映射见：`/Users/wangbinmac/gith/agentonicp/ARCHITECTURE_ALIGNMENT.md`

## 目录结构（新）

```text
backend/
  app.mo                         # 后端主入口（公开 Candid API）
  migration.mo                   # 升级迁移
  openclaw/
    core/                        # 会话、技能、状态、hooks、key 管理
      Types.mo
      Store.mo
      Sessions.mo
      Skills.mo
      Hooks.mo
      KeyVault.mo
    auto_reply/                  # OpenClaw 风格入站分发层
      Dispatch.mo
    llm/                         # LLM 请求构造、工具路由、工具注册与实现
      Llm.mo
      LlmToolRouter.mo
      ToolPolicy.mo
      ToolRegistry.mo
      ToolTypes.mo
      ToolKvGet.mo
      ToolKvPut.mo
      ToolTimeNowNs.mo
      ToolWalletIcp.mo
      ToolWalletEth.mo
      ToolWalletErc20.mo
      ToolWalletBuyErc20Uniswap.mo
      ToolWalletSwapUniswap.mo
      ToolWalletBuyUni.mo
      ToolPolymarketResearch.mo
      ToolTelegram.mo
    wallet/                      # ICP/EVM 钱包与交易
      Wallet.mo
      WalletIcp.mo
      WalletEvm.mo
      EthTx.mo
      TokenTransfer.mo
      RpcConfig.mo
      TokenConfig.mo
    polymarket/
      PolymarketResearch.mo
    channels/                    # 多渠道路由、dock 与插件注册
      ChannelRouter.mo
      ChannelDock.mo
      TelegramChannelAdapter.mo
      DiscordChannelAdapter.mo
      plugins/
        PluginRegistry.mo
    gateway/                     # OpenClaw 风格 server-methods 分层
      context/
        AuthContext.mo
      runtime/
        GatewayRuntime.mo
      server-methods/
        AdminMethods.mo
        WalletMethods.mo
        ChannelsMethods.mo
        SessionsMethods.mo
        SkillsMethods.mo
        HooksMethods.mo
        ToolsMethods.mo
        ModelsMethods.mo
    telegram/
      Telegram.mo
      TelegramWebhook.mo
    http/
      HttpTypes.mo
      Json.mo

frontend/
  index.html
  admin.html
  wallet.html
  src/
    App.jsx
    admin/AdminApp.jsx
    wallet/WalletApp.jsx
```

## 运行方式（本地）

### 依赖

- `dfx`
- Node.js + npm
- `mops`（`dfx` 构建 Motoko 时会用到）

### 步骤

1. 启动本地 replica

```bash
dfx start --background
```

2. 创建 canister id（`npm run build` 前需要）

```bash
dfx canister create --all
```

3. 安装依赖并构建前端

```bash
npm install
npm run build
```

4. 部署

```bash
dfx deploy
```

部署后从 `dfx` 输出中打开前端 URL。

### 关键注意

- `frontend` 的预构建会执行 `dfx generate backend`，所以建议先 `dfx canister create --all`
- 本地 HTTPS outcalls 可能受限；真实 LLM 调用建议主网并保证 cycles 充足
- `owner` 逻辑：首次通过受保护接口的调用者会被绑定为 owner（后续仅 owner 可管理）

## 前端页面

- 聊天页（`index.html`）
  - provider/model 选择、会话历史、skills 勾选、发送消息
  - Google provider 支持通过 `models_list` 动态拉取模型列表
  - 可打开“开发窗口”实时查看发送/接收的完整文本
- 管理页（`admin.html`）
  - Telegram / Discord 配置
  - 默认 LLM 配置（供渠道 webhook 使用）
  - Provider API Key 保存与检测
  - Skills 管理
  - Hooks 管理
- 钱包页（`wallet.html`）
  - 地址展示
  - ICP / ETH / ICRC1 / ERC20 余额刷新与转账操作
  - 交易记录：ICP 账本记录 + EVM(ETH) 本应用发起记录
  - EVM 代币管理：手动添加 ERC20 合约地址（按网络保存）

## 钱包本次改动说明（2026-02-15）

- ECDSA 与签名
  - 默认衍生路径改为 `Principal.toBlob(canisterId)` + `"agentonicp"`
  - `ecdsa_public_key` 与 `sign_with_ecdsa` 请求路径保持一致：
    - 调用方传入 `derivationPath` 非空：使用调用方路径
    - 传入为空：回退默认路径
  - 管理调用已显式附带 cycles，避免 `request sent with 0 cycles` 报错

- 钱包交易记录
  - `wallet_asset_history` 在 EVM 网络下支持 ETH 历史展示
  - 当前 EVM 历史来源为“本应用发起并成功返回 txHash 的交易记录”（稳定可用，跨 EVM 链一致）

- EVM 手动代币
  - 新增后端接口：
    - `wallet_evm_token_add(network, tokenAddress, symbol?, name?, decimals?)`
    - `wallet_evm_tokens()`
    - `wallet_evm_token_remove(network, tokenAddress)`
  - 前端钱包页支持输入并添加 ERC20 合约地址
  - 添加后会在资产列表中显示对应代币余额，并在发送页按 ERC20 流程发送

## 会话与工具流程

`sessions_send` 当前流程：

1. `gateway/server-methods/SessionsMethods` 处理鉴权、参数与 API key 解析
2. 进入 `auto_reply/Dispatch` 统一分发到 `core/Sessions.send`
3. `Sessions.send` 处理 slash 命令与 Hooks
4. 调用模型（携带 tool schema）
5. 若模型返回工具调用：执行工具，写入 `tool` 消息
6. 再次调用模型生成最终回复

说明：当前实现是有上限的 tool loop（默认最多 4 步），避免无限循环。

## LLM 工具（供模型调用）

当前注册工具：

- `wallet_send_icp`：`<to_principal>|<amount_e8s>`
- `wallet_send_eth`：`<network>|<to_address>|<amount_wei>|<amount_eth>`（`amount_wei` 与 `amount_eth` 二选一）
- `wallet_send_erc20`：`<network>|<token_address>|<to_address>|<amount>`
- `wallet_buy_erc20_uniswap`：Uniswap V3 买 ERC20（`exactInputSingle`）
- `wallet_swap_uniswap`：Uniswap V3 兑换 ERC20（支持 `auto_approve`）
- `wallet_buy_uni`：自动买 UNI（余额检查、报价、自动授权、下单）
- `polymarket_research`：拉取 Polymarket 市场候选 + 新闻头条
- `tg_send_message`：`<chat_id>|<text>`

其中 `wallet_send_eth / wallet_send_erc20` 当前支持网络：`ethereum`、`sepolia`、`base`、`polygon`、`arbitrum`、`optimism`、`bsc`、`avalanche`，以及自定义 `eip155:<chainId>`（需提供 `rpcUrl`）。

工具可见性说明：

- 普通会话（非 `tg:` / `dc:` 前缀）默认不做 profile 限制（再叠加 owner/user 权限）
- `tg:` 会话默认使用 messaging profile（是否可见消息工具仍受 owner/user 权限约束）
- `dc:` 会话默认使用 minimal profile（基础 KV/时间）
- webhook 入站默认不启用 owner tools（降低外部消息触发高风险工具的风险）

参数约定：

- tool payload 使用 `args_line`（字符串），后端按 `|` 拆分
- `wallet_send_eth` 示例：发送 2 ETH 到 `0x5A3F43378E64D196E61c0C6294882C8235212E70`
  - `wallet_send_eth|ethereum|0x5A3F43378E64D196E61c0C6294882C8235212E70||2`

## 渠道接入

### Telegram

- webhook 路径：`/tg/webhook`
- 管理 API：
  - `admin_set_tg(botToken, secretToken)`
  - `admin_set_llm_opts(opts)`
  - `admin_tg_set_webhook(url)`
  - `tg_status()`
- 若配置了 secret，后端会校验 `X-Telegram-Bot-Api-Secret-Token`

### Discord

- webhook 路径：`/discord/webhook`
- 管理 API：
  - `admin_set_discord(proxySecret)`
  - `discord_status()`
- 当前适配器会校验：
  - `x-openclaw-discord-secret`（与配置一致）
  - `x-discord-signature-ed25519`（存在）
  - `x-discord-signature-timestamp`（存在）

## 钱包说明

- ETH/ERC20：由后端查 nonce/gas、签名、广播
- RPC 默认配置集中在：`backend/agentonicp/wallet/RpcConfig.mo`
  - `ethereum/eth/mainnet` -> `https://ethereum-rpc.publicnode.com`
  - `sepolia/eth-sepolia` -> `https://ethereum-sepolia-rpc.publicnode.com`
  - `base` -> `https://base-rpc.publicnode.com`
  - `polygon/matic` -> `https://polygon-bor-rpc.publicnode.com`
  - `arbitrum/arb` -> `https://arbitrum-one-rpc.publicnode.com`
  - `optimism/op` -> `https://optimism-rpc.publicnode.com`
  - `bsc/bnb` -> `https://bsc-rpc.publicnode.com`
  - `avalanche/avax` -> `https://avalanche-c-chain-rpc.publicnode.com`
  - `solana` -> `https://solana-rpc.publicnode.com`（预留，当前未接入 Solana 转账/签名流程）
- 代币/合约地址集中在：`backend/agentonicp/wallet/TokenConfig.mo`
- `wallet_swap_uniswap`：
  - Uniswap V3 `exactInputSingle`
  - `autoApprove=true` 时先检查 allowance，不足则先发 `approve`
- `wallet_buy_uni`：
  - 先检查 ETH gas 预留、USDC/USDT 余额
  - 用 Quoter 报价，自动选更优输入币，再执行兑换
## API Key 处理

- `sessions_send` 的 `opts.apiKey` 非空时，优先使用调用时传入值
- 空值时，尝试使用 `admin_set_provider_api_key` 存储的 provider key
- 当前 KeyVault 是轻量掩码存储（非 HSM/硬件级密钥方案），生产环境建议使用更强密钥管理

## 后端 API（当前）

以 `src/declarations/backend/backend.did` 为准，按功能分组如下。

### 身份与 owner

- `owner_get()`
- `whoami()`

### sessions

- `sessions_create(sessionId)`
- `sessions_list()`
- `sessions_list_for(principal)`
- `sessions_history(sessionId, limit)`
- `sessions_reset(sessionId)`
- `sessions_send(sessionId, message, opts)`

### skills

- `skills_put(name, markdown)`
- `skills_get(name)`
- `skills_list()`
- `skills_delete(name)`

### hooks

- `hooks_list()`
- `hooks_put_command_reply(name, command, reply)`
- `hooks_put_message_reply(name, keyword, reply)`
- `hooks_put_command_tool(name, command, toolName, toolArgs)`
- `hooks_put_message_tool(name, keyword, toolName, toolArgs)`
- `hooks_set_enabled(name, enabled)`
- `hooks_delete(name)`

### 基础 tools

- `tools_list()`
- `tools_invoke(name, args)`

说明：这里的基础 tools 目前是 `kv.get`、`kv.put`、`time.nowNs`。

### LLM / provider key / 渠道管理

- `models_list(provider, apiKey)`
- `admin_set_provider_api_key(provider, apiKey)`
- `admin_has_provider_api_key(provider)`
- `admin_set_llm_opts(opts)`
- `admin_set_tg(botToken, secretToken)`
- `admin_tg_set_webhook(webhookUrl)`
- `tg_status()`
- `admin_set_discord(proxySecret)`
- `discord_status()`

### 钱包

- `canister_principal()`
- `agent_wallet()`
- `wallet_eth_address()`
- `wallet_send_icp(toPrincipalText, amountE8s)`
- `wallet_send_icrc1(ledgerPrincipalText, toPrincipalText, amount, fee)`
- `wallet_send_eth_raw(network, rpcUrl, rawTxHex)`
- `wallet_send_eth(network, rpcUrl, toAddress, amountWei)`
- `wallet_send_erc20(network, rpcUrl, tokenAddress, toAddress, amount)`
- `wallet_buy_erc20_uniswap(network, rpcUrl, routerAddress, tokenInAddress, tokenOutAddress, fee, amountIn, amountOutMinimum, deadline, sqrtPriceLimitX96)`
- `wallet_swap_uniswap(network, rpcUrl, routerAddress, tokenInAddress, tokenOutAddress, fee, amountIn, amountOutMinimum, deadline, sqrtPriceLimitX96, autoApprove)`
- `wallet_buy_uni(network, rpcUrl, amountUniBase, slippageBps, deadline)`
- `wallet_token_address(network, symbol)`
- `wallet_balance_icp()`
- `wallet_balance_icrc1(ledgerPrincipalText)`
- `wallet_balance_eth(network, rpcUrl)`
- `wallet_balance_erc20(network, rpcUrl, tokenAddress)`
- `ecdsa_public_key(derivationPath, keyName)`
- `sign_with_ecdsa(messageHash, derivationPath, keyName)`

### 研究

- `polymarket_research(topic, marketLimit, newsLimit)`

### canister HTTP

- `http_request(req)`（query）
- `http_request_update(req)`（update）
- `http_transform(args)`（query）

## 主网部署提示

- HTTPS outcalls 与 EVM RPC 请求会消耗 cycles
- webhook 使用公网 URL，例如：
  - `https://<backend-canister-id>.icp0.io/tg/webhook`
  - `https://<backend-canister-id>.icp0.io/discord/webhook`
- 生产环境建议：
  - 限制管理接口调用入口
  - 强化 API key 管理
  - 加强 Discord 签名校验链路（目前适配器主要做头字段存在性与代理 secret 校验）

2 转移控制权
1. 当前 controller 执行dfx canister update-settings backend --add-controller <new_principal>
2. 用新身份验证能管理后，再执行dfx canister update-settings backend --remove-controller <old_principal>
