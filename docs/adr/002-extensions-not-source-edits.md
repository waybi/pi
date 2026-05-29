# ADR-002 — 日常扩展走 pi 的 extension 系统，不改 pi 源码

- 状态：Accepted
- 日期：2026-05-29
- 关联：ADR-001（fork 提供魔改保险，但日常不动用）

## 背景

ADR-001 决定 fork pi。随之而来的担忧：加 tool / hook 如果必须修改 `packages/` 下的 pi 源码，
那么每次 `git pull upstream` 都会冲突，fork 会越来越僵，最终拖死同步。

进一步调研 pi 源码后发现：**pi 有完整的 extension 系统，加功能根本不需要改源码。**

证据（见 `packages/coding-agent/src/core/extensions/`）：

- `ExtensionAPI` 是一等导出：`import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent"`。
- 加载方式两种：命令行 `pi --extension <file>`，或自动发现 `~/.pi/agent/extensions/`。
- extension 可带自己的 `package.json` 和 `node_modules`（pi 用 jiti 解析）。
- 官方 `packages/coding-agent/examples/extensions/` 下有 60+ 示例，覆盖工具、命令、UI、provider、
  session 钩子、子代理、git 集成等几乎所有套路。

ExtensionAPI 能力（实测自源码 `types.ts`）：

- **26 个生命周期 event**（`pi.on(...)`）：session / agent / turn / message / tool / provider / context /
  model / input 各阶段，很多支持返回值改写流程（如 `tool_call` 返回 `{ block: true }` 拒绝执行；
  `before_agent_start` 返回 `{ systemPrompt }` 改 system prompt；`context` 改写 messages）。
- **注册类**：`registerTool` / `registerCommand` / `registerShortcut` / `registerFlag` /
  `registerProvider`（含完整 OAuth 流程）/ `registerMessageRenderer`。
- **主动动作**：`sendUserMessage` / `appendEntry` / `setModel` / `setActiveTools` / `exec` 等。
- **完整 UI 操控**：`ctx.ui.*`（对话框、状态栏、widget、footer、header、自定义 editor）。
- **event bus**：`pi.events`，extension 间通信。

## 决策

所有日常能力（tool / hook / command / provider / UI）一律写成 **external extension**，
通过 pi 官方扩展点注入。**永不修改 `packages/` 下的 pi 源码来加功能。**

需求到扩展点的映射示例：

| 需求 | extension 做法 |
|---|---|
| 加 audit-fix 工具 | `registerTool({ name: "audit_fix", ... })` |
| 内存 / context 钩子 | `pi.on("context", ...)` 改 messages |
| 安全闸（block 危险 bash） | `pi.on("tool_call", ...)` 返回 `{ block: true }`（参考 `permission-gate.ts`） |
| ChatGPT OAuth provider | `registerProvider("chatgpt", { oauth: { login, refreshToken, getApiKey } })` |
| 自定义 system prompt | `pi.on("before_agent_start", ...)` 返回 `{ systemPrompt }`（参考 `pirate.ts`） |
| 自定义 compaction | `pi.on("session_before_compact", ...)`（参考 `custom-compaction.ts`） |

## 后果

- ✅ 上游同步冲突面降到接近零（不动 `packages/`）。这是本决策最大的收益。
- ✅ 扩展与内核解耦，pi 升级不破坏自己的扩展（除非 ExtensionAPI 破坏性变更）。
- ✅ 复用官方 60+ 示例作为模板，开发成本低。
- ⚠️ 受限于 ExtensionAPI 的能力边界；真要突破（改 agent-loop 内部行为等）才动用 ADR-001 的 fork 魔改权。
- ⚠️ extension 用 jiti 运行时解析 TS，注意其依赖解析与构建产物的差异。

## 备选与否决

调研前曾设计三个"代码长在 pi packages 里"的方案，调研后全部否决：

- **A. 改 pi 的 CLI 入口**（`packages/agent-cli/src/index.ts`）：高频文件，每次上游改都冲突。否决。
- **B. `agent-cli/src/_claw/` 子目录 + 新 cli 入口**：仍在 packages 内，仍有 `package.json` bin 冲突点。否决。
- **C. 新增 `packages/claw/` workspace 包**：`tsconfig.json` 的 `paths` 是显式列表，要手动加映射，
  成为常驻冲突点；且 build script 顺序也要改。过度设计。否决。

三个方案的共同前提"代码必须长在 pi packages 里"被证伪 —— extension 系统让代码可以完全在仓外。
