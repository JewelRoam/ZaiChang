import { useEffect, useState } from 'react'
import type { Todo } from '@shared/types'

/** 'HH:mm' -> 今天该时刻的时间戳；已过则返回 null */
function toTimestamp(hhmm: string): number | null {
  const m = hhmm.match(/^(\d{1,2}):(\d{2})$/)
  if (!m) return null
  const d = new Date()
  d.setHours(Number(m[1]), Number(m[2]), 0, 0)
  return d.getTime() > Date.now() ? d.getTime() : null
}

function fmt(ts: number): string {
  const d = new Date(ts)
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
}

export function MemoView(): JSX.Element {
  const [todos, setTodos] = useState<Todo[]>([])
  const [text, setText] = useState('')
  const [editing, setEditing] = useState<string | null>(null)
  const [timeInput, setTimeInput] = useState('')
  const [warn, setWarn] = useState('')

  useEffect(() => {
    void window.buddy.listTodos().then(setTodos)
    return window.buddy.onMemoRefresh(() => {
      void window.buddy.listTodos().then(setTodos)
    })
  }, [])

  const add = async (): Promise<void> => {
    const value = text.trim()
    if (!value) return
    setText('')
    setTodos(await window.buddy.addTodo(value, null))
  }

  const applyRemind = async (id: string): Promise<void> => {
    const ts = toTimestamp(timeInput)
    if (timeInput && ts === null) {
      setWarn('时间格式是 HH:mm，而且得是今天还没到的时刻')
      return
    }
    setWarn('')
    setEditing(null)
    setTimeInput('')
    setTodos(await window.buddy.setTodoRemind(id, ts))
  }

  const undone = todos.filter((t) => !t.done).length

  return (
    <div className="memo">
      <header>
        <h1>今日备忘</h1>
        <span className="count">{undone} 件待办</span>
      </header>

      <div className="adder">
        <input
          value={text}
          placeholder="今天要做什么…"
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.nativeEvent.isComposing) void add()
          }}
        />
        <button className="primary" disabled={!text.trim()} onClick={add}>
          添加
        </button>
      </div>

      {warn && <div className="warn">{warn}</div>}

      <ul className="list">
        {todos.length === 0 && <li className="empty">今天还没记事情</li>}
        {todos.map((t) => (
          <li key={t.id} className={t.done ? 'done' : ''}>
            <input
              type="checkbox"
              checked={t.done}
              onChange={async () => setTodos(await window.buddy.toggleTodo(t.id))}
            />
            <span className="text">
              {t.carriedFrom && <em className="badge" title={`来自 ${t.carriedFrom}`}>昨</em>}
              {t.text}
            </span>
            {t.remindAt && !t.done && <span className="at">{fmt(t.remindAt)}</span>}
            {editing === t.id ? (
              <span className="edit">
                <input
                  className="time"
                  value={timeInput}
                  placeholder="09:30"
                  autoFocus
                  onChange={(e) => setTimeInput(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') void applyRemind(t.id)
                    if (e.key === 'Escape') setEditing(null)
                  }}
                />
                <button onClick={() => applyRemind(t.id)}>确定</button>
              </span>
            ) : (
              <button
                className="ghost"
                title="设置提醒时间"
                onClick={() => {
                  setEditing(t.id)
                  setTimeInput(t.remindAt ? fmt(t.remindAt) : '')
                }}
              >
                ⏰
              </button>
            )}
            <button
              className="ghost"
              title="删除"
              onClick={async () => setTodos(await window.buddy.removeTodo(t.id))}
            >
              ×
            </button>
          </li>
        ))}
      </ul>

      <footer>提醒只在应用运行期间有效；未完成的事项明天会自动带过来。</footer>
    </div>
  )
}
