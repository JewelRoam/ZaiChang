import { getMemoConfig } from '../store'
import { pushBubble } from '../bubble'
import { openMemo } from '../windows/memoWindow'
import { getLastPopupDate, markPopupShown, pendingRemindersToday, todayStr } from './store'

const CHECK_INTERVAL_MS = 60_000

const timers = new Map<string, NodeJS.Timeout>()
let poller: NodeJS.Timeout | null = null

function minutesOfDay(hhmm: string): number {
  const [h, m] = hhmm.split(':').map(Number)
  return h * 60 + m
}

function nowMinutes(): number {
  const d = new Date()
  return d.getHours() * 60 + d.getMinutes()
}

/**
 * 每分钟轮询 + 当日标记，而不是 setTimeout 到点触发。
 * 原因：macOS 睡眠唤醒后长定时器不可靠，睡过头就永远不弹了。
 */
function tick(): void {
  const cfg = getMemoConfig()
  if (!cfg.enabled) return
  const today = todayStr()
  if (getLastPopupDate() === today) return
  if (nowMinutes() < minutesOfDay(cfg.popupTime)) return
  markPopupShown(today)
  openMemo()
}

export function scheduleTodoReminder(id: string, remindAt: number | null, text: string): void {
  const existing = timers.get(id)
  if (existing) {
    clearTimeout(existing)
    timers.delete(id)
  }
  if (remindAt === null) return
  const delay = remindAt - Date.now()
  if (delay <= 0) return
  timers.set(
    id,
    setTimeout(() => {
      timers.delete(id)
      pushBubble(`📝 该做这件事了：${text}`, 8000)
    }, delay)
  )
}

/** todo 是持久化的、定时器是内存态的，所以启动时必须重建，否则重启后提醒全丢 */
export function initMemoSchedule(): void {
  for (const t of pendingRemindersToday()) {
    scheduleTodoReminder(t.id, t.remindAt, t.text)
  }
  tick()
  poller = setInterval(tick, CHECK_INTERVAL_MS)
}

export function stopMemoSchedule(): void {
  if (poller) clearInterval(poller)
  poller = null
  timers.forEach((t) => clearTimeout(t))
  timers.clear()
}
