import { randomUUID } from 'node:crypto'
import { existsSync, statSync } from 'node:fs'
import { mkdir, rm, stat } from 'node:fs/promises'
import { basename, extname, join } from 'node:path'
import sharp from 'sharp'
import type {
  ActiveAvatar,
  AiChibiResult,
  AvatarForm,
  AvatarImportResult,
  AvatarMeta,
  AvatarPreview,
  Persona
} from '@shared/types'
import {
  avatarsDir,
  getAvatars,
  imageApiKey,
  getCurrentAvatarId,
  getEffectivePersona,
  getForm,
  getModelConfig,
  setAvatars,
  setCurrentAvatarId,
  setPersonaFor,
  setForm
} from '../store'
import { resetHistory } from '../llm/client'
import { generateChibiAI, generateChibiLocal } from './chibi'
import { removeBackground } from './matting'
import { toBuddyUrl } from '../protocol'

const ALLOWED_EXT = new Set(['.png', '.jpg', '.jpeg', '.webp'])
const MAX_BYTES = 10 * 1024 * 1024
const MIN_EDGE = 128
const MAX_EDGE = 4096
const TARGET_LONG_EDGE = 512

export async function importAvatar(filePath: string): Promise<AvatarImportResult> {
  const ext = extname(filePath).toLowerCase()
  if (!ALLOWED_EXT.has(ext)) {
    return { ok: false, error: '只支持 PNG / JPG / WebP 图片' }
  }
  const info = await stat(filePath).catch(() => null)
  if (!info?.isFile()) return { ok: false, error: '文件不存在' }
  if (info.size > MAX_BYTES) return { ok: false, error: '图片超过 10MB，换张小一点的' }

  const meta = await sharp(filePath)
    .metadata()
    .catch(() => null)
  const W = meta?.width ?? 0
  const H = meta?.height ?? 0
  if (!W || !H) return { ok: false, error: '这张图读不出来，可能已损坏' }
  const long = Math.max(W, H)
  if (Math.min(W, H) < MIN_EDGE) return { ok: false, error: `图片太小了，短边至少 ${MIN_EDGE}px` }
  if (long > MAX_EDGE) return { ok: false, error: `图片太大了，长边不要超过 ${MAX_EDGE}px` }

  const id = randomUUID()
  const dir = join(avatarsDir(), id)
  await mkdir(dir, { recursive: true })
  const originalPath = join(dir, 'original.png')
  const chibiPath = join(dir, 'chibi.png')

  try {
    const resizer =
      long > TARGET_LONG_EDGE
        ? sharp(filePath).resize(
            W >= H ? { width: TARGET_LONG_EDGE } : { height: TARGET_LONG_EDGE }
          )
        : sharp(filePath)
    await resizer.png().toFile(originalPath)
    await generateChibiLocal(originalPath, chibiPath)
  } catch (e) {
    await rm(dir, { recursive: true, force: true })
    return { ok: false, error: e instanceof Error ? e.message : '图片处理失败' }
  }

  const avatar: AvatarMeta = {
    id,
    name: basename(filePath, ext).slice(0, 20) || '未命名',
    createdAt: Date.now(),
    originalPath,
    chibiPath,
    chibiAiPath: null,
    cutoutPath: null,
    useCutout: false,
    persona: null
  }
  // 上传后不自动切换当前形象，交给用户显式选择
  setAvatars([...getAvatars(), avatar])
  return { ok: true, meta: avatar }
}

export function listAvatars(): AvatarMeta[] {
  return getAvatars().map((a) => ({ ...a, broken: !existsSync(a.originalPath) }))
}

export async function deleteAvatar(id: string): Promise<void> {
  setAvatars(getAvatars().filter((a) => a.id !== id))
  if (getCurrentAvatarId() === id) setCurrentAvatarId(null)
  await rm(join(avatarsDir(), id), { recursive: true, force: true })
}

export function switchAvatar(id: string | null, form?: AvatarForm): ActiveAvatar {
  if (id !== null && !getAvatars().some((a) => a.id === id)) {
    return getActiveAvatar()
  }
  const changed = getCurrentAvatarId() !== id
  setCurrentAvatarId(id)
  if (form) setForm(form)
  // 换形象等于换了个人格，旧对话历史留着会串味
  if (changed) resetHistory()
  return getActiveAvatar()
}

/** 当前生效的人格：形象没设置就用全局默认 */
export function getPersona(id?: string | null): Persona {
  return getEffectivePersona(id)
}

/** 写入某个形象的人格；id 为 null 时写全局默认人格。人格变了就清空对话历史 */
export function setPersona(id: string | null, patch: Partial<Persona>): Persona {
  const next = setPersonaFor(id, patch)
  resetHistory()
  return next
}

export function setAvatarForm(form: AvatarForm): ActiveAvatar {
  setForm(form)
  return getActiveAvatar()
}

/** 原始形态实际显示哪张图：抠图结果优先（若开启且存在） */
function baseImagePath(avatar: AvatarMeta): string {
  if (avatar.useCutout && avatar.cutoutPath && existsSync(avatar.cutoutPath)) {
    return avatar.cutoutPath
  }
  return avatar.originalPath
}

