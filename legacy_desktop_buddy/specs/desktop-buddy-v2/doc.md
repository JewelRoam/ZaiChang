# 桌面搭子 v2 设计文档（desktop-buddy-v2）

## 0. 先说第 2 条：对话不可用的原因已定位

我读了你的本机配置 `~/Library/Application Support/desktop-buddy/config.json`：`apiKey` 已填（51 位），但 **`baseUrl` 和 `model` 两项都是空字符串**。代码里这三项缺任意一个都会直接返回「先去设置里把模型配置填上」，所以不是 key 的问题，是接口地址和模型名没填。

两件事需要你处理：

1. **这个 key 已经泄露，请立刻去你的服务商后台吊销并换一个。** 它出现在了对话记录里，这类中转 key 一旦外泄会被人跑额度。后面配置时不要再把 key 贴给我，直接填进设置页就行。
2. 告诉我你这个 key 对应的接口地址（形如 `https://xxx.com/v1`）和可用的模型名。你的 key 是 `sk-` 前缀的中转格式，不是 OpenAI 官方的 `sk-proj-` 格式，我无法推测它的域名，也不该乱猜。

代码层面我要补的是**可诊断性**：现在配置不全只会甩一句模糊提示，v2 会在设置页加「测试连接」按钮，把真实失败原因显示出来（地址不通 / 401 / 模型名不存在 / 不支持 tools），而不是让你猜。这条本来就该有，是我上一版偷懒了。

## 1. 四条需求的落地形态

| # | 需求 | 方案 |
|---|---|---|
| 1a | 上传后抠图，只留人物主体 | 接 AI 抠图接口（你选的方案），产出 `cutout.png`，成功后默认用抠图结果显示；失败保留原图并明确提示 |
| 1b | 确认更换 + 可选任意历史形象 | 设置页改成「左侧形象库 + 右侧大图预览」，选中只是预览，配合形态单选，点「应用到桌面」才生效 |
| 2 | 对话不可用 | 补齐配置 + 新增「测试连接」诊断 |
| 3 | 备忘录 | 每天定时弹 todo 面板，默认 9:00，启动时若已过点且今天没弹过则补弹一次；支持勾选完成、删除、昨日未完成自动带过来、单条设提醒时间 |
| 4 | 真 Q 版 | 打通 AI Q 版链路，源图优先用抠图结果（背景干净，Q 版效果显著更好），生成中/成功/失败三态可见 |

## 2. 数据模型与配置变更

```ts
// src/shared/types.ts
interface AvatarMeta {
  // 既有字段不变…
  cutoutPath: string | null   // 新增：AI 抠图产物
  useCutout: boolean          // 新增：原始形态是否用抠图结果，抠图成功后默认 true
}

interface ModelConfig {
  // 既有字段不变…
  mattingUrl: string          // 新增：抠图接口地址，留空则「AI 抠图」按钮禁用
  mattingStyle: 'rembg' | 'openai'  // 新增：接口协议，默认 rembg
}

interface MemoConfig {          // 新增
  enabled: boolean             // 默认 true
  popupTime: string            // 'HH:mm'，默认 '09:00'
  carryOver: boolean           // 昨日未完成带过来，默认 true
}

interface Todo {                // 新增，持久化
  id: string
  text: string
  done: boolean
  date: string                 // 归属日期 YYYY-MM-DD
  remindAt: number | null      // 单条提醒时间戳
  carriedFrom?: string         // 从哪一天带过来的
}
```

存储上 todo 单独放 `memo.json`（electron-store 第二个实例），不和 `config.json` 混。理由：todo 写入频繁，和形象/模型配置混在一个文件里，任何一次勾选都要重写整份配置，出错时容易连带损坏模型配置。

素材目录新增一个文件：`avatars/{id}/cutout.png`。

## 3. 抠图（AI）

新增 `src/main/avatar/matting.ts`，支持两种协议，靠 `mattingStyle` 切换：

- **rembg 风格（默认）**：`POST {mattingUrl}` multipart，字段名 `file`，直接返回 PNG 二进制。自建 rembg / remove.bg 类服务都是这个形态。
- **OpenAI 兼容风格**：`POST {mattingUrl}/images/edits`，prompt 固定为移除背景、保留主体、输出透明通道，复用 `apiKey`。

