import type { SkillDef } from '@shared/types'
import { addTodo, listTodos } from '../../memo/store'
import { scheduleTodoReminder } from '../../memo/schedule'
import { notifyMemoChanged } from '../../memo/notify'

export const memoSkills: SkillDef[] = [
  {
    name: 'add_todo',
    description: '把一件事记进今日备忘录，可选给这条设一个提醒时间',
    parameters: {
      type: 'object',
      required: ['text'],
      properties: {
        text: { type: 'string', description: '要记下来的事情' },
        remindMinutes: { type: 'number', description: '多少分钟后提醒这条（可选）' }
      }
    },
    run: (args) => {
      const text = typeof args.text === 'string' ? args.text : ''
      const mins =
        typeof args.remindMinutes === 'number' && args.remindMinutes > 0
          ? args.remindMinutes
          : null
      const todo = addTodo(text, mins === null ? null : Date.now() + mins * 60_000)
      if (!todo) return '要记什么？内容是空的'
      if (todo.remindAt) scheduleTodoReminder(todo.id, todo.remindAt, todo.text)
      notifyMemoChanged()
      return `记下了：${todo.text}${todo.remindAt ? `，${mins} 分钟后提醒你` : ''}`
    }
  },
  {
    name: 'list_todos',
    description: '列出今天备忘录里的事项',
    parameters: { type: 'object', properties: {} },
    run: () => {
      const items = listTodos()
      if (items.length === 0) return '今天的备忘录还是空的'
      return items.map((t) => `${t.done ? '✓' : '○'} ${t.text}`).join('；')
    }
  }
]
