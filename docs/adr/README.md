# Architecture Decision Records

本目录记录 ok-claw（fork 自 [earendil-works/pi](https://github.com/earendil-works/pi)）的关键架构决策。

每条 ADR 描述：**背景**（为什么要做决策）、**决策**（定了什么）、**后果**（收益与代价）。
ADR 是只追加的历史记录 —— 决策被推翻时新增一条 superseding ADR，不改旧文。

## 索引

| # | 标题 | 状态 |
|---|---|---|
| [001](001-fork-pi-as-ok-claw.md) | 用 fork pi 作为 ok-claw 的基底 | Accepted |
| [002](002-extensions-not-source-edits.md) | 日常扩展走 pi 的 extension 系统，不改 pi 源码 | Accepted |
| [003](003-skills-extensions-via-agent-skills.md) | extension 与 skill 由 agent-skills 统一管理分发 | Accepted |
| [004](004-codebase-skillbase-interpretation.md) | 用 codebase-skillbase 三层模型沉淀 pi 解读 | Accepted |
| [005](005-multi-machine-consistency.md) | 多机一致性策略：代码同步，状态各自 | Accepted |

## 全局蓝图

```
ok-claw (fork, 本地 ~/Desktop/my/ok-claw)   → pi 源码 + codebase-skillbase 三层解读   [学习 + 魔改保险]
agent-skills (local-tools)                   → skills/ + extensions/ + install.sh      [日常能力工厂]
codebase-skillbase                           → 生成解读的工具本身                       [方法论]
        ↓ install 软链
~/.pi/skills/ + ~/.pi/agent/extensions/      → pi 运行时加载点
~/.claude/skills/pi                          → Claude Code 加载 pi 解读
~/.pi/ (state)                               → 各机本地，不进 git
```

## 命名说明

GitHub 仓名保留为 `waybi/pi`（fork 时未改名）；本地工作副本目录与产品概念名为 `ok-claw`。
两者不一致不影响任何功能。如需统一，可在 GitHub 上把仓 rename 为 `ok-claw`，本地 `git remote set-url` 即可。
