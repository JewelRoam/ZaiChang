import { shell } from 'electron'
import { existsSync } from 'node:fs'
import { resolve } from 'node:path'

/**
 * 唯一能影响系统外部的能力，因此做白名单：
 * 只允许 http(s) 链接，以及 /Applications 下的 .app。
 * 绝不拼接 shell 命令，模型返回什么都不能绕过这里。
 */
export async function openTarget(rawTarget: unknown): Promise<string> {
  const target = typeof rawTarget === 'string' ? rawTarget.trim() : ''
  if (!target) return '你没告诉我要打开啥'

  if (/^https?:\/\//i.test(target)) {
    let url: URL
    try {
      url = new URL(target)
    } catch {
      return '这个网址我看不懂'
    }
    await shell.openExternal(url.toString())
    return `已经帮你打开 ${url.hostname} 了`
  }

  const abs = resolve(target)
  if (/^\/Applications\/[^/]+\.app\/?$/.test(abs) && existsSync(abs)) {
    const err = await shell.openPath(abs)
    if (err) return `打不开这个应用：${err}`
    return `已经帮你启动 ${abs.replace('/Applications/', '').replace('.app', '')} 了`
  }

  return '这个我打不开，只能开网页或者 /Applications 里的应用'
}
