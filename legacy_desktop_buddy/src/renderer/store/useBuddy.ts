import { create } from 'zustand'
import type { ActiveAvatar, BuddyStatus, LineStyle, MotionFreq, MotionName } from '@shared/types'
import type { AnimState } from '../anim/state'
import { autoBackDelay, isBusy } from '../anim/state'
import type { LinePools } from '../env'

export interface UiMessage {
  id: number
  role: 'user' | 'buddy'
  text: string
}

interface BuddyState {
  avatar: ActiveAvatar
  anim: AnimState
  bubble: string | null
  panelOpen: boolean
  messages: UiMessage[]
  sending: boolean
  lines: LinePools | null
  lastClickLine: string | null
  /** 当前性格的语录/动作风格，决定动作池和节奏 */
  motionStyle: LineStyle
  motionFreq: MotionFreq
  allowMove: boolean
  status: BuddyStatus | null
  setStatus: (s: BuddyStatus) => void
  setMotionStyle: (s: LineStyle) => void
  setMotionConfig: (c: { freq: MotionFreq; allowMove: boolean }) => void

  setAvatar: (a: ActiveAvatar) => void
  setAnim: (s: AnimState) => void
  /** 播一个动作；正在忙（说话/思考/其他动作）时忽略，避免抽搐 */
  playMotion: (name: MotionName) => boolean
  lastMotion: MotionName | null
  showBubble: (text: string, durationMs?: number) => void
  hideBubble: () => void
  togglePanel: () => void
  setPanelOpen: (v: boolean) => void
  addMessage: (role: UiMessage['role'], text: string) => void
  setSending: (v: boolean) => void
  setLines: (l: LinePools) => void
  /** 从池子里随机取一句，连续两次不重复 */
  pickLine: (pool: 'welcome' | 'click' | 'idle' | 'error' | 'thinking') => string | null
}

let bubbleTimer: ReturnType<typeof setTimeout> | null = null
let animTimer: ReturnType<typeof setTimeout> | null = null
let msgSeq = 0

export const useBuddy = create<BuddyState>((set, get) => ({
  avatar: { id: null, form: 'original', url: null },
  anim: 'idle',
  bubble: null,
  panelOpen: false,
  messages: [],
  sending: false,
  lines: null,
  lastClickLine: null,
  lastMotion: null,
  motionStyle: 'default',
  motionFreq: 'normal',
  allowMove: false,
  status: null,

  setStatus: (s) => set({ status: s }),

  setMotionStyle: (s) => set({ motionStyle: s }),
  setMotionConfig: (c) => set({ motionFreq: c.freq, allowMove: c.allowMove }),

  setAvatar: (a) => set({ avatar: a }),

  setAnim: (s) => {
    if (animTimer) clearTimeout(animTimer)
    set({ anim: s })
    const delay = autoBackDelay(s)
    if (delay) {
      animTimer = setTimeout(() => set({ anim: 'idle' }), delay)
    }
  },

  playMotion: (name) => {
    if (isBusy(get().anim)) return false
    set({ lastMotion: name })
    get().setAnim({ motion: name })
    return true
  },

  showBubble: (text, durationMs = 3000) => {
    if (bubbleTimer) clearTimeout(bubbleTimer)
    set({ bubble: text })
    bubbleTimer = setTimeout(() => set({ bubble: null }), durationMs)
  },

  hideBubble: () => {
    if (bubbleTimer) clearTimeout(bubbleTimer)
    set({ bubble: null })
  },

  togglePanel: () => set((s) => ({ panelOpen: !s.panelOpen })),
  setPanelOpen: (v) => set({ panelOpen: v }),

  addMessage: (role, text) =>
    set((s) => ({ messages: [...s.messages, { id: ++msgSeq, role, text }].slice(-50) })),

  setSending: (v) => set({ sending: v }),
  setLines: (l) => set({ lines: l }),

  pickLine: (pool) => {
    const lines = get().lines
    if (!lines) return null
    const status = get().status
    // 情绪命中时 60% 概率走情绪池：性格才是核心，情绪只是调味，
    // 全部替换会让用户觉得"我写的性格没生效"
    if (status && (pool === 'click' || pool === 'idle')) {
      const moodPool =
        status.mood === 'sleepy' || status.mood === 'lonely' || status.mood === 'happy'
          ? lines.moods?.[status.mood]
          : undefined
      if (moodPool && moodPool.length > 0 && Math.random() < 0.6) {
        return moodPool[Math.floor(Math.random() * moodPool.length)]
      }
    }
    const list = lines[pool] ?? []
    if (list.length === 0) return null
    if (list.length === 1) return list[0]
    const last = get().lastClickLine
    let line = list[Math.floor(Math.random() * list.length)]
    let guard = 0
    while (line === last && guard++ < 5) {
      line = list[Math.floor(Math.random() * list.length)]
    }
    if (pool === 'click') set({ lastClickLine: line })
    return line
  }
}))
