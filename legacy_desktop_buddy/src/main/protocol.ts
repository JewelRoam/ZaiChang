import { protocol, net } from 'electron'
import { pathToFileURL } from 'node:url'
import { resolve, sep } from 'node:path'
import { avatarsDir } from './store'

export const BUDDY_SCHEME = 'buddy'

/** 必须在 app ready 之前调用 */
export function registerBuddyScheme(): void {
  protocol.registerSchemesAsPrivileged([
    { scheme: BUDDY_SCHEME, privileges: { standard: true, secure: true, supportFetchAPI: true } }
  ])
}

/**
 * 把本地素材路径转成渲染进程可用的 url。
 * 带上 mtime 作为版本号，避免重新生成 Q 版后浏览器读缓存拿到旧图。
 */
export function toBuddyUrl(absPath: string, version: number | string = Date.now()): string {
  return `${BUDDY_SCHEME}://local/?p=${encodeURIComponent(absPath)}&v=${version}`
}

/** 只允许读取 avatars 目录下的文件，防止渲染进程借这个协议读任意本地文件 */
export function registerBuddyProtocolHandler(): void {
  protocol.handle(BUDDY_SCHEME, async (request) => {
    const target = new URL(request.url).searchParams.get('p')
    if (!target) return new Response('missing path', { status: 400 })

    const abs = resolve(target)
    const root = resolve(avatarsDir())
    if (abs !== root && !abs.startsWith(root + sep)) {
      return new Response('forbidden', { status: 403 })
    }
    try {
      return await net.fetch(pathToFileURL(abs).toString())
    } catch {
      return new Response('not found', { status: 404 })
    }
  })
}
