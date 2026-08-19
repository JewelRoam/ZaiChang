# 桌面搭子 MVP 设计文档（desktop-buddy-mvp）

## 1. 需求理解与 MVP 边界

### 1.1 三条原始需求的拆解

| # | 原始需求 | MVP 落地形态 |
|---|---|---|
| 1 | 形象任意上传，原始/Q 版可选，支持更换 | 支持 PNG/JPG/WebP 上传；原始形态=去背保留原图等比缩放；Q 版=本地 Canvas 程序化风格化（默认，零成本）+「AI Q 版」按钮（可选，走可配置图像编辑接口）；形象库可存多个、一键切换 |
| 2 | 桌面显示形象 + 鼠标点击互动 | 透明无边框置顶窗口；单击=台词气泡+摇晃动画；双击=展开对话面板；右键=菜单；拖拽移动；空闲呼吸动画 + 定时主动搭话 |
| 3 | 语言输入 + 内置 skill | 文字输入框（预留语音按钮，接口留好不实现）；OpenAI 兼容接口；内置 3 个 skill：定时提醒、快捷启动、闲聊 |

### 1.2 我的判断：优先级要压

需求 1 里的「Q 版」是整个 MVP 里投入产出比最低的一项。真正的 Q 版化需要人脸/主体检测 + 风格迁移，做不好就是「把头拉大的畸变图」，做好了要接图生图模型、有等待和费用。

因此本方案的处理是：**Q 版默认走本地程序化变换（头部区域放大 + 身体压缩 + 描边 + 饱和度提升），效果定位是「卡通化」而非「真 Q 版」，并在 UI 上如实标注；想要真 Q 版的用户点「AI Q 版」按钮，异步生成、结果缓存复用。** 工期主线放在需求 2 和 3。

### 1.3 明确不做（MVP 外）

TTS 语音播报、ASR 语音输入（只留按钮和 IPC 接口）、多角色同屏、骨骼动画/Live2D、云端同步、开机自启、Windows 适配调优（先保 macOS 可用，代码不写平台专有 API）。

## 2. 架构与技术方案

### 2.1 技术栈

Electron 33 + React 18 + TypeScript 5 + Vite 5（electron-vite 脚手架），状态用 zustand，配置持久化用 electron-store，打包用 electron-builder。渲染进程强制 `contextIsolation: true` / `nodeIntegration: false`，所有能力通过 preload 白名单式 IPC 暴露。

### 2.2 进程与窗口划分

- **主进程（main）**：窗口生命周期、托盘菜单、文件读写（形象素材）、配置读写、模型/图像 API 调用、定时提醒调度。所有涉及磁盘和网络的动作都在主进程，渲染进程不碰。
- **PetWindow**：透明、无边框、`alwaysOnTop`、无阴影、不进任务栏。承载形象、气泡、对话面板。透明区域通过 `setIgnoreMouseEvents(true, {forward: true})` 实现点击穿透，形象命中区域动态关闭穿透。
- **SettingsWindow**：普通窗口，形象库管理 + 模型配置 + 提醒开关。
- **Tray**：显示/隐藏搭子、切换原始/Q 版、打开设置、退出。

### 2.3 为什么用「一个 PetWindow 装下气泡和对话面板」

另一种做法是气泡、面板各开一个透明窗口。MVP 阶段不这么做：多透明窗口在 macOS 上层级和焦点管理很容易出问题（面板抢焦点导致气泡窗口被压到后面），单窗口内部用绝对定位布局成本低得多。代价是窗口尺寸要按最大展开态预留（420×560），穿透逻辑必须做对，否则会挡住用户桌面点击。

### 2.4 数据存储

```
~/Library/Application Support/desktop-buddy/
├── config.json              # electron-store：当前形象 id、显示形态、模型配置、提醒项
└── avatars/
    └── {avatarId}/
        ├── original.png     # 上传原图（统一转 PNG）
        ├── chibi.png        # 本地程序化 Q 版产物
        └── chibi-ai.png     # AI Q 版产物（可能不存在）
```

形象一律拷进应用数据目录，不引用用户原路径——否则用户挪动或删除原文件后形象直接消失。

## 3. 影响文件清单

项目根目录：`/Users/guoziying/ComateProjects/comate-zulu-demo-1785985828615/desktop-buddy/`（新建子目录，不污染现有 PPT 评测脚本）

