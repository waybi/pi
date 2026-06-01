# Workflow 设计默认（固化 workflow 怎么写）

> 写固化 workflow 脚本(pi-dynamic-workflows 的 `workflow` 工具 / `agent()`/`parallel()`/`pipeline()`)时的默认策略。
> 配合 `OPS.md §6`(推理档与限流实测)看。结论都有 A/B 实测支撑(见末尾依据)。

## 核心杠杆:逐子代理定档 > 父代理一个全局 `--thinking`

调快/调质量的真正杠杆**不是父代理的 `--thinking`**,而是 **`agent(prompt, { model })` 逐个给子代理指定模型/档位**。

- 父代理一个全局档,会逼**每一轮**(包括只读/搜索这种不需要深推理的)都用同一档 → 浪费(高档的"静默思考"是低档的数倍)。
- 固化脚本里逐子代理定档,才能"**探索用小、综合用强**",把贵的推理只花在该花的那步。
- **固化脚本 > 父代理即兴生成**:即兴编排本身就是个慢/不确定的 LLM 步骤;固化脚本让"哪个子代理用哪档、喂多大的活"完全可控、可复现。

## 档位策略(实测定的)

| 子代理角色 | 用哪档 | 依据 |
|---|---|---|
| **综合 / 判断**(distill 出最佳结论、做裁决) | **high** | 甜点位:medium 不够、xhigh 不值(见下) |
| **探索 / 扇出**(读、搜、采集事实) | high 也行,但**务必把活切小** | 不需要深推理;关键是别让它变成"重多轮" |

> 本项目当前选择:**统一用 high**,靠"把每个子代理的活切小"来避开 high 的超时墙(见下铁律)。

**为什么综合步是 high 而不是 medium 或 xhigh**(两次判官 A/B,判官都读真实代码核对):
- medium **6** vs high **8-9** → high **明显更好**(综合这步推理深度真值钱)
- high **9** vs xhigh **9** → **打平**,xhigh 白贵 ~2.7 倍、还更易超时/限流 → 不上 xhigh

## 抗超时铁律(必须遵守)

实测:gpt-5.5 经 ChatGPT Codex 订阅端**推理在服务端进行且不流式**,"想"的时候线上没数据。这段静默**随档位和任务重量放大**:

- 同一小任务:medium 最长静默 9.3s / 总 20s;high 最长静默 30.1s / 总 82s
- **重的多轮 agentic**(读几十文件 + 写 + 自验):high **直接 0 输出超时**(doc-map / doc-audit 实测均如此)

**铁律:档位可以高,但每个 `agent()` 的任务必须切小、有界**,让每次调用都接近"单发",绕开"静默累加超时"。
- ✅ 好:一个子代理读**一个**文件回答**一个**有界问题
- ❌ 坏:一个子代理"读整个 docs/ + 写长文件 + 自验循环"(必超时)

> 这不是限流(`maxRetries=0`、无 429、响应头 <1s)。是 reasoning-before-first-token 在多轮上累加。详见 OPS §6。

## 标准骨架:探索 → 综合 → 验证

```
探索/扇出(parallel,多个小子代理,各读一小块)
        ↓ 汇总
综合(一个 high 子代理,从扇出结果里 distill 出最佳)
        ↓
验证(对抗式核对,别盲信单次)
```

**验证步不能省**:实测 high 也有 **run-to-run 抖动** —— 同一综合任务,high 一次给的修复是错的、另一次是对的。所以综合即便用 high,也要再让一个子代理**对抗式核对**(默认反驳、读真实代码验),把抖动出来的错挡掉。

## 固化脚本放哪

- pi-dynamic-workflows **默认是模型即兴写脚本**(没有"放进某文件夹自动加载"的约定)。
- 要**固化复用**的 workflow 脚本,放 **`local-tools/tools/agent-skills/workflows/*.js`**(像 extensions 一样纳入分发);本设计文档管"怎么写",那里管"写好的脚本"。

## 骨架示例(伪代码)

```js
// 探索:多个小子代理并行,各读一小块(切小 → 不超时)
const findings = await parallel(targets.map((t) => () =>
  agent(`只看 ${t},回答:<一个有界问题>`, { phase: 'Explore' /* high, 但活很小 */ })))

// 综合:一个 high 子代理,从扇出结果挑最佳(单发、有界)
const best = await agent(`从下列发现里挑出最关键的一个并说明:\n${summarize(findings)}`,
  { phase: 'Synthesize', schema: BEST })

// 验证:对抗核对,别盲信(high 有抖动)
const verdict = await agent(`默认反驳。读真实代码核对这个结论是否成立:${best}`,
  { phase: 'Verify', schema: VERDICT })
```

## 实测依据(可复跑)

- A/B medium vs high(判官读代码盲评):medium 6 / high 8;high 明显更好;75s / 154s。
- A/B high vs xhigh:high 9 / xhigh 9;打平;97s / 261s;xhigh 不值。
- TTFT/静默:同任务 medium 最长静默 9.3s、high 30.1s(随档位放大)。
- high 在重多轮上 0 输出超时(doc-map / doc-audit)。
- 测试用的固化 A/B workflow 本身就是"两个 run 子代理 + 一个 judge"的结构。
