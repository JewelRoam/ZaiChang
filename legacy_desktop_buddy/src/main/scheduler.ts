import { randomUUID } from 'node:crypto'
import type { Reminder } from '@shared/types'
import { pushBubble } from './bubble'

const reminders = new Map<string, { reminder: Reminder; timer: NodeJS.Timeout }>()

/** setTimeout 上限约 24.8 天，超过会立即触发，这里直接拒绝 */
const MAX_DELAY_MS = 20 * 24 * 60 * 60 * 1000

interface ScheduleArgs {
  content?: unknown
  delayMinutes?: unknown
  atTime?: unknown
}

/** 解析 HH:mm 或 YYYY-MM-DD HH:mm；HH:mm 若已过则视为明天 */
function parseAtTime(raw: string): number | null {
  const hm = raw.match(/^(\d{1,2}):(\d{2})$/)
  if (hm) {
    const d = new Date()
    d.setHours(Number(hm[1]), Number(hm[2]), 0, 0)
    if (d.getTime() <= Date.now()) d.setDate(d.getDate() + 1)
    return d.getTime()
  }
  const ts = Date.parse(raw.replace(' ', 'T'))
  return Number.isNaN(ts) ? null : ts
}

export function scheduleReminder(args: ScheduleArgs): string {
  const content = typeof args.content === 'string' ? args.content.trim() : ''
  if (!content) return '没听懂要提醒你啥，再说一遍？'

  let fireAt: number | null = null
  if (typeof args.delayMinutes === 'number' && Number.isFinite(args.delayMinutes)) {
    if (args.delayMinutes <= 0) return '时间得是未来的呀'
    fireAt = Date.now() + args.delayMinutes * 60_000
  } else if (typeof args.atTime === 'string' && args.atTime.trim()) {
    fireAt = parseAtTime(args.atTime.trim())
    if (fireAt === null) return '这个时间我没看懂，说个具体点的？'
    if (fireAt <= Date.now()) return '这个时间已经过去了'
  }
  if (fireAt === null) return '要几点提醒你？或者说过多少分钟'

  const delay = fireAt - Date.now()
  if (delay > MAX_DELAY_MS) return '太远了，20 天以内的我才记得住'

  const reminder: Reminder = { id: randomUUID(), content, fireAt }
  const timer = setTimeout(() => {
    reminders.delete(reminder.id)
    pushBubble(`⏰ 提醒你：${reminder.content}`, 8000)
  }, delay)
  reminders.set(reminder.id, { reminder, timer })

  const t = new Date(fireAt)
  const hh = String(t.getHours()).padStart(2, '0')
  const mm = String(t.getMinutes()).padStart(2, '0')
  return `好，${hh}:${mm} 提醒你「${content}」`
}

export function listReminders(): string {
  const items = [...reminders.values()]
    .map((v) => v.reminder)
    .sort((a, b) => a.fireAt - b.fireAt)
  if (items.length === 0) return '现在没有待办提醒'
  return items
    .map((r) => {
      const t = new Date(r.fireAt)
      return `${String(t.getHours()).padStart(2, '0')}:${String(t.getMinutes()).padStart(2, '0')} ${r.content}`
    })
    .join('；')
}

/** 提醒只存内存，退出即失效（MVP 不做持久化调度） */
export function clearAllReminders(): void {
  reminders.forEach((v) => clearTimeout(v.timer))
  reminders.clear()
}
