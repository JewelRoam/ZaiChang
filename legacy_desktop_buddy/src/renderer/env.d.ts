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
} from '@shared/types'

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
  moods: { sleepy: string[]; lonely: string[]; happy: string[] }
}

export interface BuddyApi {
  setInteractive: (v: boolean) => Promise<void>
  movePet: (dx: number, dy: number) => Promise<void>
  movePetEnd: () => Promise<void>
  hidePet: () => Promise<void>
  showContextMenu: () => Promise<void>
  openSettings: () => Promise<void>
  getActiveAvatar: () => Promise<ActiveAvatar>
  listAvatars: () => Promise<AvatarMeta[]>
  getAvatarPreview: (id: string) => Promise<AvatarPreview>
  removeAvatarBackground: (id: string) => Promise<{ ok: boolean; error?: string }>
  setUseCutout: (id: string, use: boolean) => Promise<AvatarMeta[]>
  openMemo: () => Promise<void>
  listTodos: () => Promise<Todo[]>
  addTodo: (text: string, remindAt?: number | null) => Promise<Todo[]>
  toggleTodo: (id: string, done?: boolean) => Promise<Todo[]>
  removeTodo: (id: string) => Promise<Todo[]>
  setTodoRemind: (id: string, remindAt: number | null) => Promise<Todo[]>
  getMemoConfig: () => Promise<MemoConfig>
  setMemoConfig: (patch: Partial<MemoConfig>) => Promise<MemoConfig>
  onMemoRefresh: (cb: () => void) => () => void
  testConnection: () => Promise<DiagnoseResult>
  getStatus: () => Promise<BuddyStatus>
  bumpStatus: (kind: BumpKind) => Promise<BuddyStatus>
  resetStatus: () => Promise<BuddyStatus>
  getPersona: (id: string | null) => Promise<Persona>
  setPersona: (id: string | null, patch: Partial<Persona>) => Promise<Persona>
  generatePersonaLines: (
    id: string | null
  ) => Promise<
    { ok: true; click: string[]; idle: string[]; padded: boolean } | { ok: false; error: string }
  >
  onLinesChanged: (cb: () => void) => () => void
  strollPet: () => Promise<void>
  getMotionConfig: () => Promise<MotionConfig>
  setMotionConfig: (patch: Partial<MotionConfig>) => Promise<MotionConfig>
  onMotionChanged: (cb: (c: MotionConfig) => void) => () => void
  pickAvatar: () => Promise<AvatarImportResult>
  switchAvatar: (id: string | null, form?: AvatarForm) => Promise<ActiveAvatar>
  setForm: (form: AvatarForm) => Promise<ActiveAvatar>
  deleteAvatar: (id: string) => Promise<AvatarMeta[]>
  generateAiChibi: (id: string, force?: boolean) => Promise<AiChibiResult>
  getModelConfig: () => Promise<ModelConfig>
  setModelConfig: (patch: Partial<ModelConfig>) => Promise<ModelConfig>
  getIdleChat: () => Promise<boolean>
  setIdleChat: (enabled: boolean) => Promise<boolean>
  chat: (text: string) => Promise<ChatResult>
  getLines: () => Promise<LinePools>
  startAsr: () => Promise<{ ok: boolean; error?: string }>
  onBubble: (cb: (p: BubblePayload) => void) => () => void
  onAvatarChanged: (cb: (a: ActiveAvatar) => void) => () => void
  onIdleChatChanged: (cb: (enabled: boolean) => void) => () => void
}

declare global {
  interface Window {
    buddy: BuddyApi
  }
}
