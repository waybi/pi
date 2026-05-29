# ADR-005 — 多机一致性策略：代码同步，状态各自

- 状态：Accepted
- 日期：2026-05-29
- 关联：ADR-001 / ADR-003（涉及的多个仓）

## 背景

核心需求："我需要在多台电脑上都能有这个系统。"

系统由三个独立仓 + 运行时状态 + 凭证组成：

- `ok-claw`（fork，源码 + 解读）
- `local-tools`（含 agent-skills：skills + extensions）
- `codebase-skillbase`（解读生成工具）
- 运行时状态：session / logs / cache
- 凭证：OAuth token、API key、`.env`

不同类别的东西有不同的同步语义，必须分开处理。

## 决策

**代码同步，状态各自，凭证各自。**

- **代码同步**：三个仓都是独立 git repo，新机 `git clone` 即可。互不嵌套（遵循 codebase-skillbase
  自己的约定："保持独立 git 仓，不作为松散文件夹塞进别的仓"）。
- **状态各自**：session / logs / cache 留在各机本地（pi 默认 `~/.pi/`），不进任何 git。
- **凭证各自**：`.env` / OAuth token 一律 gitignore；只提交 `.env.example`；
  OAuth 登录在每台机各自跑（如 `login-codex.sh` 触发 ChatGPT OAuth）。**绝不把凭证写进任何仓。**
- **一键就绪**：ok-claw 内 `scripts/bootstrap.sh`（待建）：
  1. 装 node（读 `.nvmrc`，用 nvm/fnm）
  2. 装依赖
  3. 拉 local-tools 并跑 `agent-skills/scripts/install.sh pi`（软链 skills + extensions）
  4. 复制 `.env.example` → `.env` 并提示用户填
- **体检**：`scripts/doctor.sh`（待建）：检查 node 版本 / pi 可用 / 凭证就位 / skills+extensions 是否软链到位。

## 后果

- ✅ 新机从零到可用一条命令（`bootstrap.sh`）。
- ✅ 凭证零泄漏风险（永不进 git）。
- ✅ 各机状态独立，不会互相污染 session。
- ⚠️ `bootstrap.sh` 跨多仓有脆弱性（依赖 local-tools 的路径约定）；用 `doctor.sh` 兜底诊断。
- ⚠️ `bootstrap.sh` / `doctor.sh` 若放进 ok-claw 仓的 `scripts/`，会与上游 `scripts/` 混在一起，
  存在 minor 冲突可能。考虑放 `scripts/claw-*.sh` 前缀或独立子目录以降冲突面（实现时定）。

## 待办

- [ ] 写 `scripts/bootstrap.sh`。
- [ ] 写 `scripts/doctor.sh`。
- [ ] 确认 pi 的 state 默认目录（`~/.pi/`）并在 doctor 中检查。
