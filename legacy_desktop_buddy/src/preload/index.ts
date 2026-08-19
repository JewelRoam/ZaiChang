import { contextBridge, ipcRenderer } from 'electron'
import type {
  ActiveAvatar,
  AiChibiResult,
  AvatarForm,
  AvatarImportResult,
  AvatarMeta,
  AvatarPreview,
  BuddyStatus,
  BumpKind,
  ChatResult,
  DiagnoseResult,
  MemoConfig,
  ModelConfig,
  MotionConfig,
  Persona,
  Todo
} from '../shared/types'

export interface BubblePayload {
  text: string
  durationMs: number
}

export interface LinePools {
  welcome: string[]
  click: string[]
  idle: string[]
  error: string[]
  thinking: string[]
}

const api = {
  // 窗口 / 交互
  setInteractive: (v: boolean): Promise<void> => ipcRenderer.invoke('window:setInteractive', v),
  movePet: (dx: number, dy: number): Promise<void> => ipcRenderer.invoke('pet:move', { dx, dy }),
  movePetEnd: (): Promise<void> => ipcRenderer.invoke('pet:moveEnd'),
  hidePet: (): Promise<void> => ipcRenderer.invoke('pet:hide'),
  showContextMenu: (): Promise<void> => ipcRenderer.invoke('pet:contextMenu'),
  openSettings: (): Promise<void> => ipcRenderer.invoke('settings:open'),

  // 形象
  getActiveAvatar: (): Promise<ActiveAvatar> => ipcRenderer.invoke('avatar:active'),
  listAvatars: (): Promise<AvatarMeta[]> => ipcRenderer.invoke('avatar:list'),
  getAvatarPreview: (id: string): Promise<AvatarPreview> =>
    ipcRenderer.invoke('avatar:preview', id),
  pickAvatar: (): Promise<AvatarImportResult> => ipcRenderer.invoke('avatar:pick'),
  switchAvatar: (id: string | null, form?: AvatarForm): Promise<ActiveAvatar> =>
    ipcRenderer.invoke('avatar:switch', id, form),
  setForm: (form: AvatarForm): Promise<ActiveAvatar> => ipcRenderer.invoke('avatar:setForm', form),
  deleteAvatar: (id: string): Promise<AvatarMeta[]> => ipcRenderer.invoke('avatar:delete', id),
  generateAiChibi: (id: string, force = false): Promise<AiChibiResult> =>
    ipcRenderer.invoke('avatar:generateAi', id, force),
  removeAvatarBackground: (id: string): Promise<{ ok: boolean; error?: string }> =>
    ipcRenderer.invoke('avatar:matting', id),
  setUseCutout: (id: string, use: boolean): Promise<AvatarMeta[]> =>
    ipcRenderer.invoke('avatar:setUseCutout', id, use),

  // 备忘录
  openMemo: (): Promise<void> => ipcRenderer.invoke('memo:open'),
  listTodos: (): Promise<Todo[]> => ipcRenderer.invoke('memo:list'),
  addTodo: (text: string, remindAt: number | null = null): Promise<Todo[]> =>
    ipcRenderer.invoke('memo:add', text, remindAt),
  toggleTodo: (id: string, done?: boolean): Promise<Todo[]> =>
    ipcRenderer.invoke('memo:toggle', id, done),
  removeTodo: (id: string): Promise<Todo[]> => ipcRenderer.invoke('memo:remove', id),
  setTodoRemind: (id: string, remindAt: number | null): Promise<Todo[]> =>
    ipcRenderer.invoke('memo:setRemind', id, remindAt),
  getMemoConfig: (): Promise<MemoConfig> => ipcRenderer.invoke('memo:getConfig'),
  setMemoConfig: (patch: Partial<MemoConfig>): Promise<MemoConfig> =>
    ipcRenderer.invoke('memo:setConfig', patch),
  onMemoRefresh: (cb: () => void): (() => void) => {
    const h = (): void => cb()
    ipcRenderer.on('memo:refresh', h)
    return () => ipcRenderer.removeListener('memo:refresh', h)
  },

  // 性格
  getPersona: (id: string | null): Promise<Persona> => ipcRenderer.invoke('persona:get', id),
  setPersona: (id: string | null, patch: Partial<Persona>): Promise<Persona> =>
    ipcRenderer.invoke('persona:set', id, patch),
  generatePersonaLines: (
    id: string | null
  ): Promise<
    { ok: true; click: string[]; idle: string[]; padded: boolean } | { ok: false; error: string }
  > => ipcRenderer.invoke('persona:generateLines', id),
  onLinesChanged: (cb: () => void): (() => void) => {
    const h = (): void => cb()
    ipcRenderer.on('lines:changed', h)
    return () => ipcRenderer.removeListener('lines:changed', h)
  },

  // 动作
  strollPet: (): Promise<void> => ipcRenderer.invoke('pet:stroll'),
  getMotionConfig: (): Promise<MotionConfig> => ipcRenderer.invoke('config:getMotion'),
  setMotionConfig: (patch: Partial<MotionConfig>): Promise<MotionConfig> =>
    ipcRenderer.invoke('config:setMotion', patch),
  onMotionChanged: (cb: (c: MotionConfig) => void): (() => void) => {
    const h = (_e: unknown, c: MotionConfig): void => cb(c)
    ipcRenderer.on('config:motionChanged', h)
    return () => ipcRenderer.removeListener('config:motionChanged', h)
  },

  // 状态（好感度 / 精力 / 心情）
  getStatus: (): Promise<BuddyStatus> => ipcRenderer.invoke('state:get'),
  bumpStatus: (kind: BumpKind): Promise<BuddyStatus> => ipcRenderer.invoke('state:bump', kind),
  resetStatus: (): Promise<BuddyStatus> => ipcRenderer.invoke('state:reset'),

  // 诊断
  testConnection: (): Promise<DiagnoseResult> => ipcRenderer.invoke('llm:test'),

  // 配置
  getModelConfig: (): Promise<ModelConfig> => ipcRenderer.invoke('config:getModel'),
  setModelConfig: (patch: Partial<ModelConfig>): Promise<ModelConfig> =>
    ipcRenderer.invoke('config:setModel', patch),
  getIdleChat: (): Promise<boolean> => ipcRenderer.invoke('config:getIdleChat'),
  setIdleChat: (enabled: boolean): Promise<boolean> =>
    ipcRenderer.invoke('config:setIdleChat', enabled),

  // 对话
  chat: (text: string): Promise<ChatResult> => ipcRenderer.invoke('chat:send', text),
  getLines: (): Promise<LinePools> => ipcRenderer.invoke('lines:get'),
  /** MVP 占位，恒返回不支持 */
  startAsr: (): Promise<{ ok: boolean; error?: string }> => ipcRenderer.invoke('asr:start'),

  // 主进程推送
  onBubble: (cb: (p: BubblePayload) => void): (() => void) => {
    const h = (_e: unknown, p: BubblePayload): void => cb(p)
    ipcRenderer.on('bubble:push', h)
    return () => ipcRenderer.removeListener('bubble:push', h)
  },
  onAvatarChanged: (cb: (a: ActiveAvatar) => void): (() => void) => {
    const h = (_e: unknown, a: ActiveAvatar): void => cb(a)
    ipcRenderer.on('avatar:changed', h)
    return () => ipcRenderer.removeListener('avatar:changed', h)
  },
  onIdleChatChanged: (cb: (enabled: boolean) => void): (() => void) => {
    const h = (_e: unknown, v: boolean): void => cb(v)
    ipcRenderer.on('config:idleChatChanged', h)
    return () => ipcRenderer.removeListener('config:idleChatChanged', h)
  }
}

export type BuddyApi = typeof api

contextBridge.exposeInMainWorld('buddy', api)
