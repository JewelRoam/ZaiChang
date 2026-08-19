import { app } from 'electron'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import type { LineStyle, Persona } from '@shared/types'
import { getModelConfig } from '../store'

export interface LinePools {
  welcome: string[]
  click: string[]
  idle: string[]
  error: string[]
  thinking: string[]
  /** 情绪池：mood 命中时有一定概率替代性格语录 */
  moods: { sleepy: string[]; lonely: string[]; happy: string[] }
}

interface LinesFile {
  welcome: string[]
  error: string[]
  thinking: string[]
  styles: Record<string, { click: string[]; idle: string[] }>
  moods?: { sleepy: string[]; lonely: string[]; happy: string[] }
}

const EMPTY_MOODS = { sleepy: [], lonely: [], happy: [] }

const FALLBACK: LinePools = {
  welcome: ['我上班了，有事喊我'],
  click: ['在的在的'],
  idle: ['坐太久了吧，起来走走'],
  error: ['出了点岔子'],
  thinking: ['让我想想…'],
  moods: EMPTY_MOODS
}

let cache: LinesFile | null = null

async function loadFile(): Promise<LinesFile | null> {
  if (cache) return cache
  try {
    const raw = await readFile(join(app.getAppPath(), 'resources', 'lines.json'), 'utf-8')
    cache = JSON.parse(raw) as LinesFile
    return cache
  } catch (e) {
    console.error('[lines] 读取 lines.json 失败', e)
    return null
  }
}

export async function builtinLines(style: LineStyle): Promise<{ click: string[]; idle: string[] }> {
  const file = await loadFile()
  if (!file) return { click: FALLBACK.click, idle: FALLBACK.idle }
  return file.styles[style] ?? file.styles.default ?? { click: FALLBACK.click, idle: FALLBACK.idle }
}

/** 当前人格实际生效的语录：人格自带的优先，否则用风格内置包 */
export async function resolveLines(persona: Persona): Promise<LinePools> {
  const file = await loadFile()
  const builtin = await builtinLines(persona.style)
  const custom = persona.lines
  const pick = (a: string[] | undefined, b: string[]): string[] => (a && a.length > 0 ? a : b)
  return {
    welcome: file?.welcome ?? FALLBACK.welcome,
    error: file?.error ?? FALLBACK.error,
    thinking: file?.thinking ?? FALLBACK.thinking,
    click: pick(custom?.click, builtin.click),
    idle: pick(custom?.idle, builtin.idle),
    moods: file?.moods ?? EMPTY_MOODS
  }
}

const CLICK_TARGET = 24
const IDLE_TARGET = 12
/** AI 至少写出这么多条就不掺内置语录，避免两种语气混在一起 */
const CLICK_FLOOR = 10
const IDLE_FLOOR = 6
const MAX_LINE_LEN = 20

function buildPrompt(persona: Persona): string {
  const desc = persona.prompt || '轻松、口语化、偶尔调侃'
  return [
    `你在为一个桌面挂件角色写台词。角色名叫「${persona.name}」。`,
    `角色性格设定（这是最重要的输入，必须吃透）：${desc}`,
    '',
    '请写两组台词：',
    `1. click：用户用鼠标点击这个挂件时它说的话，${CLICK_TARGET} 条，每条 1-15 字。`,
    `2. idle：用户十分钟没有任何操作时它主动说的话，${IDLE_TARGET} 条，每条 1-20 字。`,
    '',
    '硬性要求：',
    '- 必须从性格设定里抓具体细节来写，比如里面提到的称呼、习惯、爱好、要吐槽的事、口头禅、宠物或人名，都要真的出现在台词里。至少一半的台词要能看出是专门为这个设定写的。',
    '- 禁止「在的在的」「有什么可以帮你」这类放到任何角色身上都成立的通用套话。',
    '- 语气要杂一点：有的调侃、有的嫌烦、有的关心、有的自言自语，不要 24 条都是同一个句式。',
    '- 口语、简短、条条不重复、不要引号、不要编号、不要 markdown。',
    '',
    '只输出如下 JSON，不要任何解释：',
    '{"click":["…"],"idle":["…"]}'
  ].join('\n')
}

