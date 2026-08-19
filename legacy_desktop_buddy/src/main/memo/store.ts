import { app } from 'electron'
import { randomUUID } from 'node:crypto'
import { copyFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import type { Todo } from '@shared/types'

const MAX_TEXT = 200

interface MemoFile {
  todos: Todo[]
  lastPopupDate: string | null
}

let cache: MemoFile | null = null

function filePath(): string {
  return join(app.getPath('userData'), 'memo.json')
}

export function todayStr(d = new Date()): string {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

function load(): MemoFile {
  if (cache) return cache
  const p = filePath()
  if (!existsSync(p)) {
    cache = { todos: [], lastPopupDate: null }
    return cache
  }
  try {
    const parsed = JSON.parse(readFileSync(p, 'utf-8')) as MemoFile
    cache = {
      todos: Array.isArray(parsed.todos) ? parsed.todos : [],
      lastPopupDate: typeof parsed.lastPopupDate === 'string' ? parsed.lastPopupDate : null
    }
  } catch (e) {
    // 损坏时备份后以空列表启动，不能因为一个坏文件让应用起不来
    console.error('[memo] memo.json 解析失败，已备份为 memo.json.bak', e)
    try {
      copyFileSync(p, `${p}.bak`)
    } catch {
      /* 备份失败也继续 */
    }
    cache = { todos: [], lastPopupDate: null }
  }
  return cache
}

function save(): void {
  const data = load()
  writeFileSync(filePath(), JSON.stringify(data, null, 2), 'utf-8')
}

export function listTodos(date = todayStr()): Todo[] {
  return load()
    .todos.filter((t) => t.date === date)
    .sort((a, b) => Number(a.done) - Number(b.done) || (a.remindAt ?? 0) - (b.remindAt ?? 0))
}

export function addTodo(rawText: string, remindAt: number | null = null): Todo | null {
  const text = rawText.trim().slice(0, MAX_TEXT)
  if (!text) return null
  const todo: Todo = { id: randomUUID(), text, done: false, date: todayStr(), remindAt }
  load().todos.push(todo)
  save()
  return todo
}

export function toggleTodo(id: string, done?: boolean): void {
  const t = load().todos.find((x) => x.id === id)
  if (!t) return
  t.done = done ?? !t.done
  save()
}

export function removeTodo(id: string): void {
  const data = load()
  data.todos = data.todos.filter((t) => t.id !== id)
  save()
}

export function setTodoRemind(id: string, remindAt: number | null): Todo | null {
  const t = load().todos.find((x) => x.id === id)
  if (!t) return null
  t.remindAt = remindAt
  save()
  return t
}

/**
 * 把过往未完成的 todo 复制成今天的条目，原条目标记完成。
 * 标记原条目是为了避免同一件事每天复制一份、越滚越多。
 */
export function carryOverTodos(): number {
  const data = load()
  const today = todayStr()
  const pending = data.todos.filter((t) => !t.done && t.date < today)
  if (pending.length === 0) return 0
  for (const old of pending) {
    data.todos.push({
      id: randomUUID(),
      text: old.text,
      done: false,
      date: today,
      remindAt: null,
      carriedFrom: old.carriedFrom ?? old.date
    })
    old.done = true
  }
  save()
  return pending.length
}

export function getLastPopupDate(): string | null {
  return load().lastPopupDate
}

export function markPopupShown(date = todayStr()): void {
  load().lastPopupDate = date
  save()
}

/** 今天所有还没到点的提醒，用于启动时重建定时器 */
export function pendingRemindersToday(): Todo[] {
  const now = Date.now()
  return load().todos.filter(
    (t) => t.date === todayStr() && !t.done && t.remindAt !== null && t.remindAt > now
  )
}
