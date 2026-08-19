# 情绪与状态系统设计文档（desktop-buddy-mood）

## 1. 目标

把现有的"随机"变成"有状态的随机"：搭子有好感度和精力，长期不理会低落，互动多了会活跃，深夜会犯困。不引入任何新的外部服务，只加一层状态变量去调制已有的性格、语录、动作三套系统。

## 2. 状态模型

```ts
export type MoodLevel = 'lonely' | 'low' | 'normal' | 'happy' | 'sleepy'

export interface BuddyStateData {
  /** 好感度 0-100，互动累积、久不理衰减 */
  affinity: number
  /** 最后一次互动时间戳，用于结算衰减 */
  lastSeenAt: number
  /** 当天已获得的好感度，用于防刷 */
  todayGain: number
  /** todayGain 所属日期 YYYY-MM-DD */
  todayDate: string
}

/** 对外暴露的派生状态，渲染进程和 prompt 都用这个 */
export interface BuddyStatus {
  affinity: number
  energy: number      // 0-100，由时段派生，不落盘
  mood: MoodLevel
  daysSinceSeen: number
}
```

**energy 不落盘，由当前小时派生**。理由：精力本质是时间函数，存下来反而要处理"存的值和现在时间不一致"的问题。映射表：

| 时段 | energy |
|---|---|
| 0-6 点 | 15（困） |
| 7-9 点 | 60 |
| 10-11 点 | 90 |
| 12-14 点 | 55（午后） |
| 15-20 点 | 85 |
| 21-22 点 | 55 |
| 23 点 | 30 |

**mood 由 affinity + energy + 未见天数派生**，优先级从高到低：

1. `energy < 25` → `sleepy`
2. `daysSinceSeen >= 3` → `lonely`
3. `affinity < 30` → `low`
4. `affinity >= 70` → `happy`
5. 其余 → `normal`

## 3. 累积与衰减

| 行为 | 好感度变化 |
|---|---|
| 点击搭子 | +1 |
| 对话一轮 | +2 |
| 勾选完成一条 todo | +3 |
| 每满 24 小时未互动 | −5 |

**每日累积上限 +15**，超过后当天点击不再加分。不设上限的话连点二十下就能刷满，好感度就失去意义了。

**衰减不用定时器，改为读取时结算**：启动时和每次互动前，用 `now - lastSeenAt` 算出经过了几个整天，一次性扣减。这和备忘录弹窗的处理同源——macOS 睡眠唤醒后长定时器不可靠，"记录时间点 + 读取时计算"才是可靠的做法。

防御两种异常：`lastSeenAt` 在未来（用户改过系统时钟）时不做衰减；好感度下限为 0，上限 100。

## 4. 三处调制

### 4.1 动作：精力决定幅度和频率

```ts
// energy 低时只保留小动作，避免"没精神却在打滚"的违和感
const SMALL_MOTIONS = ['sway', 'tilt', 'nod']

function moodMotionPool(base: MotionName[], status: BuddyStatus): MotionName[] {
  if (status.energy < 25) return base.filter((m) => SMALL_MOTIONS.includes(m))
  if (status.mood === 'lonely' || status.mood === 'low') {
    return base.filter((m) => m !== 'roll' && m !== 'spin')  // 不做最欢腾的两个
  }
  return base
}

// 间隔倍率：困了和低落时动得少，开心时动得多
const PACE: Record<MoodLevel, number> = {
  sleepy: 2.2, lonely: 1.6, low: 1.3, normal: 1, happy: 0.75
}
```

倍率叠加在已有的"性格节奏倍率"之上。高冷角色在深夜的间隔会是 `基础 × 1.8 × 2.2`，接近三分钟动一次——这正是想要的效果。

呼吸动画速度也随精力变化：通过 CSS 变量 `--breathe-duration`，精力低时从 1.8s 拉长到 3s，视觉上就是"没精神"。

### 4.2 语录：状态命中时优先用情绪池

`lines.json` 新增三个通用情绪池（各 10 条）：

- `sleepy`：「困…」「几点了…」「你也睡吧」
- `lonely`：「好久没见你了」「我还在这儿」「以为你不要我了」
- `happy`：「今天很开心」「有你在真好」「我状态超好」

命中规则：`mood` 为 sleepy / lonely / happy 时，**60% 概率从情绪池取，40% 仍从性格语录池取**。不做成 100% 是因为性格是产品的核心，情绪只是调味——全部替换会让用户觉得"我写的性格没生效"。

