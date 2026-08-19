import { app, dialog, ipcMain, Menu, BrowserWindow } from 'electron'
import type {
  AvatarForm,
  BumpKind,
  MemoConfig,
  ModelConfig,
  MotionConfig,
  Persona
} from '@shared/types'
import {
  deleteAvatar,
  generateAiChibi,
  getActiveAvatar,
  getAvatarPreview,
  getPersona,
  importAvatar,
  listAvatars,
  regenerateAiChibi,
  removeAvatarBackground,
  setAvatarForm,
  setPersona,
  setUseCutout,
  switchAvatar
} from './avatar/manager'
import { chat, resetHistory } from './llm/client'
import { generateLines, resolveLines } from './llm/lines'
import { testConnection } from './llm/diagnose'
import {
  addTodo,
  listTodos,
  removeTodo,
  setTodoRemind,
  toggleTodo
} from './memo/store'
import { scheduleTodoReminder } from './memo/schedule'
import { notifyMemoChanged } from './memo/notify'
import {
  getIdleChatEnabled,
  getMemoConfig,
  getModelConfig,
  getMotionConfig,
  getStateData,
  setIdleChatEnabled,
  setMemoConfig,
  setModelConfig,
  setMotionConfig,
  setPetPosition,
  setStateData
} from './store'
import { bumpAffinity, initialState, toStatus } from './mood'
import { abortStroll, strollPet } from './motion'
import { getPetWindow, setPetInteractive } from './windows/petWindow'
import { openMemo } from './windows/memoWindow'
import { openSettings } from './windows/settingsWindow'

/** 形象变化后广播到所有窗口，让 PetWindow 和设置页同时刷新 */
export function broadcastAvatarChanged(): void {
  const active = getActiveAvatar()
  BrowserWindow.getAllWindows().forEach((w) => w.webContents.send('avatar:changed', active))
}

