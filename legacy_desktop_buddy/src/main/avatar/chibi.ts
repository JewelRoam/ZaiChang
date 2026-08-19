import sharp from 'sharp'
import { writeFile } from 'node:fs/promises'

/** 头部占原图高度的比例（硬假设，见 doc 4.3） */
const HEAD_RATIO = 0.45
const HEAD_SCALE = 1.35
const BODY_SQUEEZE = 0.7

/**
 * 本地程序化「卡通化」：头部区域放大、身体压缩、饱和度提升。
 * 不做人脸检测，对半身像效果尚可，对全身/多人/风景图会变形。
 */
export async function generateChibiLocal(srcPath: string, outPath: string): Promise<void> {
  const meta = await sharp(srcPath).metadata()
  const W = meta.width ?? 0
  const H = meta.height ?? 0
  if (!W || !H) throw new Error('无法读取图片尺寸')

  const headH = Math.max(1, Math.round(H * HEAD_RATIO))
  const bodyH = H - headH

  const headW = Math.round(W * HEAD_SCALE)
  const scaledHeadH = Math.round(headH * HEAD_SCALE)

  const head = await sharp(srcPath)
    .extract({ left: 0, top: 0, width: W, height: headH })
    .resize({ width: headW, height: scaledHeadH })
    .toBuffer()

  const canvasW = headW
  let composites: sharp.OverlayOptions[] = [{ input: head, top: 0, left: 0 }]
  let canvasH = scaledHeadH

  if (bodyH > 0) {
    const squeezedBodyH = Math.max(1, Math.round(bodyH * BODY_SQUEEZE))
    const body = await sharp(srcPath)
      .extract({ left: 0, top: headH, width: W, height: bodyH })
      .resize({ width: W, height: squeezedBodyH })
      .toBuffer()
    canvasH = scaledHeadH + squeezedBodyH
    composites = [
      { input: head, top: 0, left: 0 },
      { input: body, top: scaledHeadH, left: Math.round((canvasW - W) / 2) }
    ]
  }

  const out = await sharp({
    create: {
      width: canvasW,
      height: canvasH,
      channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 }
    }
  })
    .composite(composites)
    .modulate({ saturation: 1.25 })
    .png()
    .toBuffer()

  await writeFile(outPath, out)
}

interface AiChibiOptions {
  baseUrl: string
  apiKey: string
  model: string
  srcPath: string
  outPath: string
  style: 'openai' | 'dashscope'
  endpoint: string
}

/** qwen 系列对中文提示词的语义遵循明显好于英文，所以 DashScope 走中文 */
const AI_PROMPT_ZH = [
  '把画面中的人物改成可爱的 Q 版卡通形象：',
  '头部放大，头身比约 1:1.2，四肢短小圆润；',
  '五官简化但保留原有发型、发色、服装配色和标志性配饰，让人一眼认得出是同一个角色；',
  '线条干净，柔和的赛璐璐上色，颜色明亮饱和，表情友好；',
  '纯白色背景，全身，正面朝向观众，居中构图；',
  '不要文字、不要水印、不要边框、不要多余人物。'
].join('')

const AI_PROMPT = [
  'Redraw this character as a cute chibi-style mascot sticker.',
  'Proportions: oversized head roughly the same height as the whole body (head-to-body ratio about 1:1.2), short limbs.',
  'Keep the original hair color, hairstyle, outfit colors and any distinctive accessories recognizable.',
  'Style: clean simplified lineart, soft cel shading, bright saturated colors, big expressive eyes, friendly expression.',
  'Background: fully transparent. No text, no watermark, no frame, no extra characters.',
  'Full body, facing viewer, centered.'
].join(' ')

/** 图像生成比对话慢得多，给 90s */
const IMAGE_TIMEOUT_MS = 90_000

export async function generateChibiAI(opts: AiChibiOptions): Promise<void> {
  if (opts.style === 'dashscope') return generateChibiDashScope(opts)
  return generateChibiOpenAi(opts)
}

async function readErrorDetail(res: Response): Promise<string> {
  return res.text().then(
    (t) => {
      try {
        const j = JSON.parse(t) as { error?: { message?: string }; message?: string }
        return j.error?.message ?? j.message ?? t.slice(0, 200)
      } catch {
        return t.slice(0, 200)
      }
    },
    () => ''
  )
}

/** 把 HTTP 状态映射成用户能照着行动的提示 */
function imageHttpError(status: number, detail: string, style: string): Error {
  if (status === 401 || status === 403) {
    return new Error(
      style === 'dashscope'
        ? '鉴权失败：检查 apiKey，以及地域是否对得上（北京和新加坡的 key 与地址不能混用）'
        : '图像接口鉴权失败'
    )
  }
  if (status === 404) {
    return new Error('地址不对（404）：DashScope 需要填带路径的完整地址，去阿里云文档页复制 HTTP 调用地址')
  }
  if (status === 429) {
    return new Error('限流了：图像编辑一分钟只能生成 2 张，等一会儿再点')
  }
  return new Error(`图像接口返回 ${status}${detail ? `：${detail}` : ''}`)
}

