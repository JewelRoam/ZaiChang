# 桌面搭子 MVP 任务计划（desktop-buddy-mvp）

执行顺序原则：先把「能在桌面上看见一个可拖动的透明形象」这条最短链路打通并验证点击穿透（风险最高），再叠加形象管理、交互、对话、skill，最后打包。每个任务完成后都应处于可运行状态。

- [x] Task 1: 搭建 Electron + React + TS 工程骨架
    - 1.1: 在 `desktop-buddy/` 下初始化 electron-vite 工程，配置 main/preload/renderer 三端
    - 1.2: 配置 tsconfig、路径别名（`@main`/`@renderer`/`@shared`）、ESLint + Prettier
    - 1.3: 安装依赖：electron、react、zustand、electron-store、sharp
    - 1.4: 在 `src/shared/types.ts` 定义 `AvatarMeta`/`BuddyConfig`/`ChatMessage`/`SkillDef`
    - 1.5: 验证 `npm run dev` 能起一个空白窗口

- [x] Task 2: 实现透明置顶 PetWindow 与点击穿透
    - 2.1: `createPetWindow()`：transparent/frame:false/alwaysOnTop('screen-saver')/skipTaskbar
    - 2.2: preload 暴露 `setInteractive`，主进程 `setIgnoreMouseEvents(!hit, {forward:true})`
    - 2.3: 渲染进程 `hitTest` + mousemove 边界变化时才发 IPC
    - 2.4: 渲染一个占位色块验证：色块可点、色块外桌面可正常点击
    - 2.5: 窗口默认定位到主屏右下角，`display-metrics-changed` 越界复位

- [x] Task 3: 配置存储与托盘
    - 3.1: `src/main/store.ts` 定义 config schema 与默认值
    - 3.2: `src/main/ipc.ts` 建立统一 IPC 注册入口，preload 白名单暴露
    - 3.3: `createTray()`：显示/隐藏、形态切换、设置、退出
    - 3.4: 单实例锁 + 二次启动唤起已有窗口

- [x] Task 4: 形象上传、存储与管理
    - 4.1: `importAvatar()`：扩展名/体积/尺寸校验，转 PNG、长边压 512，落 `avatars/{uuid}/`
    - 4.2: `listAvatars()`/`deleteAvatar()`/`switchAvatar()` 与 config 联动
    - 4.3: 创建 SettingsWindow 与 SettingsView 的形象库 UI（网格、当前选中态、删除）
    - 4.4: 形象文件缺失时回退内置默认形象并标记失效
    - 4.5: `avatar:changed` 广播，PetWindow 即时换图

- [x] Task 5: Q 版形态生成（本地 + AI 可选）
    - 5.1: `generateChibiLocal()`：头部放大 1.35、身体压缩 0.7、合成、饱和度 1.25
    - 5.2: 上传时同步产出 `chibi.png`，设置页提供原始/Q 版对比预览
    - 5.3: `generateChibiAI()`：调可配置图像编辑接口，60s 超时，落 `chibi-ai.png`
    - 5.4: AI Q 版按钮的可用/禁用/loading/失败四态，已有产物不重复生成
    - 5.5: UI 文案标注「本地卡通化，非 AI 重绘」

- [x] Task 6: 形象渲染与动画状态机
    - 6.1: `Pet.tsx` 按当前形态加载图片，等比适配容器
    - 6.2: `anim/state.ts` 四态机 idle/shake/thinking/talking，CSS transform 实现
    - 6.3: idle 呼吸动画 1.8s 循环

- [x] Task 7: 鼠标交互与气泡
    - 7.1: `resources/lines.json` 台词库（click/idle/welcome/error 四池，约 30 条）
    - 7.2: 单击 → 随机台词（连续不重复）+ shake，气泡 3s 自动消失
    - 7.3: 拖拽移动窗口并持久化位置，拖拽中抑制单击
    - 7.4: 右键菜单（更换形象/形态切换/设置/隐藏/退出）
    - 7.5: 空闲 >10min 主动搭话，设置项可关

- [x] Task 8: 对话面板与模型接入
    - 8.1: 双击展开/收起 `ChatPanel`，展开时布局避免超出屏幕下边界
    - 8.2: 消息列表 + 输入框 + disabled 语音按钮（预留 `startAsr` IPC 占位）
    - 8.3: 设置页模型配置表单（baseUrl/apiKey/model/temperature），apiKey 输入掩码
    - 8.4: `llm/client.ts`：OpenAI 兼容 chat/completions，30s 超时，只保留最近 10 轮在内存
    - 8.5: 错误归一化为鉴权失败/网络超时/服务异常三类文案
    - 8.6: 未配置 apiKey 时提示并打开设置页

- [x] Task 9: 内置 skill 与提醒调度
    - 9.1: `skills/registry.ts` 三个 skill 定义 + tools 参数组装
    - 9.2: `scheduler.ts`：`scheduleReminder`/`list`，到点 `bubble:push`（气泡停留 8s，窗口隐藏则先显示）
    - 9.3: `launcher.ts`：仅允许 http(s) URL 与 `/Applications/*.app`，用 openExternal/openPath，禁止 shell 拼接
    - 9.4: tool_call 参数缺失/非法/时间早于当前 → 不执行并回澄清话术
    - 9.5: 人设 system prompt，回复控制在 60 字内

- [x] Task 10: 联调、异常验证与打包
    - 10.1: 按 doc 第 7 节 7 条验收标准逐条走查，重点复验点击穿透
    - 10.2: 断网、错 key、超时三种异常路径验证不崩不白屏
    - 10.3: 全屏应用下自动隐藏、多显示器切换复位验证
    - 10.4: 配置 electron-builder 产出 dmg，验证打包后 sharp 原生依赖可用
    - 10.5: 补一份 README（启动、配置模型、已知限制与 apiKey 明文存储风险说明）
