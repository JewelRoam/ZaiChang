export type AvatarForm = 'original' | 'chibi'

export type LineStyle = 'default' | 'genki' | 'cool' | 'savage' | 'gentle'

export interface Persona {
  /** 搭子的名字，上限 10 字 */
  name: string
  /** 用户写的性格描述，上限 500 字 */
  prompt: string
  /** 内置语录风格包，作为 AI 语录的兜底 */
  style: LineStyle
  /** AI 生成或用户手写的语录；为 null 则用 style 对应的内置包 */
  lines: { click: string[]; idle: string[] } | null
}

export const PERSONA_NAME_MAX = 10
export const PERSONA_PROMPT_MAX = 500

export type MotionName =
  | 'jump'
  | 'hop'
  | 'sway'
  | 'shiver'
  | 'spin'
  | 'roll'
  | 'squash'
  | 'tilt'
  | 'stretch'
  | 'pop'
  | 'nod'
  | 'wobble'
  | 'stroll'
  | 'peek'

export type MotionFreq = 'off' | 'low' | 'normal' | 'high'

export type MoodLevel = 'lonely' | 'low' | 'normal' | 'happy' | 'sleepy'

/** 落盘的状态数据 */
export interface BuddyStateData {
  /** 好感度 0-100 */
  affinity: number
  /** 最后一次互动时间戳，用于结算衰减 */
  lastSeenAt: number
  /** 当天已获得的好感度，用于防刷 */
  todayGain: number
  /** todayGain 所属日期 YYYY-MM-DD */
  todayDate: string
}

/** 对外暴露的派生状态 */
export interface BuddyStatus {
  affinity: number
  /** 0-100，由当前时段派生，不落盘 */
  energy: number
  mood: MoodLevel
  daysSinceSeen: number
}

export type BumpKind = 'click' | 'chat' | 'todo'

export interface MotionConfig {
  freq: MotionFreq
  /** 是否允许 stroll/peek 这类会移动窗口的动作 */
  allowMove: boolean
}

export interface AvatarMeta {
  id: string
  name: string
  /** 上传时间戳 */
  createdAt: number
  /** 原图（统一转 PNG）绝对路径 */
  originalPath: string
  /** 本地程序化 Q 版绝对路径 */
  chibiPath: string
  /** AI 生成的 Q 版绝对路径，未生成时为 null */
  chibiAiPath: string | null
  /** AI 抠图产物绝对路径，未抠图时为 null */
  cutoutPath: string | null
  /** 原始形态是否使用抠图结果，抠图成功后默认 true */
  useCutout: boolean
  /** 素材文件缺失时置 true，加载会回退到默认形象 */
  broken?: boolean
  /** 该形象对应的性格；null 表示用全局默认人格 */
  persona: Persona | null
}

export interface ModelConfig {
  baseUrl: string
  apiKey: string
  model: string
  temperature: number
  /** 图像/抠图服务的 apiKey；留空则回落到对话用的 apiKey */
  imageApiKey: string
  /** 图像编辑接口地址，为空则「AI Q 版」按钮禁用 */
  imageBaseUrl: string
  imageModel: string
  /** 图像接口协议：openai = /images/edits；dashscope = 百炼原生多模态生成 */
  imageStyle: 'openai' | 'dashscope'
  /** DashScope 协议用的完整请求地址（不是 base，是带路径的完整 URL） */
  imageEndpoint: string
  /** 抠图接口地址，为空则「AI 抠图」按钮禁用 */
  mattingUrl: string
  /** 抠图接口协议：rembg = multipart 直接返回 PNG；openai = /images/edits */
  mattingStyle: 'rembg' | 'openai'
}

export interface MemoConfig {
  enabled: boolean
  /** 'HH:mm' */
  popupTime: string
  carryOver: boolean
}

export interface Todo {
  id: string
  text: string
  done: boolean
  /** 归属日期 YYYY-MM-DD */
  date: string
  remindAt: number | null
  /** 从哪一天带过来的 */
  carriedFrom?: string
}

export type DiagnoseResult =
  | { ok: true; toolsSupported: boolean; message: string }
  | {
      ok: false
      kind: 'missing' | 'bad-url' | 'network' | 'auth' | 'model' | 'rate-limit' | 'server'
      message: string
    }

export interface BuddyConfig {
  avatars: AvatarMeta[]
  currentAvatarId: string | null
  form: AvatarForm
  petPosition: { x: number; y: number } | null
  idleChatEnabled: boolean
  model: ModelConfig
  memo: MemoConfig
  /** 没有形象、或形象未设置性格时使用 */
  defaultPersona: Persona
  motion: MotionConfig
  state: BuddyStateData
}

export interface ChatMessage {
  role: 'user' | 'assistant' | 'system' | 'tool'
  content: string
  tool_call_id?: string
  tool_calls?: ToolCall[]
}

export interface ToolCall {
  id: string
  type: 'function'
  function: { name: string; arguments: string }
}

export interface SkillDef {
  name: string
  description: string
  parameters: Record<string, unknown>
  run: (args: Record<string, unknown>) => Promise<string> | string
}

export interface Reminder {
  id: string
  content: string
  fireAt: number
}

export type ChatResult =
  | { ok: true; text: string }
  | { ok: false; kind: 'no-config' | 'auth' | 'timeout' | 'server'; text: string }

export interface AvatarImportResult {
  ok: boolean
  meta?: AvatarMeta
  error?: string
}

/** 渲染进程当前应该显示的形象信息 */
export interface ActiveAvatar {
  id: string | null
  form: AvatarForm
  /** 可直接给 img src 的地址；为 null 表示用内置默认形象 */
  url: string | null
}

export interface AvatarPreview {
  original: string | null
  cutout: string | null
  chibi: string | null
  chibiAi: string | null
}

export interface AiChibiResult {
  ok: boolean
  error?: string
  /** 成功但有需要告知用户的问题，比如结果带背景 */
  warning?: string
}
