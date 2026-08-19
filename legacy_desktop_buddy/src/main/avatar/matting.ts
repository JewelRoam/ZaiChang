import sharp from 'sharp'
import { writeFile } from 'node:fs/promises'

const TIMEOUT_MS = 60_000

const OPENAI_PROMPT =
  'Remove the background completely. Keep only the main character/person subject, ' +
  'preserve original colors and details, output PNG with fully transparent background.'

interface MattingOptions {
  url: string
  style: 'rembg' | 'openai'
  apiKey: string
  srcPath: string
  outPath: string
}

export async function removeBackground(opts: MattingOptions): Promise<void> {
  if (!opts.url) throw new Error('未配置抠图接口地址')

  const png = await sharp(opts.srcPath).png().toBuffer()
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS)
  try {
    const result =
      opts.style === 'rembg'
        ? await postRembg(opts, png, controller.signal)
        : await postOpenAiEdit(opts, png, controller.signal)

    const out = await sharp(result).ensureAlpha().png().toBuffer()
    if (await isFullyOpaque(out)) {
      // 中转服务把请求丢给不支持抠图的模型、原样回吐原图是常见失败模式，
      // 不校验的话用户看到「成功但没变化」，比直接报错更难排查
      throw new Error('接口返回的图片没有透明背景，它可能不是抠图服务')
    }
    await writeFile(opts.outPath, out)
  } catch (e) {
    if (e instanceof Error && e.name === 'AbortError') throw new Error('抠图超时（60s）')
    throw e
  } finally {
    clearTimeout(timer)
  }
}

async function postRembg(
  opts: MattingOptions,
  png: Buffer,
  signal: AbortSignal
): Promise<Buffer> {
  const form = new FormData()
  form.append('file', new Blob([png], { type: 'image/png' }), 'input.png')
  const headers: Record<string, string> = {}
  if (opts.apiKey) headers['Authorization'] = `Bearer ${opts.apiKey}`

  const res = await fetch(opts.url, { method: 'POST', headers, body: form, signal })
  if (!res.ok) {
    throw new Error(
      res.status === 401 || res.status === 403
        ? '抠图接口鉴权失败'
        : `抠图接口返回 HTTP ${res.status}`
    )
  }
  const type = res.headers.get('content-type') ?? ''
  if (type.includes('application/json')) {
    // 有些服务返回 { data: { image_base64 } } 之类的包装
    const json = (await res.json()) as Record<string, unknown>
    const b64 = findBase64(json)
    if (!b64) throw new Error('抠图接口返回了 JSON，但里面找不到图片数据')
    return Buffer.from(b64, 'base64')
  }
  return Buffer.from(await res.arrayBuffer())
}

async function postOpenAiEdit(
  opts: MattingOptions,
  png: Buffer,
  signal: AbortSignal
): Promise<Buffer> {
  const form = new FormData()
  form.append('image', new Blob([png], { type: 'image/png' }), 'input.png')
  form.append('prompt', OPENAI_PROMPT)
  form.append('size', '1024x1024')

  const url = new URL('images/edits', opts.url.replace(/\/?$/, '/')).toString()
  const res = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${opts.apiKey}` },
    body: form,
    signal
  })
  if (!res.ok) {
    throw new Error(
      res.status === 401 || res.status === 403
        ? '图像接口鉴权失败'
        : `图像接口返回 HTTP ${res.status}`
    )
  }
  const json = (await res.json()) as { data?: Array<{ b64_json?: string; url?: string }> }
  const item = json.data?.[0]
  if (item?.b64_json) return Buffer.from(item.b64_json, 'base64')
  if (item?.url) {
    const img = await fetch(item.url, { signal })
    if (!img.ok) throw new Error('下载抠图结果失败')
    return Buffer.from(await img.arrayBuffer())
  }
  throw new Error('图像接口未返回结果')
}

/** alpha 通道最小值为 255 说明全不透明，即没有抠掉任何背景 */
async function isFullyOpaque(png: Buffer): Promise<boolean> {
  const stats = await sharp(png).stats()
  const alpha = stats.channels[3]
  return !alpha || alpha.min === 255
}

/**
 * 从任意结构的 JSON 里找出图片数据：先按 base64 字符集筛候选，
 * 再用解码后的魔数确认真是图片，避免把 id、token 之类的长字符串当成图。
 */
function findBase64(obj: unknown, depth = 0): string | null {
  if (depth > 4 || obj === null || typeof obj !== 'object') return null
  for (const value of Object.values(obj as Record<string, unknown>)) {
    if (typeof value === 'string' && value.length >= 64) {
      const cleaned = value.replace(/^data:image\/\w+;base64,/, '').replace(/\s/g, '')
      if (/^[A-Za-z0-9+/]+={0,2}$/.test(cleaned) && looksLikeImage(cleaned)) return cleaned
    }
    const nested = findBase64(value, depth + 1)
    if (nested) return nested
  }
  return null
}

function looksLikeImage(b64: string): boolean {
  let head: Buffer
  try {
    head = Buffer.from(b64.slice(0, 32), 'base64')
  } catch {
    return false
  }
  const png = head[0] === 0x89 && head[1] === 0x50 && head[2] === 0x4e && head[3] === 0x47
  const jpeg = head[0] === 0xff && head[1] === 0xd8
  const webp = head.subarray(0, 4).toString('ascii') === 'RIFF'
  return png || jpeg || webp
}
