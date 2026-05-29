# ADR-003 — extension 与 skill 由 agent-skills 统一管理分发

- 状态：Accepted
- 日期：2026-05-29
- 关联：ADR-002（extension 是日常扩展的形态）

## 背景

ADR-002 决定日常能力走 external extension。随之要回答：**这些 extension 和 skill 文件存在哪、怎么分发到多台机器。**

已有成熟工具 `~/Desktop/my/local-tools/tools/agent-skills`：

- 管理可移植 `SKILL.md` 集合（`skills/<name>/SKILL.md`）。
- `scripts/install.sh` 把 skill 软链到目标位置，已支持 `~/.codex/skills/`、`~/.claude/skills/`。
- `manifest.json` 用 `targets` 字段控制每个 skill 装到哪些目标。
- 与 aweskill 配合：aweskill 做发现与临时安装，accepted 的 skill 再 intake 回 agent-skills 作为长期源。

pi 的加载约定（实测自源码）：

- skill → `~/.pi/skills/`（pi 的 `loadSkills(env, dirs)` 支持多目录，懒加载，SKILL.md 只放指针不放内容）。
- extension → `~/.pi/agent/extensions/`（自动发现）。

## 决策

- **ok-claw 仓内不存放任何 skill 或 extension 文件。** ok-claw 仓只保留 pi 源码 + `docs/`。
- 给 agent-skills 扩容：
  - 新增 `extensions/` 子目录存放 pi extensions（`.ts` 文件）。
  - `manifest.json` 增加 `"pi"` target。
  - `install.sh` 增加分支：skill → `~/.pi/skills/<name>`，extension → `~/.pi/agent/extensions/<name>.ts`。
- 新 skill 仍走既有链路：aweskill 发现 → agent-skills intake → install。

## 后果

- ✅ 一个工具统一管 skill + extension + 跨工具分发（Codex / Claude Code / pi），复用现成机制，不另起炉灶。
- ✅ ok-claw 仓职责单一（只做源码镜像 + 解读），不参与扩展生命周期。
- ✅ 扩展可在三个 agent 运行时之间复用，符合"内容层与安装适配层解耦"的既有原则。
- ⚠️ 多机部署因此变成两步：`git clone ok-claw` + `git clone local-tools` 后跑 `install.sh pi`。
  用 `bootstrap.sh` 自动化第二步（见 ADR-005）。
- ⚠️ 需确认 agent-skills 的 SKILL.md frontmatter 字段与 pi 期望一致（`name`、`description`、
  `disable-model-invocation` 等）；不一致处在 install 时做适配。

## 待办

- [ ] agent-skills 加 `extensions/` 子目录与 `pi` target。
- [ ] `install.sh` 加 pi 分支（两个软链目标）。
- [ ] 校验 SKILL.md frontmatter 与 pi 的兼容性。
