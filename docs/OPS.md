# OPS — ok-claw 运维手册

ok-claw = fork(earendil-works/pi)。本文件是这个 fork 的日常运维清单：
多机部署、upstream 同步、commit 注意事项。配合 `docs/adr/` 的决策记录看。

- origin：`git@github.com:waybi/pi.git`（GitHub 仓名 `pi`，本地目录 `ok-claw`）
- upstream：`https://github.com/earendil-works/pi.git`

---

## 1. 新机器一键就绪（多机一致 · ADR-005）

**一键路径**（推荐）：clone 后跑 bootstrap，再 doctor 体检。

```bash
git clone git@github.com:waybi/pi.git ~/Desktop/my/ok-claw
cd ~/Desktop/my/ok-claw
bash scripts/claw-bootstrap.sh    # node + build + 装扩展 + 提示登录
# 按提示在 TUI 里 /login → ChatGPT Plus/Pro (Codex)
bash scripts/claw-doctor.sh       # 体检：node / build / 登录 / 扩展是否到位
```

下面是 bootstrap 背后做的事（手动等价，排障时参考）：

```bash
# 1. node（pi 要求 >=22.19.0）—— 用 nvm 装一个合规版本
nvm install 22.22.3 && nvm use 22.22.3

# 2. 拉代码
git clone git@github.com:waybi/pi.git ~/Desktop/my/ok-claw
cd ~/Desktop/my/ok-claw
git remote add upstream https://github.com/earendil-works/pi.git

# 3. 装依赖 + build
npm install          # ~2min，348 包
npm run build        # tsgo 编译 tui/ai/agent/coding-agent → dist/cli.js

# 4. 登录 provider（凭证各机各自，绝不进 git）
node packages/coding-agent/dist/cli.js     # 交互界面里 /login → ChatGPT Plus/Pro (Codex)
# token 落 ~/.pi/agent/auth.json，自动刷新

# 5. 装扩展（skills + extensions 由 local-tools/agent-skills 分发 · ADR-003）
git clone <local-tools repo> ~/Desktop/my/local-tools   # 若尚未克隆
cd ~/Desktop/my/local-tools/tools/agent-skills
./scripts/install.sh pi      # 软链 extensions → ~/.pi/agent/extensions/
```

验证：
```bash
node ~/Desktop/my/ok-claw/packages/coding-agent/dist/cli.js \
  --no-tools --no-session -p "Reply with exactly one word: OK"
```

**代码同步，状态各自**：代码靠 git clone；session/log/cache 留各机 `~/.pi/`；凭证各机各自 `/login`。

---

## 2. commit 到 ok-claw 的注意事项 ⚠️（fork-as-workspace 同步税 · ADR-001）

**`npm install` 之后 husky pre-commit 钩子会激活**，对整仓跑：
`biome check --write . && check:pinned-deps && check:ts-imports && check:shrinkwrap && tsgo --noEmit && check:browser-smoke`

后果：

- **纯文档改动（如 `docs/`）会被钩子拦截**——因为 build/install 让 `npm-shrinkwrap.json`
  过期、`packages/ai/src/models.generated.ts` 和 `package-lock.json` 漂移，shrinkwrap 检查失败。
- 对策：**docs-only commit 用 `git commit --no-verify`**。上游钩子是给源码贡献用的，
  我们的 `docs/` 上游根本没有，跳过合理。
  ```bash
  git commit --no-verify -m "docs: ..."
  ```

- **build/install 副产物会污染工作树**：`package-lock.json`、`packages/ai/src/*.generated.ts`。
  这些是自动生成的，不要提交。commit 后还原：
  ```bash
  git restore package-lock.json packages/ai/src/models.generated.ts
  ```

- 真要改 pi **源码**（而非 docs）时，则应让钩子跑，必要时
  `npm run shrinkwrap:coding-agent` 更新 shrinkwrap 后再提交。

---

## 3. 与 upstream 同步（按 minor version 节奏 · ADR-001/004）

不追每个 commit，按 pi 的 minor version 复审。流程：

```bash
git fetch upstream
git log --oneline HEAD..upstream/main | head -30   # 看上游动了啥
git checkout main && git merge upstream/main        # 或 rebase
```

冲突高发点（因为我们改了根文件 / 自带 docs）：
- `package.json`（若动过 name/workspaces）
- `package-lock.json`、`npm-shrinkwrap.json`（generated）
- `README.md`（我们覆盖过）

同步后：
1. `npm install && npm run build` 重新构建。
2. **复审 `docs/project-knowledge-base/`**（ADR-004）：pi 源码变了，解读可能过期；
   在 `SKILL.md` 顶部更新 `synced to pi vX.Y.Z / commit`。
3. 冒烟测试（见 §1 验证）。

> 越拖越僵。两周一次，别让它落后几十个 commit。

---

## 4. 扩展与技能（ADR-002/003）

- 加能力 = 写 pi extension，**不改 pi 源码**。源在 `local-tools/tools/agent-skills/extensions/`。
- 改完 `cd local-tools/tools/agent-skills && ./scripts/install.sh pi` 重新软链。
- pi 启动自动发现 `~/.pi/agent/extensions/*.ts`（`--no-extensions` 可关）。
- 现有：`claw-ping`（健康检查）、`claw-audit`（只读 AI-readiness 审计，包 agent-harness）。

---

## 5. 常用命令

```bash
# headless 单发
node packages/coding-agent/dist/cli.js --no-session -p "<prompt>"
# JSON 事件流（看 tool 调用等）
node packages/coding-agent/dist/cli.js --no-session --mode json -p "<prompt>"
# 交互
node packages/coding-agent/dist/cli.js
# 重新 build（改了源码后）
npm run build
```

---

## 6. 推理档与限流（实测，重要）

默认档在 `~/.pi/agent/settings.json` 的 `defaultThinkingLevel`（本机设为 `high`）。但 ChatGPT Codex OAuth 这条路实测有硬限制：

| 任务类型 | 用哪档 | 实测 |
|---|---|---|
| **单发推理**（审一个文件 / 回一个问题，内容用 `@file` 内联） | high 可用 | gpt-5.5 high ~100s 出结果，质量好 |
| **多轮 agentic**（Ralph 循环、跨文件探索、audit-fix） | **medium** | high 几乎跑不动：每轮 server 端思考久且不流式，累积超时（doc-audit 在 high 下各种形态都 0 输出超时）。topbi audit-fix 在 medium 下跑完、清零 |
| high vs xhigh | 别用 xhigh | 同任务无质量增益，xhigh 慢 4-5 倍、更易限流 |

- **限流**：并行/连续猛打 high 请求会耗尽 ChatGPT 订阅额度 → 请求**静默挂起**（无报错、超时）。重活要**串行 + 留间隔**。
- **经验法则**：交互/单发深思用 high；多轮自动化（Ralph）用 medium；量大的循环考虑切本地/按量 provider（见 models.json 自定义 provider）。