### 4.3 对话：prompt 追加一行状态

在三段式 system prompt 的性格段之后插入一行，例如：

```
你现在的状态：和用户已经很熟了（好感度 82），精力充沛。
你现在的状态：精力不太够（凌晨了），说话可以更短、更懒散一点。
你现在的状态：用户已经 4 天没理你了，可以适度表达一点情绪，但不要卖惨。
```

"不要卖惨"这类约束要写进去。状态注入很容易让模型进入戏剧化表演，那会让人尴尬而不是觉得可爱。

## 5. 与现有机制的协调

**深夜不主动搭话**。`mood === 'sleepy'` 时跳过"空闲 10 分钟主动搭话"，只保留低频小动作。半夜被搭子说话是惊悚而不是陪伴。

**状态变化不打断动画**。状态只影响下一次取动作时的池子和间隔，正在播的动作不中断。

**状态刷新时机**：渲染进程每分钟拉一次状态（跨小时会变），以及每次互动后主动拉一次。不用推送，因为状态变化不需要毫秒级同步。

## 6. 界面

设置页「互动」区块顶部加一个状态卡片：

- 好感度进度条 + 数值
- 当前心情文字（睡意朦胧 / 有点孤单 / 平静 / 心情不错）
- 精力条
- 「重置状态」按钮（带二次确认）

展示数值而不是藏起来，因为可见的好感度本身就是互动激励。但不展示计分公式细节，避免用户为了刷分而互动。

## 7. 影响文件

| 类型 | 路径 | 说明 |
|---|---|---|
| 修改 | `src/shared/types.ts` | `MoodLevel`、`BuddyStateData`、`BuddyStatus`；`BuddyConfig.state` |
| 新增 | `src/main/mood.ts` | 纯逻辑：结算衰减、累积（含日上限）、energy 映射、mood 派生 |
| 修改 | `src/main/store.ts` | state 读写与默认值 |
| 修改 | `src/main/ipc.ts` | `state:get` / `state:bump` / `state:reset` |
| 修改 | `src/main/llm/client.ts` | prompt 注入状态行；对话后 +2 |
| 修改 | `src/main/memo/store.ts` 调用侧 | 勾选完成 todo 时 +3 |
| 修改 | `src/renderer/anim/motions.ts` | 情绪对动作池与间隔倍率的调制 |
| 修改 | `src/renderer/store/useBuddy.ts` | 存 status；语录按情绪池取 |
| 修改 | `src/renderer/App.tsx` | 每分钟刷新状态；sleepy 时不主动搭话；呼吸时长 CSS 变量 |
| 修改 | `src/renderer/components/Pet.tsx` | 点击时 +1 |
| 修改 | `src/renderer/styles/pet.css` | 呼吸动画用 CSS 变量 |
| 修改 | `resources/lines.json` | 三个情绪池各 10 条 |
| 修改 | `src/renderer/components/SettingsView.tsx` | 状态卡片 |
| 修改 | `README.md` | 状态系统说明 |

## 8. 边界与异常

| 场景 | 处理 |
|---|---|
| 连点刷分 | 每日上限 +15，超出不再加 |
| 跨天 | `todayDate` 变化时重置 `todayGain` |
| 系统时钟被回调 | `lastSeenAt` 在未来时不衰减，并把它修正为当前时间 |
| 长期不用（如 30 天） | 衰减下限 0，不出现负值 |
| 好感度满 100 | 不再累积，mood 保持 happy |
| 深夜 | 不主动搭话，动作只保留小幅且间隔 ×2.2 |
| 情绪池为空（文件损坏） | 回落到性格语录池，不出现空气泡 |
| 重置状态 | 好感度回到初始 20，`lastSeenAt` 置为当前 |

## 9. 预期结果

1. 凌晨打开，搭子动作幅度明显变小、频率明显变低，呼吸变慢，不主动说话，偶尔说「困…」。
2. 连续互动一段时间后好感度上升，动作变频繁，语气变亲近。
3. 三天不打开，再打开时会说「好久没见你了」类台词，好感度可见下降。
4. 连点二十下，好感度当天只涨 15 就停住。
5. 设置页能看到好感度、心情、精力，并可重置。
6. 所有效果叠加在性格之上，而不是覆盖性格——高冷角色即使 happy 也不会变得话多。