```ts
export async function removeBackground(opts: {
  url: string; style: 'rembg' | 'openai'; apiKey: string; srcPath: string; outPath: string
}): Promise<void> {
  const buf = await sharp(opts.srcPath).png().toBuffer()
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), 60_000)
  try {
    const res = opts.style === 'rembg'
      ? await postRembg(opts, buf, ctrl.signal)
      : await postOpenAiEdit(opts, buf, ctrl.signal)
    // 关键校验：结果必须真的有透明像素，否则说明服务没抠图，只是把原图回吐了
    const out = await sharp(res).ensureAlpha().png().toBuffer()
    const { channels, isOpaque } = await sharp(out).stats().then(...)
    if (isOpaque) throw new Error('接口返回的图片没有透明背景，可能不是抠图服务')
    await writeFile(opts.outPath, out)
  } finally { clearTimeout(timer) }
}
```

那个「结果是否真有透明像素」的校验必须做。中转服务把请求转给一个不支持抠图的模型、然后原样返回原图，是很常见的失败模式；不校验的话用户看到的是「抠图成功但一点没变」，比明确报错更难排查。

抠图成功后：`cutoutPath` 落库、`useCutout = true`、**重新生成本地 Q 版**（源图换成抠图结果），并广播刷新。

## 4. 形象更换交互改造

设置页形象区改成两栏：

- **左栏形象库**：所有历史形象的缩略图列表（你上传过的都在，不会因为切换而丢），标出「当前使用中」和「已选中待应用」两种不同状态。带上传按钮和删除按钮。
- **右栏预览区**：大图显示选中形象在选定形态下的实际样子；下面是形态单选（原始 / Q 版）、`AI 抠图`、`AI Q 版` 两个处理按钮，以及主按钮 **「应用到桌面」**。

关键行为变化：点缩略图和切形态都**只改预览**，不动桌面上的搭子；只有点「应用到桌面」才写 config 并广播。这样形态和形象可以一起选好再一次性生效，也不会出现「手一抖桌面形象就变了」。

主按钮的禁用规则：选中项与当前生效项（形象 id + 形态）完全一致时禁用，并显示「已是当前形象」。

托盘和右键菜单里的形态切换保留即时生效（那是快捷操作，不走预览确认），这一点在设置页文案里说明清楚，避免两处行为不一致让人困惑。

## 5. 备忘录

新增 `src/main/memo/store.ts`（增删改查 + 带过来逻辑）、`src/main/memo/schedule.ts`（每日弹窗调度）、`src/main/windows/memoWindow.ts`（独立窗口）、`src/renderer/memo.html` + `MemoView.tsx`。

**弹窗时机**：应用启动后与每分钟一次的轮询里判断——若 `enabled` 且今天还没弹过（`lastPopupDate !== today`）且当前时间 ≥ `popupTime`，则弹一次并记 `lastPopupDate`。用「每分钟检查 + 日期标记」而不是 `setTimeout` 到点触发，是因为 macOS 睡眠唤醒后长定时器不可靠，睡过头就永远不弹了。

**昨日未完成带过来**：打开今日备忘时，把所有 `date < today && !done` 的 todo 复制成今天的条目（`carriedFrom` 记原日期），原条目标记已处理，避免同一件事每天复制一份越滚越多。列表里带过来的条目加一个「昨」的角标。

**单条提醒**：todo 可设 `remindAt`，到点复用 v1 的气泡通道推送。因为 todo 是持久化的而调度是内存态，应用启动时要重建当天所有未过期的提醒定时器——这是最容易漏的一步。

**顺带接进对话**：新增 `add_todo` 和 `list_todos` 两个 skill，这样「帮我记一下今天要写周报」也能落进备忘录，不需要额外打开面板。成本很低，且让备忘录和 chatbot 不是两套割裂的东西。

窗口形态：普通窗口（有标题栏、可关闭），420×520，不置顶，避免早上弹出来挡住你正在做的事。

## 6. 真 Q 版（AI）

链路 v1 已搭好，v2 要做的是让它真能跑通并且好用：

- 源图优先级改为 `cutout.png` → `original.png`。背景干净的输入对 Q 版化的效果影响很大，带背景的图容易让模型把背景一起卡通化。
- prompt 强化：明确要求 chibi 比例（头身比约 1:1.2）、保留发色与服装特征、纯透明背景、无文字水印。
- 生成中在预览区显示进度占位，失败把接口返回的具体原因显示出来（而不是「生成失败」四个字）。
- 生成成功后 Q 版形态优先用 AI 产物，本地卡通化产物保留作为回退。
- 已有 AI 产物时按钮变「重新生成」，需要二次确认（避免误点重复消耗额度）。

**风险明说**：你的 key 是中转服务的，很多中转只代理 `chat/completions`，不一定支持 `images/edits`。如果实测发现不支持，可选方案是换成 `images/generations` + 图片 URL 输入的形态，或者单独找一个图像服务。这个要拿到你的接口地址实测才能定，我不会预先写两套适配。

## 7. 影响文件清单