/** 百炼 DashScope 原生多模态生成：JSON 请求体、base64 传图、返回 OSS 临时 URL */
async function generateChibiDashScope(opts: AiChibiOptions): Promise<void> {
  const { apiKey, model, srcPath, outPath, endpoint } = opts
  if (!endpoint) throw new Error('未配置图像接口地址')
  if (!apiKey) throw new Error('未配置 apiKey')

  const b64 = (await sharp(srcPath).png().toBuffer()).toString('base64')
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), IMAGE_TIMEOUT_MS)
  try {
    const res = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({
        model: model || 'qwen-image-edit-plus',
        input: {
          messages: [
            {
              role: 'user',
              content: [{ image: `data:image/png;base64,${b64}` }, { text: AI_PROMPT_ZH }]
            }
          ]
        },
        parameters: { n: 1, watermark: false, prompt_extend: true, size: '1024*1024' }
      }),
      signal: controller.signal
    })
    if (!res.ok) throw imageHttpError(res.status, await readErrorDetail(res), 'dashscope')

    const json = (await res.json()) as unknown
    const found = findImageData(json)
    if (!found) {
      console.error('[chibi] 响应里没找到图片', JSON.stringify(json).slice(0, 200))
      throw new Error('接口返回里没有图片数据，可能是模型名不对或响应格式变了')
    }
    if (found.kind === 'base64') {
      await writeFile(outPath, Buffer.from(found.value, 'base64'))
      return
    }
    // OSS 临时 URL 24 小时后失效，必须立刻下载转存
    const img = await fetch(found.value, { signal: controller.signal })
    if (!img.ok) throw new Error('生成成功但下载结果失败（这次调用已计费，可以重试）')
    await writeFile(outPath, Buffer.from(await img.arrayBuffer()))
  } catch (e) {
    if (e instanceof Error && e.name === 'AbortError') throw new Error('图像生成超时（90s）')
    throw e
  } finally {
    clearTimeout(timer)
  }
}

/**
 * 递归找响应里的图片（URL 或 base64）。
 * 不死绑 output.choices[0].message.content[0].image：阿里云的响应字段改过多次，
 * 死绑路径会让一次小改动直接打断功能。
 */
function findImageData(
  obj: unknown,
  depth = 0
): { kind: 'url' | 'base64'; value: string } | null {
  if (depth > 8 || obj === null) return null
  if (typeof obj === 'string') {
    if (/^https?:\/\//i.test(obj)) return { kind: 'url', value: obj }
    const cleaned = obj.replace(/^data:image\/\w+;base64,/, '')
    // 用魔数确认真是图片，而不是靠长度猜，避免把 request_id 之类的长串当成图
    if (cleaned.length >= 64 && /^[A-Za-z0-9+/]+={0,2}$/.test(cleaned) && looksLikeImage(cleaned)) {
      return { kind: 'base64', value: cleaned }
    }
    return null
  }
  if (Array.isArray(obj)) {
    for (const item of obj) {
      const hit = findImageData(item, depth + 1)
      if (hit) return hit
    }
    return null
  }
  if (typeof obj === 'object') {
    // 优先看名字像图片的字段，避免误取 request_id 之类
    const entries = Object.entries(obj as Record<string, unknown>).sort(
      ([a], [b]) => Number(/image|url|b64/i.test(b)) - Number(/image|url|b64/i.test(a))
    )
    for (const [, value] of entries) {
      const hit = findImageData(value, depth + 1)
      if (hit) return hit
    }
  }
  return null
}

/** 解码前 32 字节看魔数，判断是不是 PNG / JPEG / WebP */
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

/** OpenAI 兼容的 images/edits */
async function generateChibiOpenAi(opts: AiChibiOptions): Promise<void> {
  const { baseUrl, apiKey, model, srcPath, outPath } = opts
  if (!baseUrl || !apiKey) throw new Error('未配置图像接口地址或 apiKey')

  const png = await sharp(srcPath).png().toBuffer()
  const form = new FormData()
  form.append('image', new Blob([png], { type: 'image/png' }), 'avatar.png')
  form.append('prompt', AI_PROMPT)
  form.append('model', model || 'gpt-image-1')
  form.append('size', '1024x1024')

  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), IMAGE_TIMEOUT_MS)
  try {
    const res = await fetch(new URL('images/edits', baseUrl.replace(/\/?$/, '/')).toString(), {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}` },
      body: form,
      signal: controller.signal
    })
    if (!res.ok) throw imageHttpError(res.status, await readErrorDetail(res), 'openai')
    const json = (await res.json()) as { data?: Array<{ b64_json?: string; url?: string }> }
    const item = json.data?.[0]
    if (item?.b64_json) {
      await writeFile(outPath, Buffer.from(item.b64_json, 'base64'))
      return
    }
    if (item?.url) {
      const imgRes = await fetch(item.url, { signal: controller.signal })
      if (!imgRes.ok) throw new Error('下载生成结果失败')
      await writeFile(outPath, Buffer.from(await imgRes.arrayBuffer()))
      return
    }
    throw new Error('图像接口未返回结果')
  } catch (e) {
    if (e instanceof Error && e.name === 'AbortError') throw new Error('图像生成超时（90s）')

    throw e
  } finally {
    clearTimeout(timer)
  }
}
