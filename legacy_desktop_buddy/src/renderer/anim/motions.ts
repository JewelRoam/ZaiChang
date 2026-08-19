import type { BuddyStatus, LineStyle, MoodLevel, MotionName } from '@shared/types'

/** 动作时长，必须和 pet.css 里的 animation duration 一致 */
export const MOTION_DURATION: Record<MotionName, number> = {
  jump: 600,
  hop: 800,
  sway: 1200,
  shiver: 500,
  spin: 700,
  roll: 900,
  squash: 500,
  tilt: 900,
  stretch: 1100,
  pop: 400,
  nod: 700,
  wobble: 800,
  stroll: 3200,
  peek: 1400
}

/** 不同性格的动作偏好：元气幅度大、高冷只做小动作 */
const BY_STYLE: Record<LineStyle, MotionName[]> = {
  default: ['jump', 'sway', 'nod', 'tilt', 'wobble', 'squash'],
  genki: ['hop', 'jump', 'spin', 'pop', 'roll', 'wobble'],
  cool: ['sway', 'tilt', 'nod'],
  savage: ['shiver', 'wobble', 'spin', 'squash', 'pop'],
  gentle: ['sway', 'stretch', 'nod', 'tilt']
}

/** 自发动作的间隔区间（毫秒），再按性格做一次缩放 */
const FREQ_RANGE: Record<string, [number, number]> = {
  off: [0, 0],
  low: [60_000, 150_000],
  normal: [20_000, 60_000],
  high: [8_000, 25_000]
}

const STYLE_PACE: Record<LineStyle, number> = {
  default: 1,
  genki: 0.6,
  cool: 1.8,
  savage: 0.9,
  gentle: 1.3
}

export function motionPool(style: LineStyle, allowMove: boolean): MotionName[] {
  const base = BY_STYLE[style] ?? BY_STYLE.default
  return allowMove ? [...base, 'stroll', 'peek'] : base
}

/** 精力低时只做小动作——「没精神却在打滚」很违和 */
const SMALL_MOTIONS: MotionName[] = ['sway', 'tilt', 'nod']

/** 情绪对动作幅度的调制 */
export function moodMotionPool(pool: MotionName[], status: BuddyStatus | null): MotionName[] {
  if (!status) return pool
  if (status.energy < 25) {
    const small = pool.filter((m) => SMALL_MOTIONS.includes(m))
    return small.length > 0 ? small : SMALL_MOTIONS
  }
  if (status.mood === 'lonely' || status.mood === 'low') {
    const calm = pool.filter((m) => m !== 'roll' && m !== 'spin')
    return calm.length > 0 ? calm : pool
  }
  return pool
}

/** 情绪对动作频率的调制，叠加在性格节奏之上 */
const MOOD_PACE: Record<MoodLevel, number> = {
  sleepy: 2.2,
  lonely: 1.6,
  low: 1.3,
  normal: 1,
  happy: 0.75
}

/** 随机取一个动作，连续两次不重复 */
export function pickMotion(
  style: LineStyle,
  allowMove: boolean,
  last: MotionName | null,
  status: BuddyStatus | null = null
): MotionName {
  const pool = moodMotionPool(motionPool(style, allowMove), status)
  if (pool.length === 1) return pool[0]
  let pick = pool[Math.floor(Math.random() * pool.length)]
  let guard = 0
  while (pick === last && guard++ < 5) {
    pick = pool[Math.floor(Math.random() * pool.length)]
  }
  return pick
}

/** 下一次自发动作的等待时长；返回 0 表示不做自发动作 */
export function nextMotionDelay(
  freq: string,
  style: LineStyle,
  status: BuddyStatus | null = null
): number {
  const [min, max] = FREQ_RANGE[freq] ?? FREQ_RANGE.normal
  if (min === 0) return 0
  const pace = (STYLE_PACE[style] ?? 1) * (status ? MOOD_PACE[status.mood] : 1)
  return Math.round((min + Math.random() * (max - min)) * pace)
}

/** 精力越低呼吸越慢，视觉上就是「没精神」 */
export function breatheDuration(status: BuddyStatus | null): string {
  if (!status) return '1.8s'
  if (status.energy < 25) return '3s'
  if (status.energy < 60) return '2.3s'
  return '1.8s'
}

export function isMoveMotion(name: MotionName): boolean {
  return name === 'stroll' || name === 'peek'
}
