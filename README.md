# OpenClaw on ICP（最小可用子集）

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
- 语言切换：右上角按钮切换中文/英文（仅切换界面文案）

## 目录结构

- 后端主入口：backend/app.mo
- 后端模块：backend/openclaw/
	- Types.mo：对外 Candid 类型
	- Store.mo：状态与升级序列化
	- Sessions.mo / Skills.mo / Tools.mo：核心业务
	- Llm.mo：OpenAI/Anthropic 请求构造与 outcall
	- Json.mo：JSON escape + 定向解析（抽取 content/text）
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

## 本次改动（相对 ICP Ninja HelloWorld 模板）

- 后端从 HelloWorld 重构为 OpenClaw 风格最小子集：会话/历史、技能、工具、LLM outcalls
- 后端按模块拆分到 backend/openclaw/，主入口 backend/app.mo 仅负责组装与对外导出
- 前端从纯 HTML/JS 重写为 Vite + React，并加入右上角中英文切换
- 构建流程：`npm run build` 会先 `dfx generate backend` 再 `vite build` 产出 frontend/dist
