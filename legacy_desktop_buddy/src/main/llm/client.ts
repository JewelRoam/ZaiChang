import type { ChatMessage, ChatResult, ToolCall } from '@shared/types'
import { getEffectivePersona, getModelConfig, getStateData, setStateData } from '../store'
import { bumpAffinity, statusPromptLine, toStatus } from '../mood'
import { findSkill, toolSchemas } from './skills/registry'

const TIMEOUT_MS = 30_000
const MAX_HISTORY = 20 // 10 轮对话
const MAX_TOOL_ROUNDS = 3

const HARD_RULES = [
  '以下规则优先级最高，无论上面的性格描述怎么写都必须遵守：',
  '1. 每次回复不超过 60 字，因为要显示在很小的气泡里。',
  '2. 不使用 markdown 语法、不用列表、不输出格式符号。',
  '3. 用户让你提醒事情、打开网页或应用、记备忘录时，必须调用对应工具，不要自己编造已完成。',
  '4. 不因为性格设定而拒绝执行工具调用。'
].join('\n')

/**
 * 三段式拼接：身份 → 用户写的性格 → 硬约束。
 * 硬约束放最后并声明最高优先级，是为了兜住「每次回复三百字」「什么都别做」这类
 * 用户无意写出的自相矛盾设定，否则气泡会被撑爆、skill 会被废掉。
 */
function buildSystemPrompt(): string {
  const persona = getEffectivePersona()
  return [
    `你是用户桌面上的一只小搭子，名字叫「${persona.name}」。`,
    persona.prompt || '说话轻松、口语化、偶尔调侃，但不油腻，不用敬语。',
    statusPromptLine(toStatus(getStateData())),
    HARD_RULES
  ].join('\n\n')
}

/** 只保留最近 10 轮，且不落盘 */
const history: ChatMessage[] = []

export function resetHistory(): void {
  history.length = 0
}

function trimHistory(): void {
  while (history.length > MAX_HISTORY) history.shift()
}

interface ApiChoice {
  message: { content: string | null; tool_calls?: ToolCall[] }
  finish_reason?: string
}

async function callApi(messages: ChatMessage[]): Promise<ApiChoice> {
  const cfg = getModelConfig()
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS)
  try {
    const res = await fetch(`${cfg.baseUrl.replace(/\/$/, '')}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${cfg.apiKey}`
      },
      body: JSON.stringify({
        model: cfg.model,
        temperature: cfg.temperature,
        messages,
        tools: toolSchemas(),
        tool_choice: 'auto'
      }),
      signal: controller.signal
    })
    if (res.status === 401 || res.status === 403) throw new ApiError('auth')
    if (res.status === 429) throw new ApiError('rate')
    if (!res.ok) throw new ApiError('server', `HTTP ${res.status}`)
    const json = (await res.json()) as { choices?: ApiChoice[] }
    const choice = json.choices?.[0]
    if (!choice) throw new ApiError('server', '响应里没有 choices')
    return choice
  } catch (e) {
    if (e instanceof ApiError) throw e
    if (e instanceof Error && e.name === 'AbortError') throw new ApiError('timeout')
    throw new ApiError('server', e instanceof Error ? e.message : String(e))
  } finally {
    clearTimeout(timer)
  }
}

class ApiError extends Error {
  constructor(
    readonly kind: 'auth' | 'timeout' | 'rate' | 'server',
    detail?: string
  ) {
    super(detail ?? kind)
  }
}

/** 免费档限流很常见，429 自动重试一次再放弃，避免用户白等一句报错 */
async function callApiWithRetry(messages: ChatMessage[]): Promise<ApiChoice> {
  try {
    return await callApi(messages)
  } catch (e) {
    if (e instanceof ApiError && e.kind === 'rate') {
      await new Promise((r) => setTimeout(r, 2500))
      return callApi(messages)
    }
    throw e
  }
}

async function runToolCalls(calls: ToolCall[]): Promise<ChatMessage[]> {
  const results: ChatMessage[] = []
  for (const call of calls) {
    const skill = findSkill(call.function?.name ?? '')
    if (!skill) {
      results.push({ role: 'tool', tool_call_id: call.id, content: '没有这个能力' })
      continue
    }
    let args: Record<string, unknown> = {}
    try {
      args = call.function.arguments ? JSON.parse(call.function.arguments) : {}
    } catch {
      console.warn('[skill] 参数不是合法 JSON', call.function.name, call.function.arguments)
      results.push({ role: 'tool', tool_call_id: call.id, content: '参数没看懂，让用户再说清楚点' })
      continue
    }
    try {
      const out = await skill.run(args)
      results.push({ role: 'tool', tool_call_id: call.id, content: out })
    } catch (e) {
      console.error('[skill] 执行失败', skill.name, e)
      results.push({ role: 'tool', tool_call_id: call.id, content: '这件事没办成' })
    }
  }
  return results
}

export async function chat(userText: string): Promise<ChatResult> {
  const text = userText.trim()
  if (!text) return { ok: true, text: '你还没说话呢' }

  const cfg = getModelConfig()
  if (!cfg.baseUrl || !cfg.apiKey || !cfg.model) {
    return { ok: false, kind: 'no-config', text: '先去设置里把模型配置填上，我才能听懂你说话' }
  }

  history.push({ role: 'user', content: text })
  trimHistory()

  try {
    const working: ChatMessage[] = [{ role: 'system', content: buildSystemPrompt() }, ...history]
    for (let round = 0; round <= MAX_TOOL_ROUNDS; round++) {
      const choice = await callApiWithRetry(working)
      const calls = choice.message.tool_calls
      if (calls?.length && round < MAX_TOOL_ROUNDS) {
        const assistantMsg: ChatMessage = {
          role: 'assistant',
          content: choice.message.content ?? '',
          tool_calls: calls
        }
        working.push(assistantMsg, ...(await runToolCalls(calls)))
        continue
      }
      const reply = (choice.message.content ?? '').trim() || '嗯，我在。'
      history.push({ role: 'assistant', content: reply })
      trimHistory()
      setStateData(bumpAffinity(getStateData(), 'chat'))
      return { ok: true, text: reply }
    }
    return { ok: false, kind: 'server', text: '我绕进去了，换个说法再试试' }
  } catch (e) {
    // 失败的这轮不留在历史里，避免污染后续上下文
    const idx = history.findIndex((m) => m.role === 'user' && m.content === text)
    if (idx >= 0) history.splice(idx, 1)
    if (e instanceof ApiError) {
      if (e.kind === 'auth') return { ok: false, kind: 'auth', text: 'apiKey 好像不对，去设置里检查下' }
      if (e.kind === 'timeout') return { ok: false, kind: 'timeout', text: '网有点慢，等会儿再问我' }
      if (e.kind === 'rate') return { ok: false, kind: 'server', text: '这会儿排队的人太多，等十几秒再说' }
      console.error('[llm]', e.message)
      return { ok: false, kind: 'server', text: '模型那边出了点问题' }
    }
    console.error('[llm] 未知错误', e)
    return { ok: false, kind: 'server', text: '出了点问题，我也不知道咋了' }
  }
}