/** 模型返回不合规是常态，所以解析要层层兜底 */
function parseLines(text: string): { click: string[]; idle: string[] } {
  const tryParse = (s: string): { click?: unknown; idle?: unknown } | null => {
    try {
      return JSON.parse(s) as { click?: unknown; idle?: unknown }
    } catch {
      return null
    }
  }
  const obj = tryParse(text) ?? tryParse(text.match(/\{[\s\S]*\}/)?.[0] ?? '')
  if (obj) {
    return { click: clean(obj.click), idle: clean(obj.idle) }
  }
  // 连 JSON 都不是，按行拆：前面的算 click，后面的算 idle
  const rows = clean(text.split('\n'))
  return { click: rows.slice(0, CLICK_TARGET), idle: rows.slice(CLICK_TARGET) }
}

function clean(input: unknown): string[] {
  const arr = Array.isArray(input) ? input : typeof input === 'string' ? input.split('\n') : []
  const out: string[] = []
  for (const raw of arr) {
    if (typeof raw !== 'string') continue
    const line = raw
      .replace(/^\s*[-*\d.、)]+\s*/, '') // 去编号和列表符号
      .replace(/^["'「『]|["'」』]$/g, '') // 去包裹的引号
      .replace(/[*_`#]/g, '') // 去 markdown 标记
      .trim()
      .slice(0, MAX_LINE_LEN)
    if (line && !out.includes(line)) out.push(line)
  }
  return out
}

export type GenerateLinesResult =
  | { ok: true; click: string[]; idle: string[]; padded: boolean }
  | { ok: false; error: string }

export async function generateLines(persona: Persona): Promise<GenerateLinesResult> {
  const cfg = getModelConfig()
  if (!cfg.baseUrl || !cfg.apiKey || !cfg.model) {
    return { ok: false, error: '先把模型配置填好，才能按性格生成语录' }
  }

  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), 60_000)
  try {
    const res = await fetch(`${cfg.baseUrl.replace(/\/$/, '')}/chat/completions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${cfg.apiKey}` },
      body: JSON.stringify({
        model: cfg.model,
        temperature: 1,
        messages: [{ role: 'user', content: buildPrompt(persona) }]
      }),
      signal: controller.signal
    })
    if (!res.ok) {
      if (res.status === 401 || res.status === 403) return { ok: false, error: 'apiKey 被拒绝' }
      if (res.status === 429) return { ok: false, error: '模型忙，等十几秒再点' }
      return { ok: false, error: `模型返回 HTTP ${res.status}` }
    }
    const json = (await res.json()) as { choices?: Array<{ message?: { content?: string } }> }
    const text = json.choices?.[0]?.message?.content ?? ''
    const parsed = parseLines(text)

    // 数量不够时的策略：AI 写出来的够用就不掺内置语录——掺了会混进另一种语气，
    // 反而稀释掉性格。只有少到撑不起随机性时才补。
    const builtin = await builtinLines(persona.style)
    let padded = false
    const fill = (got: string[], pool: string[], target: number, floor: number): string[] => {
      if (got.length >= floor) return got.slice(0, target)
      padded = true
      const merged = [...got]
      for (const line of pool) {
        if (merged.length >= target) break
        if (!merged.includes(line)) merged.push(line)
      }
      return merged
    }
    const click = fill(parsed.click, builtin.click, CLICK_TARGET, CLICK_FLOOR)
    const idle = fill(parsed.idle, builtin.idle, IDLE_TARGET, IDLE_FLOOR)
    if (click.length === 0 && idle.length === 0) {
      console.error('[lines] 模型返回无法解析：', text.slice(0, 200))
      return { ok: false, error: '模型返回的内容解析不出来，再试一次' }
    }
    return { ok: true, click, idle, padded }
  } catch (e) {
    if (e instanceof Error && e.name === 'AbortError') return { ok: false, error: '生成超时（60s）' }
    return { ok: false, error: e instanceof Error ? e.message : '生成失败' }
  } finally {
    clearTimeout(timer)
  }
}
