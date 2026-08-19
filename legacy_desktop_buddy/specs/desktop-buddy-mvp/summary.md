# 桌面搭子 MVP 完成总结

## 交付物

代码在 `/Users/guoziying/ComateProjects/comate-zulu-demo-1785985828615/desktop-buddy/`，Electron 32 + React 18 + TypeScript，共 24 个源文件。启动：`npm run dev`；打包：`npm run dist:dmg`。使用说明和已知限制见该目录下 README.md。

## 三条需求的落地情况

**形象上传与形态切换**：支持 PNG/JPG/WebP，校验体积（≤10MB）与尺寸（短边 ≥128、长边 ≤4096），统一转 PNG 并压到长边 512，拷进应用数据目录 `~/Library/Application Support/desktop-buddy/avatars/{uuid}/`，不引用用户原路径。设置页形象库可多存、切换、删除，原图与 Q 版并排预览。Q 版走本地 sharp 变换（头部区域放大 1.35、身体压缩 0.7、饱和度 +25%），配置了图像接口后可点「AI Q 版」调 `/images/edits` 生成真 Q 版，结果缓存不重复调用。

**桌面显示与鼠标互动**：透明无边框窗口，`alwaysOnTop('screen-saver')`，全屏应用下自动隐藏。单击出随机台词（连续不重复）+ 摇晃，双击开对话面板，右键出菜单，可拖拽且位置持久化，空闲 10 分钟主动搭话（可关）。台词库 `resources/lines.json` 分 welcome/click/idle/error/thinking 五池共 30 条。

**对话与 skill**：OpenAI 兼容 `/chat/completions`，带 tools 做函数调用，最多 3 轮工具循环，只保留最近 10 轮上下文且不落盘。内置 `set_reminder`、`open_target`、`list_reminders` 三个 skill，未命中则闲聊。语音按钮为 disabled 占位，`startAsr` IPC 已定义。

## 验证结果

- `tsc --noEmit` 与 `electron-vite build` 均通过。
- 应用实际启动无报错，渲染进程正常挂载（欢迎气泡 + 形象两个可交互节点）。
- 本地 Q 版生成经单测验证：300×400 输入产出 405×397，与公式一致。
- 提醒调度的 7 个边界用例逐一验证：空内容、缺时间、负数分钟、HH:mm 跨天、非法时间串、超 20 天上限、清空后列表均返回预期话术。
- electron-builder 打包成功，sharp 原生 `.node` 正确 unpack，`resources/lines.json` 进入 asar 且运行时可读。验证用的 release 产物已清理。

## 安全上的处理与取舍

- `open_target` 是唯一影响系统外部的能力，白名单限定 http(s) URL 与 `/Applications/*.app`，用 `shell.openExternal`/`openPath`，不拼接 shell，模型返回其他内容一律拒绝。
- 本地素材通过自定义 `buddy://` 协议读取，路径校验限制在 avatars 目录内，防止渲染进程借协议读任意文件。
- 渲染进程 `contextIsolation: true` / `nodeIntegration: false`，能力全部经 preload 白名单暴露。
- **apiKey 明文存在本地 config.json**，这是为避开原生钥匙串依赖的有意取舍，已写进 README 与设置页提示。要分发给他人前必须换成 `safeStorage`。

## 仍需人工确认的部分

1. 点击穿透的手感需要你实际用一下：代码逻辑（仅命中元素时关闭穿透）已就位，但「形象边缘附近点击桌面是否顺手」只能人工判断。
2. 模型链路需要你填真实 `baseUrl`/`apiKey` 才能跑通，我这边无法验证具体供应商的 tools 兼容性——如果换成不支持 function calling 的模型，三个 skill 会失效并退化成闲聊。
3. 台词库的人设定调（目前是「轻松、简短、略带调侃」）是产品决策，需要你确认或替换文案。
4. Windows 适配未做，需要另开一轮。