| 类型 | 路径（相对根目录） | 职责 / 关键函数 |
|---|---|---|
| 新增 | `package.json`、`electron.vite.config.ts`、`tsconfig.json`、`electron-builder.yml` | 工程与打包配置 |
| 新增 | `src/main/index.ts` | `app.whenReady` 引导、单实例锁 |
| 新增 | `src/main/windows/petWindow.ts` | `createPetWindow()`、`applyClickThrough()` |
| 新增 | `src/main/windows/settingsWindow.ts` | `openSettings()` |
| 新增 | `src/main/tray.ts` | `createTray()` 托盘菜单 |
| 新增 | `src/main/store.ts` | 配置 schema、默认值、`getConfig/setConfig` |
| 新增 | `src/main/avatar/manager.ts` | `importAvatar()`、`listAvatars()`、`deleteAvatar()`、`switchAvatar()` |
| 新增 | `src/main/avatar/chibi.ts` | `generateChibiLocal()`（sharp 变换）、`generateChibiAI()` |
| 新增 | `src/main/llm/client.ts` | `chat()` OpenAI 兼容调用、tools 协议、错误归一化 |
| 新增 | `src/main/llm/skills/*.ts` | `reminder.ts`、`launcher.ts`、`chitchat.ts` + `registry.ts` |
| 新增 | `src/main/scheduler.ts` | `scheduleReminder()`、到点向 PetWindow 推气泡 |
| 新增 | `src/main/ipc.ts` | 所有 `ipcMain.handle` 注册，唯一 IPC 入口 |
| 新增 | `src/preload/index.ts` | `contextBridge.exposeInMainWorld('buddy', {...})` 白名单 |
| 新增 | `src/renderer/App.tsx` | 布局：Pet + Bubble + ChatPanel |
| 新增 | `src/renderer/components/Pet.tsx` | 命中区域计算、拖拽、单击/双击/右键分发 |
| 新增 | `src/renderer/components/Bubble.tsx` | 气泡显示与自动消失 |
| 新增 | `src/renderer/components/ChatPanel.tsx` | 消息列表、输入框、语音按钮（disabled） |
| 新增 | `src/renderer/components/SettingsView.tsx` | 形象库、形态切换、模型配置、提醒管理 |
| 新增 | `src/renderer/store/useBuddy.ts` | zustand：形象、形态、动画态、消息列表 |
| 新增 | `src/renderer/anim/state.ts` | 动画状态机：idle / shake / thinking / talking |
| 新增 | `src/shared/types.ts` | `AvatarMeta`、`BuddyConfig`、`ChatMessage`、`SkillDef` |
| 新增 | `resources/lines.json` | 内置互动台词库（点击/空闲/欢迎/报错） |

## 4. 关键实现细节

### 4.1 透明置顶窗口 + 点击穿透

```ts
// src/main/windows/petWindow.ts
export function createPetWindow() {
  const win = new BrowserWindow({
    width: 420, height: 560,
    transparent: true, frame: false, hasShadow: false,
    resizable: false, skipTaskbar: true,
    alwaysOnTop: true, fullscreenable: false,
    webPreferences: { preload, contextIsolation: true, nodeIntegration: false }
  })
  win.setAlwaysOnTop(true, 'screen-saver')      // 高于普通置顶窗口
  win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: false })
  win.setIgnoreMouseEvents(true, { forward: true })  // 默认全穿透
  return win
}
```

渲染进程按鼠标位置判断是否落在形象/气泡/面板的矩形内，跨越边界时才发 IPC 切换穿透状态（用 `useRef` 记录上一次状态，避免每次 mousemove 都发 IPC）：

```ts
// src/renderer/components/Pet.tsx
useEffect(() => {
  const onMove = (e: MouseEvent) => {
    const hit = hitTest(e.clientX, e.clientY)   // 形象包围盒 ∪ 气泡 ∪ 面板
    if (hit !== lastHit.current) {
      lastHit.current = hit
      window.buddy.setInteractive(hit)          // → setIgnoreMouseEvents(!hit, {forward:true})
    }
  }
  window.addEventListener('mousemove', onMove)
  return () => window.removeEventListener('mousemove', onMove)
}, [])
```

### 4.2 形象上传与存储

主进程 `importAvatar(filePath)`：校验扩展名（png/jpg/jpeg/webp）与体积（≤10MB）→ sharp 读取，校验尺寸（长边 ≥128、≤4096）→ 统一转 PNG、长边压到 512 → 写入 `avatars/{uuid}/original.png` → 同步生成 `chibi.png` → 写入配置的形象列表并返回 `AvatarMeta`。

上传成功后不自动切换当前形象，由用户在形象库里点击选择，避免误传一张图就把桌面搭子换掉。

