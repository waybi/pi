# ADR-001 — 用 fork pi 作为 ok-claw 的基底

- 状态：Accepted
- 日期：2026-05-29

## 背景

需要一个开源、可扩展、轻量、可学习、可魔改的个人 agent 系统，并要求在多台电脑上都能使用。
目标不止于编程，还包括日常自动化工作。

为选基底做过两轮调研：

1. 按 GitHub star 排序 —— 信息不足以判断真实使用度。
2. 按 token 消耗（OpenRouter 等真实付费榜单）排序 —— 暴露了一个系统性盲区：自带
   API key（BYO-key）的应用不出现在这类榜单上，pi 正是其中之一，第一轮差点漏掉。

最终选定 pi（[`earendil-works/pi`](https://github.com/earendil-works/pi)）：

- MIT license，TypeScript，monorepo。
- 多 provider（经 pi-ai），含 ChatGPT OAuth（`streamOpenAICodexResponses`，订阅内免费、无需 API key）。
- 自带完整 extension 系统与 harness 子包。
- 体量小、可读，明确"被设计为可 fork / 可扩展"。

## 决策

Fork `earendil-works/pi` 到自己的 GitHub（`waybi/pi`），clone 到本地
`~/Desktop/my/ok-claw/`，并配置 `upstream` remote 指向官方：

```bash
git clone git@github.com:waybi/pi.git ~/Desktop/my/ok-claw
cd ~/Desktop/my/ok-claw
git remote add upstream https://github.com/earendil-works/pi.git
```

**ok-claw 仓 = pi 的近乎完整镜像**，唯一新增顶层目录是 `docs/`（学习解读 + 本 ADR）。
fork 的用途是两条：**读源码学习** + **未来魔改 pi 内核的保险（期权）**。

## 后果

- ✅ 拥有权：tag / branch / 未来魔改都在自己仓里，不受官方节奏制约。
- ✅ 多机一致：`git clone` 即拿到全部源码 + 解读。
- ✅ 学习场所固定：源码和笔记在同一棵文件树，IDE 内跳转零成本。
- ⚠️ 需周期性 `git pull upstream main`；按 minor version 节奏复审，避免落后过多后心理上抗拒同步。写进 `OPS.md`。
- ⚠️ 期权成本：fork-as-workspace 的固有代价（CI/lint 配置受上游约束、npm 命名空间归上游）。
  若半年内一次内核都没改，应重新评估是否退回纯 npm 依赖（`@earendil-works/pi-agent-core`）。

## 备选与否决

- **纯 npm 依赖，不 fork**：最省事，但失去学习入口和魔改保险。用户明确要求 fork 用于学习与未雨绸缪，否决。
- **多仓 sibling（ok-claw 仓 + 独立 pi clone）**：边界清晰但要管两个克隆，学习与运行割裂。否决。
- **subtree / submodule 把 pi 嵌进独立的 ok-claw 仓**：subtree 命令繁琐、submodule 多机踩坑率高；
  既然 fork 本身就够用，无需再套一层。否决。
