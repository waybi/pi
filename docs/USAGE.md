# ok-claw 使用手册（USAGE）

> 怎么用 ok-claw 干活（操作向）。配套文档:
> - 装机 / upstream 同步 / commit 注意 / 推理档与限流实测 → [`OPS.md`](OPS.md)
> - 写固化 workflow 的逐子代理定档策略 + A/B 实测 → [`workflow-design.md`](workflow-design.md)
> - 架构决策（为什么 fork、为什么走 extension）→ [`adr/`](adr/)

约定:下文 `CLI` = `~/Desktop/my/ok-claw/packages/coding-agent/dist/cli.js`
前置:已跑过 `claw-bootstrap.sh` 且 TUI 里 `/login` 过 ChatGPT Codex（见 OPS §1）。

---

## 0. 最快路径（先跑通一个）

```bash
CLI=~/Desktop/my/ok-claw/packages/coding-agent/dist/cli.js
node "$CLI"                       # 进交互 TUI
# 在 TUI 里输入：ping claw with message hello
# 看到 CLAW_PONG: hello → 链路通了，可以开干
```

---

## 1. 启动方式

```bash
node "$CLI"                       # 交互 TUI —— 日常默认，深活都走这
node "$CLI" -p "你的指令"          # headless 单发（脚本/一次性）
node "$CLI" --mode json -p "..."  # headless + JSON 事件流（看 tool 调用）
node "$CLI" -c                    # 继续上一个会话
node "$CLI" -r                    # 选历史会话恢复
node "$CLI" --no-session -p "..." # 不留 session（临时）
```

> ⚠️ **深活（要模型真推理/多轮）一律用交互 TUI。** headless 跑实质性 gpt-5.5 任务会静默挂到超时——根因见 OPS §6 / workflow-design「抗超时铁律」。`-p` 只适合琐碎单发。

## 2. 选模型 / 推理档（按需追加）

```bash
--provider openai-codex --model gpt-5.5    # codex 默认就是 gpt-5.5
--model gpt-5.4-mini                       # 便宜快：探索/批量
--thinking medium                          # off|minimal|low|medium|high|xhigh
node "$CLI" --list-models codex            # 看可用模型
```

| 场景 | 档位 |
|---|---|
| 交互/单发深思 | `high` |
| 多轮自动化（修复循环、跨文件） | `medium`（high 多轮易超时/限流） |
| 别用 | `xhigh`（实测同质量、慢 2.7×） |

## 3. 能力速查

| 能力 | 怎么触发 | 产出 |
|---|---|---|
| `claw_ping` | TUI: `ping claw with message hi` | `CLAW_PONG: hi`，验证扩展链路 |
| `claw_audit` | TUI: `审计 <绝对路径> 的 AI-readiness` | L1/L2/L3 成熟度 + open gaps（零 LLM、只读） |
| `ai-readiness`（技能） | 上面那句自动引用 | 审计/保鲜方法，不用记命令 |
| `claw-ralph-fix` | `CLAW_RALPH_TARGET=<路径> node "$CLI" --thinking medium` | 自主循环修到审计归零 |
| `pi-dynamic-workflows` | TUI: `run a workflow to ...` | 多代理扇出编排（用 TUI；固化写法见 workflow-design.md） |
| `pi-goal` | `/goal --tokens 50k <目标>` | 跨多轮自动推进到完成/预算 |
| prompts | `/is <issue>` `/pr <url>` `/wr` `/cl` | 分析 issue / 评审 PR / 收尾提交 / changelog |

## 4. 任务菜谱

### ① 看一个项目对 AI agent 友不友好（以 topbi 为例）

```bash
# 最稳：零 LLM、只读、不用 pi、不会挂
HARNESS=~/Desktop/my/local-tools/tools/agent-harness
bash "$HARNESS/loop.sh" --target /Users/waybi/Desktop/topgames/topbi
cat "$HARNESS/.runs/topbi/gap-report.yaml"     # L1/L2/L3 成熟度 + open gaps
```
或在 **TUI** 里说:`审计 /Users/waybi/Desktop/topgames/topbi 的 AI-readiness，按严重度排序给修复建议`
（agent 调 `claw_audit`，内部跑同一个 loop.sh，再用模型总结成优先级清单）。

**读结果**:open gaps 每条带 `tier/severity/fix`，就是"对 agent 不够友好"的具体短板（缺入口文档、文档没分层、无 lint/类型检查、无记忆、缺能力地图、文档漂移……）。

### ② 把它修干净并提交（"健康提交"）

```bash
cd /Users/waybi/Desktop/topgames/topbi
git checkout -b ai-readiness-fix                 # 专用分支：Ralph 会自动改文件
CLAW_RALPH_TARGET=$PWD node "$CLI" --thinking medium   # 跑到审计归零
git commit -am "chore: AI-readiness fixes"
```

### ③ 多角度审仓 / 调研（多代理）

TUI 里:
```text
run a workflow to audit src/ for security, perf, and test-coverage gaps, then synthesize a prioritized list
```
要固化复用、控制每个子代理的档位（探索小 / 综合 high / 加验证步）→ 见 [`workflow-design.md`](workflow-design.md)，脚本放 `agent-skills/workflows/`。

### ④ 让 agent 盯一个长目标

TUI 里:
```text
/goal --tokens 30k 把 topbi 的文档漂移全部修掉并验证
/goal status | pause | resume | clear
```

### ⑤ 装新能力

```bash
node "$CLI" install npm:<包名>     # 装；然后 TUI 里 /reload
node "$CLI" list                  # 查看已装
```
自己写之前先查现成的:[awesome-pi.site/extensions](https://awesome-pi.site/extensions/) + pi.dev/packages（OPS §4）。

## 5. 避坑

- **headless 跑深活会挂** → 一律用交互 TUI（`-p` 只配琐碎单发）。
- **`high` 比 `medium` 贵 ~4×**（实测 154s/质量8 vs 75s/质量6）:只在"找最微妙问题/综合判断"时上 high，且 **high 给的修复方案要人复核**（它会自信地开错药——见 workflow-design「验证步不能省」）。
- **`pi-goal` / workflow 会自动烧额度** → 永远带 `--tokens` 预算。
- **升级 pi 后**（`git pull upstream`）回归测 `pi-dynamic-workflows` / `pi-goal`（命名空间/版本可能错配）。
- **审计只读、复用别重写**:需要新 check 加进 `readiness-kit/`，别塞进单项目 `scripts/`；改动要真，别 game 检查。

## 6. 相关文档

- [`OPS.md`](OPS.md) — 装机、同步、commit、限流实测
- [`workflow-design.md`](workflow-design.md) — 固化 workflow 的档位/结构策略
- [`adr/`](adr/) — 架构决策记录