根目录 `/Users/guoziying/ComateProjects/comate-zulu-demo-1785985828615/desktop-buddy/`

| 类型 | 路径 | 说明 |
|---|---|---|
| 新增 | `src/main/avatar/matting.ts` | `removeBackground()` + 透明度校验 |
| 新增 | `src/main/memo/store.ts` | todo 持久化、`carryOverTodos()`、增删改查 |
| 新增 | `src/main/memo/schedule.ts` | 每日弹窗轮询、启动时重建单条提醒 |
| 新增 | `src/main/windows/memoWindow.ts` | `openMemo()` |
| 新增 | `src/main/llm/skills/memo.ts` | `add_todo` / `list_todos` |
| 新增 | `src/main/llm/diagnose.ts` | `testConnection()` 返回结构化诊断结果 |
| 新增 | `src/renderer/memo.html`、`memo.tsx`、`components/MemoView.tsx`、`styles/memo.css` | 备忘录界面 |
| 修改 | `src/shared/types.ts` | `AvatarMeta` 加 `cutoutPath`/`useCutout`；新增 `MemoConfig`/`Todo`/`DiagnoseResult` |
| 修改 | `src/main/store.ts` | 新增 memo 配置项；旧 avatar 记录做字段补默认值的迁移 |
| 修改 | `src/main/avatar/manager.ts` | `removeAvatarBackground()`；`getActiveAvatar` 尊重 `useCutout`；Q 版源图改抠图优先 |
| 修改 | `src/main/avatar/chibi.ts` | 强化 AI prompt，`generateChibiLocal` 接受抠图源 |
| 修改 | `src/main/ipc.ts` | 新增抠图、备忘录、测试连接相关 handler |
| 修改 | `src/main/tray.ts` | 菜单加「今日备忘…」 |
| 修改 | `src/main/index.ts` | 启动时初始化 memo 调度 |
| 修改 | `src/preload/index.ts`、`src/renderer/env.d.ts` | 暴露新 API |
| 修改 | `src/renderer/components/SettingsView.tsx` | 两栏改造 + 应用到桌面 + 测试连接 + 备忘录设置 |
| 修改 | `src/renderer/components/Pet.tsx` 右键菜单 | 加「今日备忘」入口 |
| 修改 | `electron.vite.config.ts` | 注册 `memo.html` 入口 |
| 修改 | `README.md` | 新功能与新配置项说明 |

## 8. 边界与异常

| 场景 | 处理 |
|---|---|
| 未配置抠图地址 | 「AI 抠图」按钮禁用，hover 说明需要先配置 |
| 抠图接口返回不透明图 | 判定为失败，提示「这个接口好像不是抠图服务」，不覆盖原图 |
| 抠图/Q 版接口超时（60s） | 明确超时提示，保留既有产物，按钮回到可点状态 |
| 抠图后主体只剩一小块（误抠） | 保留原图不删，用户可在预览区取消勾选「使用抠图结果」回到原图 |
| 旧版本已上传的形象 | 读取时补 `cutoutPath: null`/`useCutout: false`，不需要重新上传 |
| 备忘录跨天 | 以本地日期为准；跨天后重新计算今日列表与带过来项 |
| 系统睡眠跨过弹窗时间 | 每分钟轮询 + 当日标记，唤醒后补弹一次，不会连弹多次 |
| todo 提醒时间已过 | 启动重建时跳过并保留 todo，不静默丢弃 |
| todo 文本为空或超长 | 空则不添加；超 200 字截断 |
| memo.json 损坏 | 读取失败时备份为 `memo.json.bak` 并以空列表启动，不让应用起不来 |
| 测试连接时 key 为空 | 直接返回「apiKey 未填」，不发请求 |

## 9. 预期结果

1. 上传图片 → 点「AI 抠图」→ 预览区看到只剩主体的透明图 → 点「应用到桌面」→ 桌面搭子无背景方块。
2. 形象库里所有历史形象都能重新选回来，选中不立即生效，「应用到桌面」才生效。
3. 设置页「测试连接」能给出具体失败原因；配好后对话正常，三个 skill 可用。
4. 每天 9:00（可改）弹出今日备忘；启动时若已过点且当天没弹过会补弹一次；昨日未完成自动带过来；单条 todo 到点气泡提醒。
5. 「AI Q 版」在配置了图像接口后能产出真正的 Q 版形象，失败时显示具体原因。

## 10. 需要你提供的信息

1. `baseUrl`（形如 `https://xxx.com/v1`）与可用模型名——对话和 AI Q 版都卡在这里。
2. 抠图服务地址；如果没有现成的，告诉我，我可以先把接口做成可配置的空实现，等你拿到地址再填。
3. 换过的新 key 请直接填进设置页，不要发给我。
