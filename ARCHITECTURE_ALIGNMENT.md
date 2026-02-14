# OpenClaw 架构对齐说明（agentonicp）

本文记录 `agentonicp` 对 `openclaw` 上游架构的同构映射，目标是让当前 ICP 版本在分层与流程上尽量接近原工程。

## 上游主干（抽样）

上游仓库（本地参考：`/Users/wangbinmac/gith/agentonicp/_upstream_openclaw`）的核心分层：

- `src/gateway/server-methods/*`：按域拆分网关方法
- `src/auto-reply/dispatch.ts`：统一入站消息分发
- `src/channels/dock.ts`：轻量渠道元数据
- `src/channels/plugins/index.ts`：渠道插件注册/获取
- `src/agents/tools/*`：工具与执行层

## ICP 版本对齐结果

对应到当前工程：

- `backend/openclaw/gateway/server-methods/*`
  - `AdminMethods.mo`
  - `WalletMethods.mo`
  - `ChannelsMethods.mo`
  - `SessionsMethods.mo`
  - `SkillsMethods.mo`
  - `HooksMethods.mo`
  - `ToolsMethods.mo`
  - `ModelsMethods.mo`
- `backend/openclaw/auto_reply/Dispatch.mo`
- `backend/openclaw/gateway/context/AuthContext.mo`
- `backend/openclaw/gateway/runtime/GatewayRuntime.mo`
- `backend/openclaw/channels/ChannelDock.mo`
- `backend/openclaw/channels/plugins/PluginRegistry.mo`
- 现有 `backend/openclaw/llm/*` + `backend/openclaw/wallet/*` 继续承担工具/执行能力

## 关键流程映射

1. API 会话发送（`sessions_send`）
- 入口：`backend/app.mo`
- 方法层：`gateway/server-methods/SessionsMethods.mo`
- 分发层：`auto_reply/Dispatch.mo`
- 会话执行：`core/Sessions.mo`（命令、hooks、模型、工具循环）

2. 渠道 webhook（Telegram/Discord）
- 入口：`http_request` / `http_request_update`
- 方法层：`gateway/server-methods/ChannelsMethods.mo`
- 插件注册：`channels/plugins/PluginRegistry.mo`
- 轻量元数据：`channels/ChannelDock.mo`
- 渠道适配器：`TelegramChannelAdapter.mo` / `DiscordChannelAdapter.mo`
- 入站统一分发：`auto_reply/Dispatch.mo`

3. 工具调用
- 注册与可见性：`llm/ToolRegistry.mo` + `llm/LlmToolRouter.mo`
- API 工具入口：`gateway/server-methods/ToolsMethods.mo`
- 运行编排：`gateway/runtime/GatewayRuntime.mo`
- 具体执行：`wallet/*`、`telegram/*`、`kv/time` 工具实现

4. 管理与钱包方法（`admin_*` / `wallet_*`）
- 入口：`backend/app.mo`
- 方法层：`gateway/server-methods/AdminMethods.mo` / `WalletMethods.mo`
- 执行层：`core/KeyVault.mo`、`wallet/*.mo`、`telegram/Telegram.mo`

## 已知差异（保留）

由于运行时不同（Node 本地网关 vs ICP canister），以下仍是有意差异：

- 不引入上游的 WS 网关、CLI 进程控制、插件动态加载机制
- 不引入设备节点/本地系统工具（如本机 shell、browser 控制等）
- 保持现有 Candid API 兼容，优先做内部架构分层对齐
