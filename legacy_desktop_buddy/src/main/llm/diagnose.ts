import type { DiagnoseResult } from '@shared/types'
import { getModelConfig } from '../store'

const TIMEOUT_MS = 20_000

const PROBE_TOOL = {
  type: 'function',
  function: {
    name: 'ping',
    description: '连通性探测用，不要真的调用',
    parameters: { type: 'object', properties: {} }
  }
}

/**
 * 用一次最小请求探测配置是否可用，把失败原因分类返回。
 * 目的是让用户看到「到底哪一步不对」，而不是一句「配置有问题」。
 */
export async function testConnection(): Promise<DiagnoseResult> {
  const cfg = getModelConfig()
  const missing: string[] = []
  if (!cfg.baseUrl.trim()) missing.push('接口地址')
  if (!cfg.apiKey.trim()) missing.push('apiKey')
  if (!cfg.model.trim()) missing.push('模型名')
  if (missing.length) {
    return { ok: false, kind: 'missing', message: `还没填：${missing.join('、')}` }
  }

  let url: string
  try {
    url = new URL('chat/completions', cfg.baseUrl.replace(/\/?$/, '/')).toString()
  } catch {
    return { ok: false, kind: 'bad-url', message: '接口地址不是合法 URL，通常形如 https://xxx.com/v1' }
  }

  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS)
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${cfg.apiKey}` },
      body: JSON.stringify({
        model: cfg.model,
        messages: [{ role: 'user', content: 'ping' }],
        max_tokens: 1,
        tools: [PROBE_TOOL],
        tool_choice: 'none'
      }),
      signal: controller.signal
    })

    if (res.status === 401 || res.status === 403) {
      return { ok: false, kind: 'auth', message: 'apiKey 被拒绝（401/403），检查 key 是否有效或已过期' }
    }

    if (res.status === 429) {
      return {
        ok: false,
        kind: 'rate-limit',
        message:
          '限流了（429）：key 有效、地址和模型名都对，是服务端当前排不上队。免费档并发和容量都紧，隔十几秒重试即可；如果高峰期一直这样，换成同系列的付费型号会稳很多。'
      }
    }

    const raw = await res.text()
    if (res.ok) {
      return { ok: true, toolsSupported: true, message: `连接正常，模型 ${cfg.model} 可用，支持工具调用` }
    }

    const detail = extractError(raw)
    // 模型名不对和「不支持 tools」都会返回 400，靠报文关键字区分
    if (/tool|function[_ ]?call/i.test(detail)) {
      const retry = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${cfg.apiKey}` },
        body: JSON.stringify({
          model: cfg.model,
          messages: [{ role: 'user', content: 'ping' }],
          max_tokens: 1
        }),
        signal: controller.signal
      })
      if (retry.ok) {
        return {
          ok: true,
          toolsSupported: false,
          message: `模型 ${cfg.model} 能对话，但不支持工具调用：提醒、打开网页、备忘录这几个能力会失效，只能闲聊。换一个支持 function calling 的模型可解决。`
        }
      }
      return { ok: false, kind: 'server', message: `接口报错：${detail || `HTTP ${retry.status}`}` }
    }
    if (res.status === 404 || /model/i.test(detail)) {
      return {
        ok: false,
        kind: 'model',
        message: `模型名或路径不对（HTTP ${res.status}）：${detail || '检查模型名，以及接口地址是否需要带 /v1'}`
      }
    }
    return { ok: false, kind: 'server', message: `接口返回 HTTP ${res.status}：${detail || '无详细信息'}` }
  } catch (e) {
    if (e instanceof Error && e.name === 'AbortError') {
      return { ok: false, kind: 'network', message: '请求超时（20s），地址可能不通或需要代理' }
    }
    return {
      ok: false,
      kind: 'network',
      message: `连不上这个地址：${e instanceof Error ? e.message : String(e)}`
    }
  } finally {
    clearTimeout(timer)
  }
}

function extractError(raw: string): string {
  try {
    const json = JSON.parse(raw) as { error?: { message?: string } | string; message?: string }
    if (typeof json.error === 'string') return json.error
    return json.error?.message ?? json.message ?? raw.slice(0, 200)
  } catch {
    return raw.slice(0, 200)
  }
}
