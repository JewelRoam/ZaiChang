import type { MotionName } from '@shared/types'
import { MOTION_DURATION } from './motions'

/** idle 是稳态；thinking 由业务显式结束；motion 播完自动回落 idle */
export type AnimState = 'idle' | 'thinking' | 'talking' | { motion: MotionName }

const TALKING_MS = 1200

export function isBusy(state: AnimState): boolean {
  return state !== 'idle'
}

export function autoBackDelay(state: AnimState): number | null {
  if (state === 'talking') return TALKING_MS
  if (typeof state === 'object') return MOTION_DURATION[state.motion]
  return null
}

export function animClass(state: AnimState): string {
  if (typeof state === 'object') return `pet-img anim-${state.motion}`
  return `pet-img anim-${state}`
}