/** 解析当前应显示的图片；素材缺失则回退默认形象（url = null） */
export function getActiveAvatar(): ActiveAvatar {
  const form = getForm()
  const id = getCurrentAvatarId()
  const avatar = getAvatars().find((a) => a.id === id)
  if (!avatar) return { id: null, form, url: null }

  const candidates =
    form === 'chibi'
      ? [avatar.chibiAiPath, avatar.chibiPath, baseImagePath(avatar)]
      : [baseImagePath(avatar), avatar.originalPath]
  const hit = candidates.find((p): p is string => !!p && existsSync(p))
  if (!hit) {
    // 文件被外部删掉了，标记失效但不删记录，用户能在设置里看到并清理
    setAvatars(getAvatars().map((a) => (a.id === avatar.id ? { ...a, broken: true } : a)))
    return { id: avatar.id, form, url: null }
  }
  return { id: avatar.id, form, url: toBuddyUrl(hit, statSync(hit).mtimeMs) }
}

/** 设置页预览用：一次给出四种产物的地址，前端自己按形态选 */
export function getAvatarPreview(id: string): AvatarPreview {
  const avatar = getAvatars().find((a) => a.id === id)
  const url = (p: string | null | undefined): string | null =>
    p && existsSync(p) ? toBuddyUrl(p, statSync(p).mtimeMs) : null
  if (!avatar) return { original: null, cutout: null, chibi: null, chibiAi: null }
  return {
    original: url(avatar.originalPath),
    cutout: url(avatar.cutoutPath),
    chibi: url(avatar.chibiPath),
    chibiAi: url(avatar.chibiAiPath)
  }
}

/** AI 抠图：成功后默认启用抠图结果，并用它重建本地 Q 版 */
export async function removeAvatarBackground(
  id: string
): Promise<{ ok: boolean; error?: string }> {
  const avatar = getAvatars().find((a) => a.id === id)
  if (!avatar) return { ok: false, error: '形象不存在' }
  const cfg = getModelConfig()
  if (!cfg.mattingUrl) return { ok: false, error: '未配置抠图接口地址' }

  const outPath = join(avatarsDir(), id, 'cutout.png')
  try {
    await removeBackground({
      url: cfg.mattingUrl,
      style: cfg.mattingStyle,
      apiKey: imageApiKey(),
      srcPath: avatar.originalPath,
      outPath
    })
    await generateChibiLocal(outPath, avatar.chibiPath)
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : '抠图失败' }
  }
  setAvatars(
    getAvatars().map((a) => (a.id === id ? { ...a, cutoutPath: outPath, useCutout: true } : a))
  )
  return { ok: true }
}

export function setUseCutout(id: string, use: boolean): AvatarMeta[] {
  setAvatars(getAvatars().map((a) => (a.id === id ? { ...a, useCutout: use } : a)))
  return listAvatars()
}
export async function generateAiChibi(id: string): Promise<AiChibiResult> {
  const avatar = getAvatars().find((a) => a.id === id)
  if (!avatar) return { ok: false, error: '形象不存在' }
  if (avatar.chibiAiPath && existsSync(avatar.chibiAiPath)) return { ok: true }

  const cfg = getModelConfig()
  const hasEndpoint = cfg.imageStyle === 'dashscope' ? !!cfg.imageEndpoint : !!cfg.imageBaseUrl
  if (!hasEndpoint) return { ok: false, error: '未配置图像接口地址' }

  const outPath = join(avatarsDir(), id, 'chibi-ai.png')
  try {
    await generateChibiAI({
      baseUrl: cfg.imageBaseUrl,
      apiKey: imageApiKey(),
      model: cfg.imageModel,
      style: cfg.imageStyle,
      endpoint: cfg.imageEndpoint,
      // 用原图作为源：Q 版模型不保证输出透明背景，去背景放在生成之后做
      srcPath: avatar.originalPath,
      outPath
    })
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : 'AI Q 版生成失败' }
  }

  // 生成结果大概率带底色，配了抠图接口就自动去一次背景
  let warning: string | undefined
  if (cfg.mattingUrl) {
    try {
      await removeBackground({
        url: cfg.mattingUrl,
        style: cfg.mattingStyle,
        apiKey: imageApiKey(),
        srcPath: outPath,
        outPath
      })
    } catch (e) {
      // 这次生成已经计费了，不能因为抠图失败就丢弃结果
      warning = `Q 版生成好了，但自动去背景失败：${e instanceof Error ? e.message : '未知原因'}`
    }
  } else {
    warning = 'Q 版生成好了，但没配抠图接口，这张带背景。配上抠图接口后重新生成会更好'
  }

  setAvatars(getAvatars().map((a) => (a.id === id ? { ...a, chibiAiPath: outPath } : a)))
  return { ok: true, warning }
}

/** 强制重新生成：删掉已有 AI 产物再走一遍 */
export async function regenerateAiChibi(id: string): Promise<AiChibiResult> {
  const avatar = getAvatars().find((a) => a.id === id)
  if (avatar?.chibiAiPath) {
    await rm(avatar.chibiAiPath, { force: true })
    setAvatars(getAvatars().map((a) => (a.id === id ? { ...a, chibiAiPath: null } : a)))
  }
  return generateAiChibi(id)
}
