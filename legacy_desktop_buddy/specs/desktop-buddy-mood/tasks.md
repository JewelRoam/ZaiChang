# 情绪与状态系统任务计划（desktop-buddy-mood）

执行顺序：先把纯逻辑层做出来并测透（衰减、防刷、时段映射最容易错），再依次接动作、语录、对话，最后做界面。

- [x] Task 1: 状态数据模型与纯逻辑层
    - 1.1: `types.ts` 新增 `MoodLevel`、`BuddyStateData`、`BuddyStatus`；`BuddyConfig.state`
    - 1.2: `store.ts` 读写 state，默认好感度 20、`lastSeenAt` 为当前
    - 1.3: `src/main/mood.ts`：`energyOf(hour)` 时段映射表
    - 1.4: `deriveMood()` 按优先级派生（sleepy → lonely → low → happy → normal）
    - 1.5: `settleDecay()` 按 `now - lastSeenAt` 结算整天衰减，下限 0，时钟回退时修正不衰减
    - 1.6: `bumpAffinity(kind)`：点击 +1 / 对话 +2 / 完成 todo +3，每日上限 +15，跨天重置

- [x] Task 2: IPC 与状态分发
    - 2.1: `state:get` 返回派生后的 `BuddyStatus`
    - 2.2: `state:bump` 接收互动类型并结算
    - 2.3: `state:reset` 重置到初始值（好感度 20）
    - 2.4: preload / env.d.ts 暴露三个接口

- [x] Task 3: 动作层调制
    - 3.1: `motions.ts` 新增 `moodMotionPool()`：精力低只留小动作，低落时去掉 roll/spin
    - 3.2: 情绪间隔倍率表（sleepy 2.2 / lonely 1.6 / low 1.3 / normal 1 / happy 0.75）
    - 3.3: 倍率叠加在既有性格节奏倍率之上
    - 3.4: `pet.css` 呼吸动画改用 `--breathe-duration` 变量，精力低时拉长到 3s
    - 3.5: 状态变化不打断正在播放的动作

- [x] Task 4: 语录层调制
    - 4.1: `lines.json` 新增 sleepy / lonely / happy 三个情绪池，各 10 条
    - 4.2: `resolveLines` 一并返回情绪池
    - 4.3: mood 命中时 60% 概率从情绪池取、40% 仍走性格池
    - 4.4: 情绪池缺失或为空时回落性格池，不出现空气泡

- [x] Task 5: 对话层调制
    - 5.1: `client.ts` 在性格段后插入一行状态描述
    - 5.2: 状态文案按 mood 分档，含「不要卖惨」这类防戏剧化约束
    - 5.3: 对话成功后好感度 +2
    - 5.4: 勾选完成 todo 时好感度 +3

- [x] Task 6: 运行时接入
    - 6.1: `App.tsx` 每分钟拉一次状态，互动后主动拉一次
    - 6.2: `mood === 'sleepy'` 时跳过空闲主动搭话
    - 6.3: 呼吸时长写入 CSS 变量
    - 6.4: `Pet.tsx` 点击时 +1

- [x] Task 7: 界面与文档
    - 7.1: 设置页「互动」区块加状态卡片：好感度进度条、心情文字、精力条
    - 7.2: 「重置状态」按钮带二次确认
    - 7.3: README 补状态系统说明
    - 7.4: `tsc --noEmit` + 构建 + 重新打包 dmg 并覆盖安装

- [x] Task 8: 验证
    - 8.1: 时段映射：0-6 点低、10-11 点高、12-14 点回落
    - 8.2: mood 派生优先级：困意优先于孤单、孤单优先于好感度档位
    - 8.3: 衰减：满 24 小时扣 5、不满不扣、下限 0、时钟回退不扣
    - 8.4: 防刷：连续 30 次点击当天只涨 15，跨天后恢复
    - 8.5: 动作池：精力低只剩小动作；间隔倍率与性格倍率正确相乘
    - 8.6: 语录：情绪命中时两个池都可能被取到，情绪池为空时不返回空
