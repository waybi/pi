# ADR-004 — 用 codebase-skillbase 三层模型沉淀 pi 解读

- 状态：Accepted
- 日期：2026-05-29
- 关联：ADR-001（fork 是学习场所）

## 背景

ADR-001 把 fork 定位为"读源码 + 写笔记"的学习场所，但没规定笔记**怎么写**。
散乱手写的 `docs/01-agent-loop.md` 这类文件随心情、不成体系，难以长期维护和复用。

已有工具 `~/Desktop/my/codebase-skillbase`：标准化的"代码库 → 项目级知识库"生成器，
三层模型，产物 Claude Code skill 兼容：

- **engineering 层**：可操作工程事实（命令、配置、API、数据库、测试、部署）。
- **architecture 层**：结构与设施机制（模块边界、依赖、运行时流程、数据状态、设计决策、风险）。
- **ai-agent 层**：AI agent 项目专属语义（能力表面、上下文组装、运行时生命周期、会话记忆状态、
  工具权限、harness 适配、能力分发、安全风险）。

pi 是 AI agent 框架，与 `ai-agent` 层天然契合 —— 这层就是为这类项目设计的。

## 决策

ok-claw 的 `docs/` 用 codebase-skillbase 生成标准三层结构 `docs/project-knowledge-base/`，
**边读源码边增量填充**（而非读完一轮再整理，避免拖延）。

```bash
python3 ~/Desktop/my/codebase-skillbase/scripts/init_knowledge_base.py pi \
  --path ~/Desktop/my/ok-claw/docs/project-knowledge-base \
  --description "pi (earendil-works) agent framework 源码解读：扩展系统、生命周期事件、provider、harness"
```

- 在 `SKILL.md` 顶部标注 `synced to pi vX.Y.Z / commit <hash>`，明确解读对应的源码版本。
- 产物双重利用：
  1. **fork 仓文档** —— IDE 内源码旁就是结构化解读。
  2. **可装载 skill** —— 软链给 Claude Code：`ln -s .../docs/project-knowledge-base ~/.claude/skills/pi`，
     以后 agent 做 pi 相关任务（如帮写 extension）会自动 reference。

ai-agent 层重点文档与 pi 的对应：

| 文档 | 写什么 |
|---|---|
| capability-surface | ExtensionAPI 全表（26 event + register* + UI） |
| context-assembly | system prompt + skills 指针 + messages 怎么拼 |
| runtime-lifecycle | 26 个 event 逐个详解 |
| session-memory-state | compaction、branch、fork |
| tools-permissions | built-in tools + 注册流程 + tool_call 拦截 |
| harness-adaptation | interactive / RPC / print 三种 mode |
| capability-distribution | extensions 与 skills 的加载机制 |
| safety-risks | bash 越权、tool override、prompt 注入 |

## 后果

- ✅ 笔记从随心情手写升级为标准化工程方法，三层 + `_routing.md` 仲裁边界清晰。
- ✅ agent 做 pi 相关任务时自动获得解读上下文，写 extension 时主动查"event 怎么用"。
- ⚠️ 解读会随 pi 迭代落后；按 minor version 节奏复审（与 ADR-001 的同步流程合并）。
- ⚠️ **暂不软链给 pi 自身**（`~/.pi/skills/`）。让 pi 装载"关于 pi 自己的 skill"可能在
  agent 改 pi 时引发自指循环；先只给 Claude Code 用，等有稳定且明确"给 agent 自己看"的版本再评估。

## 待办

- [ ] `init_knowledge_base.py` 生成三层骨架到 `docs/project-knowledge-base/`。
- [ ] 边读边填 ai-agent 层（优先 capability-surface、runtime-lifecycle）。
- [ ] 软链给 Claude Code（不软链给 pi）。
