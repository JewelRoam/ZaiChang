# 桌宠动作系统任务计划（desktop-buddy-motion）

执行顺序：先把动作库和点击触发做出来（立刻能看到效果），再做自发调度和闸门，最后做走动和设置项。

- [✓] Task 1: 动作数据模型与配置
    - 1.1: `types.ts` 新增 `MotionName`、`MotionFreq`、`MotionConfig`
    - 1.2: `BuddyConfig.motion` 默认值：频率 normal、允许走动 false
    - 1.3: `store.ts` 读写 motion 配置，旧配置读取时补默认值
    - 1.4: IPC / preload / env.d.ts 暴露配置读写与变更广播

- [✓] Task 2: 动作库（12 个变换动作）
    - 2.1: `src/renderer/anim/motions.ts` 定义动作名、时长表
    - 2.2: `pet.css` 写 12 个 `@keyframes`：jump / hop / sway / shiver / spin / roll / squash / tilt / stretch / pop / nod / wobble
    - 2.3: 统一 `transform-origin: 50% 90%`，保证跳和蹲有重量感
    - 2.4: 性格 → 动作偏好池映射表（5 种风格各一套）
    - 2.5: `pickMotion(style, last)` 随机取动作，连续两次不重复

- [✓] Task 3: 动画状态机扩展
    - 3.1: `anim/state.ts` 状态从 4 态扩展为 `idle / thinking / talking / motion:{name}`
    - 3.2: `useBuddy` 新增 `playMotion(name)`，按动作时长自动回落 idle
    - 3.3: 正在播动作、thinking、talking 时忽略新动作，不打断不排队
    - 3.4: `Pet.tsx` className 绑定当前动作

- [✓] Task 4: 点击触发动作
    - 4.1: 单击从当前性格动作池随机取一个，替代固定的 shake
    - 4.2: 动作与台词同时出现
    - 4.3: 拖拽过程中不触发动作
    - 4.4: 双击开面板时不播动作

- [✓] Task 5: 自发动作调度
    - 5.1: 频率档位 → 间隔区间表（off / low / normal / high）
    - 5.2: 间隔随性格浮动（元气偏短、高冷偏长）
    - 5.3: 三道闸门：状态必须 idle、对话面板未打开、窗口可见
    - 5.4: `visibilitychange` + 窗口 hide/show 时暂停调度并暂停呼吸动画（省电）
    - 5.5: 恢复可见后重新计时，不补做错过的动作

- [✓] Task 6: 走动类动作（默认关闭）
    - 6.1: `src/main/motion.ts` 实现 `strollPet()`：分帧移动窗口，60ms 一帧
    - 6.2: 目标位置先 clamp 到当前屏幕工作区内，结束回到原位并持久化
    - 6.3: 走动中用户拖拽则立即中止，以当前位置为新原点
    - 6.4: 渲染进程侧配合播 sway，让它像在走而不是平移
    - 6.5: `allowMove` 为 false 时动作池里不含 stroll / peek

- [✓] Task 7: 设置项与文档
    - 7.1: 设置页「互动」区块加「动作频率」下拉（关/低/正常/高）
    - 7.2: 加「允许在桌面上走动」开关，并说明它会移动窗口位置
    - 7.3: 配置变更实时生效，无需重启
    - 7.4: README 补动作系统说明与单张静态图的能力边界
    - 7.5: `tsc --noEmit` + 构建 + 重新打包 dmg 并覆盖安装

- [✓] Task 8: 验证
    - 8.1: 频率设 high 时观察动作是否随机且不重复、不抽搐
    - 8.2: 打开对话面板、切到 thinking 状态时确认自发动作不打断
    - 8.3: 隐藏搭子后确认动画与调度都停止
    - 8.4: 开启走动后确认不跑出屏幕、结束回原位、拖拽可中止
    - 8.5: 切换不同性格的形象，确认动作幅度和节奏明显不同
