# 桌面搭子 v2 任务计划（desktop-buddy-v2）

执行顺序：先解决「用不起来」的问题（模型诊断），再做数据模型和抠图，接着改形象更换交互，最后做备忘录与真 Q 版。每个任务完成后应用都应可运行。

- [x] Task 1: 模型配置诊断与修复对话链路
    - 1.1: 新增 `src/main/llm/diagnose.ts`，`testConnection()` 区分地址不通 / 401 / 模型不存在 / 不支持 tools / 正常
    - 1.2: `types.ts` 新增 `DiagnoseResult`，preload 与 env.d.ts 暴露 `testConnection`
    - 1.3: 设置页模型区加「测试连接」按钮与结果展示（成功/失败具体原因）
    - 1.4: 必填项（baseUrl / apiKey / model）为空时输入框标红并说明，保存时给出提示
    - 1.5: 校验 tools 是否被支持，不支持时明确告知「三个 skill 会失效，只能闲聊」

- [x] Task 2: 数据模型与存储扩展
    - 2.1: `AvatarMeta` 增加 `cutoutPath` / `useCutout`，旧记录读取时补默认值
    - 2.2: `ModelConfig` 增加 `mattingUrl` / `mattingStyle`
    - 2.3: 新增 `MemoConfig`（enabled / popupTime / carryOver）与 `Todo` 类型
    - 2.4: 新增 memo 独立 store（`memo.json`），读取损坏时备份并以空列表启动

- [x] Task 3: AI 抠图
    - 3.1: `src/main/avatar/matting.ts` 实现 rembg 与 OpenAI 兼容两种协议，60s 超时
    - 3.2: 结果透明度校验，全不透明判定为「接口不是抠图服务」并失败退出
    - 3.3: `manager.ts` 新增 `removeAvatarBackground()`：落 `cutout.png`、置 `useCutout`、用抠图结果重建本地 Q 版
    - 3.4: `getActiveAvatar()` 与预览接口尊重 `useCutout`
    - 3.5: IPC / preload 打通，设置页「AI 抠图」按钮含禁用、生成中、失败原因三态

- [x] Task 4: 形象更换交互改造（左侧库 + 右侧预览 + 应用到桌面）
    - 4.1: 设置页形象区改两栏布局，左侧列出全部历史形象
    - 4.2: 区分「当前使用中」与「已选中待应用」两种视觉状态
    - 4.3: 右侧大图预览随选中形象和选定形态实时变化，不影响桌面
    - 4.4: 「应用到桌面」按钮：一次性提交形象 + 形态，与当前一致时禁用并提示
    - 4.5: 增加「使用抠图结果」勾选项，可退回原图
    - 4.6: 文案说明托盘/右键的形态切换是即时生效的快捷操作

- [x] Task 5: 备忘录数据层与调度
    - 5.1: `memo/store.ts`：todo 增删改查、按日期查询、文本空/超长处理
    - 5.2: `carryOverTodos()`：把过往未完成项复制为今日项并标记 `carriedFrom`，原项标记已处理
    - 5.3: `memo/schedule.ts`：每分钟轮询 + `lastPopupDate` 当日标记，睡眠唤醒后补弹一次
    - 5.4: 启动时重建当天未过期的单条 todo 提醒定时器，已过期的跳过但保留 todo
    - 5.5: 单条提醒到点复用气泡通道推送

- [x] Task 6: 备忘录界面
    - 6.1: 新增 `memo.html` / `memo.tsx` / `MemoView.tsx` / `memo.css`，并在 vite 配置注册入口
    - 6.2: `memoWindow.ts`：420×520 普通窗口、不置顶
    - 6.3: 列表交互：新增、勾选完成、删除、带过来项加「昨」角标
    - 6.4: 单条设置提醒时间
    - 6.5: 托盘菜单与形象右键菜单加「今日备忘…」入口
    - 6.6: 设置页加备忘录开关、弹出时间、是否带过来三项配置

- [x] Task 7: 备忘录接入对话
    - 7.1: 新增 `skills/memo.ts`：`add_todo` / `list_todos`
    - 7.2: 注册进 registry 并在 system prompt 里说明何时使用
    - 7.3: 通过对话新增的 todo 立即反映到备忘录窗口（广播刷新）

- [x] Task 8: 真 Q 版打通
    - 8.1: AI Q 版源图优先用 `cutout.png`
    - 8.2: 强化 prompt（chibi 头身比、保留发色服装、透明背景、无水印）
    - 8.3: 失败时把接口返回的具体原因透传到界面
    - 8.4: 已有 AI 产物时按钮变「重新生成」并二次确认
    - 8.5: Q 版形态优先用 AI 产物，本地产物作为回退

- [x] Task 9: 联调与文档
    - 9.1: 用你提供的真实接口地址实测对话、AI Q 版、抠图三条链路
    - 9.2: 备忘录跨天、睡眠唤醒补弹、提醒重建三个场景验证
    - 9.3: 旧配置兼容验证（已上传的 2 个形象不需重传）
    - 9.4: `tsc --noEmit` + `electron-vite build` + 打包验证
    - 9.5: README 补新功能、新配置项、抠图接口说明
