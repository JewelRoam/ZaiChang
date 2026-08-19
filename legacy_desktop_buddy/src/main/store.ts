import Store from 'electron-store'
import { app } from 'electron'
import { join } from 'node:path'
import type {
  AvatarForm,
  AvatarMeta,
  BuddyConfig,
  BuddyStateData,
  MemoConfig,
  ModelConfig,
  MotionConfig,
  Persona
} from '@shared/types'
import { PERSONA_NAME_MAX, PERSONA_PROMPT_MAX } from '@shared/types'
import { INITIAL_AFFINITY, initialState } from './mood'

const defaultPersona: Persona = {
  name: '搭搭',
  prompt: '说话轻松、口语化、偶尔调侃，但不油腻，不用敬语。',
  style: 'default',
  lines: null
}

/** 名字和性格描述都做长度截断，避免撑爆气泡或 system prompt */
export function normalizePersona(p: Partial<Persona>): Persona {
  return {
    name: (p.name ?? defaultPersona.name).trim().slice(0, PERSONA_NAME_MAX) || defaultPersona.name,
    prompt: (p.prompt ?? '').trim().slice(0, PERSONA_PROMPT_MAX),
    style: p.style ?? 'default',
    lines: p.lines ?? null
  }
}

const DASHSCOPE_DEFAULT_ENDPOINT =
  'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation'

const defaultModel: ModelConfig = {
  baseUrl: '',
  apiKey: '',
  model: '',
  temperature: 0.8,
  imageApiKey: '',
  imageBaseUrl: '',
  imageModel: '',
  imageStyle: 'dashscope',
  imageEndpoint: DASHSCOPE_DEFAULT_ENDPOINT,
  mattingUrl: '',
  mattingStyle: 'rembg'
}

const defaultMemo: MemoConfig = {
  enabled: true,
  popupTime: '09:00',
  carryOver: true
}

const defaultMotion: MotionConfig = {
  freq: 'normal',
  allowMove: false
}

const defaultState: BuddyStateData = {
  affinity: INITIAL_AFFINITY,
  lastSeenAt: 0,
  todayGain: 0,
  todayDate: ''
}

const defaults: BuddyConfig = {
  avatars: [],
  currentAvatarId: null,
  form: 'original',
  petPosition: null,
  idleChatEnabled: true,
  model: defaultModel,
  memo: defaultMemo,
  defaultPersona,
  motion: defaultMotion,
  state: defaultState
}

const store = new Store<BuddyConfig>({ name: 'config', defaults })

export function avatarsDir(): string {
  return join(app.getPath('userData'), 'avatars')
}

export function getConfig(): BuddyConfig {
  return {
    ...defaults,
    ...(store.store as BuddyConfig),
    model: { ...defaultModel, ...(store.get('model') ?? {}) }
  }
}

export function getAvatars(): AvatarMeta[] {
  // v1 的记录没有 cutout 相关字段，读取时补默认值，不需要用户重新上传
  return (store.get('avatars') ?? []).map((a) => ({
    ...a,
    cutoutPath: a.cutoutPath ?? null,
    useCutout: a.useCutout ?? false,
    persona: a.persona ?? null
  }))
}

export function setAvatars(list: AvatarMeta[]): void {
  store.set('avatars', list)
}

export function getCurrentAvatarId(): string | null {
  return store.get('currentAvatarId') ?? null
}

export function setCurrentAvatarId(id: string | null): void {
  store.set('currentAvatarId', id)
}

export function getForm(): AvatarForm {
  return store.get('form') ?? 'original'
}

export function setForm(form: AvatarForm): void {
  store.set('form', form)
}

export function getPetPosition(): { x: number; y: number } | null {
  return store.get('petPosition') ?? null
}

export function setPetPosition(pos: { x: number; y: number }): void {
  store.set('petPosition', pos)
}

export function getModelConfig(): ModelConfig {
  return { ...defaultModel, ...(store.get('model') ?? {}) }
}

export function setModelConfig(patch: Partial<ModelConfig>): ModelConfig {
  const next = { ...getModelConfig(), ...patch }
  store.set('model', next)
  return next
}

/** 图像和抠图服务用的 key：填了独立 key 就用它，否则回落到对话的 key */
export function imageApiKey(): string {
  const cfg = getModelConfig()
  return cfg.imageApiKey.trim() || cfg.apiKey
}

export function getDefaultPersona(): Persona {
  return normalizePersona(store.get('defaultPersona') ?? defaultPersona)
}

export function setDefaultPersona(patch: Partial<Persona>): Persona {
  const next = normalizePersona({ ...getDefaultPersona(), ...patch })
  store.set('defaultPersona', next)
  return next
}

export function getMotionConfig(): MotionConfig {
  return { ...defaultMotion, ...(store.get('motion') ?? {}) }
}

/** 首次读取时 lastSeenAt 为 0，用当前时间初始化，避免被算成"几十年没互动" */
export function getStateData(): BuddyStateData {
  const raw = store.get('state')
  if (!raw || !raw.lastSeenAt) {
    const init = initialState()
    store.set('state', init)
    return init
  }
  return { ...defaultState, ...raw }
}

export function setStateData(next: BuddyStateData): BuddyStateData {
  store.set('state', next)
  return next
}

export function setMotionConfig(patch: Partial<MotionConfig>): MotionConfig {
  const next = { ...getMotionConfig(), ...patch }
  store.set('motion', next)
  return next
}

/**
 * 当前生效的人格。放在 store 而不是 avatar/manager，是为了避免
 * client.ts ↔ manager.ts 相互 import 形成循环依赖。
 */
export function getEffectivePersona(id?: string | null): Persona {
  const avatarId = id === undefined ? getCurrentAvatarId() : id
  const avatar = getAvatars().find((a) => a.id === avatarId)
  return avatar?.persona ? normalizePersona(avatar.persona) : getDefaultPersona()
}

export function setPersonaFor(id: string | null, patch: Partial<Persona>): Persona {
  if (id === null) return setDefaultPersona(patch)
  const next = normalizePersona({ ...getEffectivePersona(id), ...patch })
  setAvatars(getAvatars().map((a) => (a.id === id ? { ...a, persona: next } : a)))
  return next
}

export function getIdleChatEnabled(): boolean {
  return store.get('idleChatEnabled') ?? true
}

export function setIdleChatEnabled(enabled: boolean): void {
  store.set('idleChatEnabled', enabled)
}

export function getMemoConfig(): MemoConfig {
  return { ...defaultMemo, ...(store.get('memo') ?? {}) }
}

export function setMemoConfig(patch: Partial<MemoConfig>): MemoConfig {
  const next = { ...getMemoConfig(), ...patch }
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(next.popupTime)) next.popupTime = defaultMemo.popupTime
  store.set('memo', next)
  return next
}
