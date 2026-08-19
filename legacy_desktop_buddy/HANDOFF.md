# 交接说明（给接手的 RD）

产品功能说明看 `README.md`，这份只讲上手开发需要知道的东西。设计文档在 `specs/` 下（六个迭代各有 doc.md / tasks.md / summary.md），想搞清楚某个模块为什么这么写，先翻对应的 doc。

## 跑起来

```bash
cd desktop-buddy
npm install                 # 会编译 sharp 原生模块，需要能访问 npm
npm run dev
npm run build               # tsc + electron-vite build，改完代码先跑这个
npm run dist:dmg            # 出 dmg（未签名）
```

**必须知道的坑**：如果 shell 里有 `ELECTRON_RUN_AS_NODE=1`，Electron 会以纯 Node 模式启动，进程立刻以 code 0 静默退出，没有任何报错。排查过两次，都是这个原因。遇到"启动没反应"先 `env -u ELECTRON_RUN_AS_NODE npm run dev`。

未签名 dmg 装到别人机器上会被 Gatekeeper 拦，需要 `xattr -cr /Applications/桌面搭子.app`。

## 代码结构

三个进程边界，`src/shared/types.ts` 是唯一的类型契约，加字段从这里开始。

```
src/main/          主进程
  index.ts         启动入口、单实例锁
  windows/         petWindow(透明置顶) / settingsWindow / memoWindow
  ipc.ts           所有 IPC handler 的注册点
  store.ts         electron-store 封装 + 默认值 + 迁移 + persona/state 读写
  protocol.ts      buddy:// 自定义协议，限制在 avatars 目录内
  avatar/          manager(编排) / chibi(Q版生成) / matting(抠图)
  llm/             client(对话) / diagnose(测试连接) / lines(语录生成) / skills/
  memo/            store / schedule / notify
  mood.ts          好感度与心情的纯逻辑，无副作用
  motion.ts        溜达动作（逐帧移动窗口）
  scheduler.ts     空闲主动搭话
src/preload/       白名单 IPC 桥，contextIsolation 开启
src/renderer/      pet / settings / memo 三个入口
  anim/            动作时长表、动作池、心情调制
  store/useBuddy   zustand
resources/lines.json  内置语录包，打包时作为 extraResource
```

几个容易踩的约定：

- `renderer/anim/motions.ts` 的 `MOTION_DURATION` 必须和 `styles/pet.css` 里的 `@keyframes` 时长一致，这是双份真相，有测试锁住，改动画记得同时改。
- `getEffectivePersona` / `setPersonaFor` 放在 `store.ts` 而不是 `avatar/manager.ts`，是为了避开 `llm/client.ts ↔ avatar/manager.ts` 的循环 import。别挪回去。
- 好感度衰减和备忘录补弹都用「记时间点 + 读取时结算」，不用长定时器——合盖睡眠会让长 timer 不可靠。
- 点击穿透靠 `setIgnoreMouseEvents(true,{forward:true})` + renderer 里 `elementFromPoint` 命中测试，只在命中状态跳变时发 IPC。改 pet 窗口的 DOM 结构要回归这块。

## 外部依赖

都是用户在设置页自己填的，代码里没有任何硬编码 key。

| 用途 | 协议 | 说明 |
|---|---|---|
| 对话 | OpenAI 兼容 `/chat/completions` + tools | 目前用智谱，免费档会 429，client 里有一次 2.5s 重试 |
| AI Q 版 | 阿里云百炼 DashScope 原生协议 | **不是** OpenAI 兼容格式，`input.messages[{image:base64},{text}]`，返回 24h 过期的 OSS URL |
| 抠图 | rembg 本地 HTTP | `rembg s --host 127.0.0.1 --port 7000`，目前是手起的前台进程，重启就没了，没做 launchd |

qwen 图像编辑不保证透明背景，所以 Q 版流水线是「原图 → 生成 → 再抠图」，顺序不能反。抠图那边有 alpha 通道校验，防止接口把原图直接返回来假装成功。

## 已知限制 / 待办

- `apiKey` 明文存在 `~/Library/Application Support/desktop-buddy/config.json`，对外分发前要改 `safeStorage`。
- sharp 是 arm64 原生模块，universal dmg 里只打了 arm64，Intel 机器能启动但上传形象会失败。要支持 Intel 得单独 `npm run dist:dmg -- --x64`。
- 只在 macOS 验证过，Windows 的透明置顶和点击穿透没适配。
- 提醒只在应用运行期间有效，退出后当天未触发的丢失。
- 语音输入按钮是占位，没有 ASR / TTS。
- 图标还是 Electron 默认的，需要一张 1024×1024 PNG。
- 动作都是整图变换，做不到抬手眨眼这类分层动作。可行路线是用百炼从原图生成几张姿态图（0.2 元/张）切图叠加。

## 另外

`web-demo/index.html` 是一个自包含的纯前端体验页（复用了真实的 CSS keyframes 和语录），给别人快速感受交互用的，不含 AI 能力，和主应用没有代码依赖。