### 4.3 Q 版两条路径

**本地程序化（默认）** — 在主进程用 sharp 做纯几何+色彩变换，不做任何检测，效果是「大头卡通化」：

```ts
// src/main/avatar/chibi.ts
export async function generateChibiLocal(src: string, out: string) {
  const img = sharp(src)
  const { width: W, height: H } = await img.metadata()
  const headH = Math.round(H * 0.45)                       // 约定上 45% 为头部
  const head = await sharp(src).extract({ left: 0, top: 0, width: W, height: headH })
    .resize({ width: Math.round(W * 1.35) }).toBuffer()     // 头部放大 1.35 倍
  const body = await sharp(src).extract({ left: 0, top: headH, width: W, height: H - headH })
    .resize({ width: W, height: Math.round((H - headH) * 0.7) }).toBuffer()  // 身体压缩到 0.7
  await sharp({ create: { width: Math.round(W * 1.35), height: /* 见实现 */ 0, channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 } } })
    .composite([{ input: head, top: 0, left: 0 }, { input: body, /* 居中对齐 */ }])
    .modulate({ saturation: 1.25 })                         // 饱和度提升，更「卡通」
    .png().toFile(out)
}
```

「上 45% 是头部」是一个硬假设。对半身人像/头像类图片效果尚可，对全身图、多人图、风景图会变形。UI 文案必须写清「卡通化效果，非 AI 重绘」，并提供 Q 版预览让用户自己判断是否接受，接受不了就用原始形态或点 AI Q 版。

**AI Q 版（可选）** — 调用配置中的图像编辑接口（OpenAI 兼容 `/v1/images/edits`），prompt 固定为 chibi 风格描述，请求超时 60s。生成中在设置页显示 loading，成功写 `chibi-ai.png` 并作为该形象的 Q 版优先产物；失败保留本地版本并提示原因。同一形象已有 `chibi-ai.png` 时不重复调用，除非用户点「重新生成」。

### 4.4 交互与动画状态机

动画状态：`idle`（1.8s 循环缩放 1.0↔1.03 呼吸）、`shake`（0.5s 左右摇晃 ±6°）、`thinking`（形象半透明 + 气泡三点省略号）、`talking`（气泡打字机输出 + 轻微上下浮动）。全部用 CSS transform + transition 实现，不引入动画库。

事件映射：

| 事件 | 行为 |
|---|---|
| 单击形象 | 从 `lines.json` 的 `click` 池随机取一句（连续两次不重复），气泡显示 3s；同时播 `shake` |
| 双击形象 | 展开/收起 ChatPanel，展开时窗口内布局上移避免面板超出屏幕下边界 |
| 右键形象 | 菜单：更换形象 / 原始形态·Q 版形态 / 打开设置 / 隐藏搭子 / 退出 |
| 按住拖拽 | 拖动窗口位置，松手后写入配置，重启复位；拖拽中不触发单击 |
| 空闲 >10min | 从 `idle` 池随机一句主动搭话（设置里可关，默认开） |

### 4.5 对话与内置 skill

模型配置项：`baseUrl`、`apiKey`、`model`、`temperature`。走标准 `POST {baseUrl}/chat/completions`，带 `tools` 参数做函数调用。只保留最近 10 轮对话在内存中，不落盘（避免聊天记录明文存磁盘）。

内置 3 个 skill：

```ts
// src/main/llm/skills/registry.ts
export const skills: SkillDef[] = [
  { name: 'set_reminder',
    description: '在指定时间或多少分钟后提醒用户做某事',
    parameters: { type: 'object', required: ['content'], properties: {
      content: { type: 'string' }, delayMinutes: { type: 'number' }, atTime: { type: 'string' } } },
    run: (args) => scheduler.scheduleReminder(args) },
  { name: 'open_target',
    description: '打开一个网址或本地应用/文件',
    parameters: { type: 'object', required: ['target'], properties: { target: { type: 'string' } } },
    run: (args) => launcher.open(args.target) },
  { name: 'list_reminders',
    description: '列出当前所有未触发的提醒',
    parameters: { type: 'object', properties: {} },
    run: () => scheduler.list() }
]
```

未命中 skill 的输入走闲聊，system prompt 注入搭子人设（简短、口语化、每次回复不超过 60 字，适配气泡展示）。