export function registerIpc(): void {
  ipcMain.handle('window:setInteractive', (_e, interactive: boolean) => {
    setPetInteractive(!!interactive)
  })

  ipcMain.handle('pet:move', (_e, delta: { dx: number; dy: number }) => {
    const win = getPetWindow()
    if (!win) return
    // 用户开始拖拽就中止走动，否则两边抢窗口位置
    abortStroll()
    const [x, y] = win.getPosition()
    win.setPosition(Math.round(x + delta.dx), Math.round(y + delta.dy))
  })

  ipcMain.handle('pet:stroll', () => strollPet())

  ipcMain.handle('config:getMotion', () => getMotionConfig())
  ipcMain.handle('config:setMotion', (_e, patch: Partial<MotionConfig>) => {
    const next = setMotionConfig(patch ?? {})
    BrowserWindow.getAllWindows().forEach((w) => w.webContents.send('config:motionChanged', next))
    return next
  })

  ipcMain.handle('pet:moveEnd', () => {
    const win = getPetWindow()
    if (!win) return
    const [x, y] = win.getPosition()
    setPetPosition({ x, y })
  })

  ipcMain.handle('pet:hide', () => getPetWindow()?.hide())

  ipcMain.handle('avatar:active', () => getActiveAvatar())
  ipcMain.handle('avatar:list', () => listAvatars())

  ipcMain.handle('avatar:preview', (_e, id: string) => getAvatarPreview(String(id)))

  ipcMain.handle('avatar:pick', async () => {
    const res = await dialog.showOpenDialog({
      title: '选择搭子形象',
      properties: ['openFile'],
      filters: [{ name: '图片', extensions: ['png', 'jpg', 'jpeg', 'webp'] }]
    })
    if (res.canceled || !res.filePaths[0]) return { ok: false, error: '' }
    const out = await importAvatar(res.filePaths[0])
    if (out.ok) broadcastAvatarChanged()
    return out
  })

  ipcMain.handle('avatar:switch', (_e, id: string | null, form?: AvatarForm) => {
    const active = switchAvatar(id, form)
    broadcastAvatarChanged()
    return active
  })

  ipcMain.handle('avatar:setForm', (_e, form: AvatarForm) => {
    const active = setAvatarForm(form)
    broadcastAvatarChanged()
    return active
  })

  ipcMain.handle('avatar:delete', async (_e, id: string) => {
    await deleteAvatar(id)
    broadcastAvatarChanged()
    return listAvatars()
  })

  ipcMain.handle('avatar:generateAi', async (_e, id: string, force?: boolean) => {
    const out = force ? await regenerateAiChibi(id) : await generateAiChibi(id)
    if (out.ok) broadcastAvatarChanged()
    return out
  })

  ipcMain.handle('avatar:matting', async (_e, id: string) => {
    const out = await removeAvatarBackground(String(id))
    if (out.ok) broadcastAvatarChanged()
    return out
  })

  ipcMain.handle('avatar:setUseCutout', (_e, id: string, use: boolean) => {
    const list = setUseCutout(String(id), !!use)
    broadcastAvatarChanged()
    return list
  })

  ipcMain.handle('state:get', () => toStatus(getStateData()))

  ipcMain.handle('state:bump', (_e, kind: BumpKind) => {
    const next = setStateData(bumpAffinity(getStateData(), kind))
    return toStatus(next)
  })

  ipcMain.handle('state:reset', () => {
    return toStatus(setStateData(initialState()))
  })

  ipcMain.handle('llm:test', () => testConnection())

  ipcMain.handle('memo:open', () => {
    openMemo()
  })
  ipcMain.handle('memo:list', () => listTodos())
  ipcMain.handle('memo:add', (_e, text: string, remindAt: number | null) => {
    const todo = addTodo(String(text ?? ''), remindAt ?? null)
    if (todo?.remindAt) scheduleTodoReminder(todo.id, todo.remindAt, todo.text)
    notifyMemoChanged()
    return listTodos()
  })
  ipcMain.handle('memo:toggle', (_e, id: string, done?: boolean) => {
    const before = listTodos().find((t) => t.id === id)
    toggleTodo(String(id), done)
    // 只在「标记完成」时加好感度，取消勾选不加，避免反复勾选刷分
    const after = listTodos().find((t) => t.id === id)
    if (before && after && !before.done && after.done) {
      setStateData(bumpAffinity(getStateData(), 'todo'))
    }
    notifyMemoChanged()
    return listTodos()
  })
  ipcMain.handle('memo:remove', (_e, id: string) => {
    removeTodo(String(id))
    scheduleTodoReminder(String(id), null, '')
    notifyMemoChanged()
    return listTodos()
  })
  ipcMain.handle('memo:setRemind', (_e, id: string, remindAt: number | null) => {
    const todo = setTodoRemind(String(id), remindAt ?? null)
    if (todo) scheduleTodoReminder(todo.id, todo.remindAt, todo.text)
    notifyMemoChanged()
    return listTodos()
  })
  ipcMain.handle('memo:getConfig', () => getMemoConfig())
  ipcMain.handle('memo:setConfig', (_e, patch: Partial<MemoConfig>) => setMemoConfig(patch ?? {}))

  ipcMain.handle('config:getModel', () => getModelConfig())
  ipcMain.handle('config:setModel', (_e, patch: Partial<ModelConfig>) => {
    const next = setModelConfig(patch ?? {})
    resetHistory() // 换了模型/key，旧上下文不再可信
    return next
  })

  ipcMain.handle('config:getIdleChat', () => getIdleChatEnabled())
  ipcMain.handle('config:setIdleChat', (_e, enabled: boolean) => {
    setIdleChatEnabled(!!enabled)
    BrowserWindow.getAllWindows().forEach((w) =>
      w.webContents.send('config:idleChatChanged', !!enabled)
    )
    return !!enabled
  })

  ipcMain.handle('chat:send', (_e, text: string) => chat(String(text ?? '')))

  ipcMain.handle('lines:get', async () => {
    return resolveLines(getPersona())
  })

  ipcMain.handle('persona:get', (_e, id: string | null) => getPersona(id))

  ipcMain.handle('persona:set', (_e, id: string | null, patch: Partial<Persona>) => {
    const next = setPersona(id, patch ?? {})
    broadcastAvatarChanged()
    BrowserWindow.getAllWindows().forEach((w) => w.webContents.send('lines:changed'))
    return next
  })

  ipcMain.handle('persona:generateLines', async (_e, id: string | null) => {
    return generateLines(getPersona(id))
  })

  ipcMain.handle('settings:open', () => {
    openSettings()
  })

  ipcMain.handle('asr:start', () => {
    // MVP 占位：接口先定下来，实现留到接 ASR 的版本
    return { ok: false, error: 'MVP 暂不支持语音输入' }
  })

  ipcMain.handle('pet:contextMenu', (event) => {
    const win = BrowserWindow.fromWebContents(event.sender)
    const active = getActiveAvatar()
    const menu = Menu.buildFromTemplate([
      { label: '更换形象…', click: () => openSettings() },
      { label: '今日备忘…', click: () => openMemo() },
      { type: 'separator' },
      {
        label: '原始形态',
        type: 'radio',
        checked: active.form === 'original',
        click: () => {
          setAvatarForm('original')
          broadcastAvatarChanged()
        }
      },
      {
        label: 'Q 版形态',
        type: 'radio',
        checked: active.form === 'chibi',
        click: () => {
          setAvatarForm('chibi')
          broadcastAvatarChanged()
        }
      },
      { type: 'separator' },
      { label: '设置…', click: () => openSettings() },
      { label: '隐藏搭子', click: () => win?.hide() },
      { label: '退出', click: () => app.quit() }
    ])
    if (win) menu.popup({ window: win })
  })
}
