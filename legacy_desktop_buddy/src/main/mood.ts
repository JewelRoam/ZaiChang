import type { BumpKind, BuddyStateData, BuddyStatus, MoodLevel } from '@shared/types'

export const INITIAL_AFFINITY = 20
const MAX_AFFINITY = 100
const DAILY_CAP = 15
const DECAY_PER_DAY = 5
const DAY_MS = 24 * 60 * 60 * 1000

const GAIN: Record<BumpKind, number> = { click: 1, chat: 2, todo: 3 }

/** 精力本质是时间函数，所以按小时映射而不落盘 */
export function energyOf(hour: number): number {
  if (hour < 6) return 15
  if (hour < 10) return 60
  if (hour < 12) return 90
  if (hour < 15) return 55
  if (hour < 21) return 85
  if (hour < 23) return 55
  return 30
}

export function deriveMood(affinity: number, energy: number, daysSinceSeen: number): MoodLevel {
  if (energy < 25) return 'sleepy'
  if (daysSinceSeen >= 3) return 'lonely'
  if (affinity < 30) return 'low'
  if (affinity >= 70) return 'happy'
  return 'normal'
}

export function todayStr(now = Date.now()): string {
  const d = new Date(now)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

/**
 * 按 now - lastSeenAt 结算整天衰减。
 * 不用定时器：macOS 睡眠唤醒后长定时器不可靠，「记录时间点 + 读取时计算」才靠得住。
 */
export function settleDecay(state: BuddyStateData, now = Date.now()): BuddyStateData {
  // 系统时钟被回调过，lastSeenAt 落在未来：不衰减，只把它修正回来
  if (state.lastSeenAt > now) {
    return { ...state, lastSeenAt: now }
  }
  const days = Math.floor((now - state.lastSeenAt) / DAY_MS)
  if (days <= 0) return state
  const affinity = Math.max(0, state.affinity - days * DECAY_PER_DAY)
  return { ...state, affinity, lastSeenAt: state.lastSeenAt + days * DAY_MS }
}

/** 累积好感度；每日上限避免连点刷满，否则好感度就没有意义了 */
export function bumpAffinity(
  state: BuddyStateData,
  kind: BumpKind,
  now = Date.now()
): BuddyStateData {
  const settled = settleDecay(state, now)
  const day = todayStr(now)
  const todayGain = settled.todayDate === day ? settled.todayGain : 0
  const room = Math.max(0, DAILY_CAP - todayGain)
  const gain = Math.min(GAIN[kind], room)
  return {
    affinity: Math.min(MAX_AFFINITY, settled.affinity + gain),
    lastSeenAt: now,
    todayGain: todayGain + gain,
    todayDate: day
  }
}

export function toStatus(state: BuddyStateData, now = Date.now()): BuddyStatus {
  const settled = settleDecay(state, now)
  const energy = energyOf(new Date(now).getHours())
  const daysSinceSeen = Math.floor((now - settled.lastSeenAt) / DAY_MS)
  return {
    affinity: settled.affinity,
    energy,
    mood: deriveMood(settled.affinity, energy, daysSinceSeen),
    daysSinceSeen
  }
}

export function initialState(now = Date.now()): BuddyStateData {
  return { affinity: INITIAL_AFFINITY, lastSeenAt: now, todayGain: 0, todayDate: todayStr(now) }
}

/** 注入 system prompt 的状态描述；「不要卖惨」这类约束必须写，否则模型容易演过头 */
export function statusPromptLine(status: BuddyStatus): string {
  switch (status.mood) {
    case 'sleepy':
      return `你现在的状态：精力不太够（现在是深夜），说话可以更短、更懒散一点，不要强行活跃。`
    case 'lonely':
      return `你现在的状态：用户已经 ${status.daysSinceSeen} 天没理你了，可以适度表达一点情绪，但不要卖惨、不要指责。`
    case 'low':
      return `你现在的状态：和用户还不太熟（好感度 ${status.affinity}），保持礼貌和距离感，别过分自来熟。`
    case 'happy':
      return `你现在的状态：和用户已经很熟了（好感度 ${status.affinity}），可以更亲近、更放松，但不要变得话多。`
    default:
      return `你现在的状态：平常心，精力还行。`
  }
}