`open_target` 是唯一能对系统产生外部影响的 skill，必须做白名单式约束：只允许 `http(s)://` 开头的 URL，以及 `/Applications` 下的 `.app`；其他一律拒绝并回复「这个我打不开」。禁止拼接 shell，统一用 `shell.openExternal` / `shell.openPath`。这一条是安全底线，模型返回什么都不能绕过。

## 5. 边界条件与异常处理

| 场景 | 处理 |
|---|---|
| 上传非图片 / 超 10MB / 尺寸过小 | 设置页 toast 明确原因，不写入形象库 |
| 上传图无透明通道（jpg） | 原样显示为矩形图，提示「建议使用透明背景 PNG」；MVP 不做自动抠图 |
| 形象文件被外部删除 | 加载失败回退到内置默认形象，并把该形象标记为失效 |
| 未配置 apiKey 就发消息 | 气泡提示「先去设置里填模型配置」并直接打开设置页 |
| 模型接口 4xx/5xx/超时（30s） | 归一化为三类文案：鉴权失败 / 网络超时 / 服务异常，不把原始报文抛给用户 |
| 模型返回 tool_call 参数缺失或非法 | 不执行，回一句「没听懂要提醒啥」，并记录日志 |
| 提醒时间早于当前时间 | 拒绝创建并要求用户澄清 |
| 应用退出时仍有未触发提醒 | 提醒仅存内存，退出即失效，UI 上如实说明（MVP 不做持久化调度） |
| 多显示器 / 分辨率变化 | 监听 `display-metrics-changed`，若窗口位置越界则复位到主屏右下角 |
| 全屏应用（如全屏视频） | `visibleOnFullScreen: false`，搭子自动隐藏，退出全屏后恢复 |
| 重复启动 | 单实例锁，第二次启动只是唤起已有窗口 |

**已知安全弱点（需向使用者明示）**：apiKey 以明文存在本地 `config.json` 中。MVP 不引入系统钥匙串（keytar 会带原生依赖、拖慢打包）。这是有意识的取舍，不是遗漏；若后续要发给他人使用，必须先换成 `safeStorage` 加密存储。

## 6. 数据流路径

**上传形象**：SettingsView 点上传 → `buddy.pickAvatar()` → 主进程 `dialog.showOpenDialog` → `importAvatar()` 校验+转码+生成 chibi → 写 config → 返回 `AvatarMeta` → 渲染进程刷新形象库。

**切换形象/形态**：SettingsView 或托盘菜单 → `buddy.setAvatar(id, form)` → 主进程写 config → 主进程向 PetWindow `webContents.send('avatar:changed', meta)` → Pet 组件换图（`file://` 协议加载，路径由主进程给出）。

**对话**：ChatPanel 回车 → `buddy.chat(text)` → 主进程组装 messages+tools → 模型接口 → 若返回 tool_call：执行 skill → 把结果作为 tool message 二次请求模型 → 最终文本 → 返回渲染进程 → `talking` 动画 + 气泡/面板打字机输出。期间 Pet 处于 `thinking`。

**提醒触发**：scheduler 到点 → `webContents.send('bubble:push', {text})` → 若 PetWindow 隐藏则先显示 → 气泡展示 8s（提醒气泡比互动气泡停留更久）。

## 7. 预期结果与验收标准

MVP 交付一个可在 macOS 上 `npm run dev` 起、且能 `npm run build` 出 dmg 的应用，满足：

1. 上传任意 PNG 后，桌面右下角出现该形象，可拖动，位置重启保留。
2. 形态切换即时生效；Q 版有可预览的差异；「AI Q 版」按钮在配置了图像接口时可用，未配置时禁用并说明原因。
3. 形象之外的桌面区域点击不被拦截（点击穿透正确），这是本 MVP 最容易翻车的一点，需单独验证。
4. 单击有台词+摇晃；双击开面板；右键出菜单；空闲 10 分钟主动搭话一次。
5. 文字输入「20 分钟后提醒我喝水」→ 到点弹气泡；「打开百度」→ 浏览器打开；「你是谁」→ 人设化闲聊回复。
6. 语音按钮存在但为 disabled，hover 提示「MVP 暂不支持」，IPC 接口 `buddy.startAsr` 已定义为占位。
7. 无网络、错 key、模型超时三种异常均有明确气泡文案，应用不崩、不白屏。

## 8. 遗留待定项

- 是否需要 Windows 支持：透明窗口的点击穿透与置顶行为在 Windows 上差异较大，若要支持需追加一轮适配工期。
- 人设与台词库：`lines.json` 我会先按「轻松、简短、略带调侃」写 30 条左右，人设定调需要你确认，这部分是产品决策不是技术决策。

