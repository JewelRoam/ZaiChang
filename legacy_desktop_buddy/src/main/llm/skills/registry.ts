import type { SkillDef } from '@shared/types'
import { listReminders, scheduleReminder } from '../../scheduler'
import { openTarget } from './launcher'
import { memoSkills } from './memo'

export const skills: SkillDef[] = [
  {
    name: 'set_reminder',
    description: '在指定时间或多少分钟后提醒用户做某件事。二者给其中一个即可。',
    parameters: {
      type: 'object',
      required: ['content'],
      properties: {
        content: { type: 'string', description: '提醒的内容，比如「喝水」' },
        delayMinutes: { type: 'number', description: '多少分钟后提醒' },
        atTime: { type: 'string', description: '提醒时间，HH:mm 或 YYYY-MM-DD HH:mm' }
      }
    },
    run: (args) => scheduleReminder(args)
  },
  {
    name: 'open_target',
    description: '打开一个网址，或者启动 /Applications 下的 macOS 应用',
    parameters: {
      type: 'object',
      required: ['target'],
      properties: {
        target: { type: 'string', description: 'http(s) 网址，或 /Applications/Xxx.app' }
      }
    },
    run: (args) => openTarget((args as { target?: unknown }).target)
  },
  {
    name: 'list_reminders',
    description: '列出当前所有还没触发的提醒',
    parameters: { type: 'object', properties: {} },
    run: () => listReminders()
  },
  ...memoSkills
]

export function findSkill(name: string): SkillDef | undefined {
  return skills.find((s) => s.name === name)
}

export function toolSchemas(): Array<Record<string, unknown>> {
  return skills.map((s) => ({
    type: 'function',
    function: { name: s.name, description: s.description, parameters: s.parameters }
  }))
}
