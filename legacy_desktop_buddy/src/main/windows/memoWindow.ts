import { BrowserWindow } from 'electron'
import { join } from 'node:path'
import { carryOverTodos } from '../memo/store'
import { getMemoConfig } from '../store'

let memoWindow: BrowserWindow | null = null

export function getMemoWindow(): BrowserWindow | null {
  return memoWindow && !memoWindow.isDestroyed() ? memoWindow : null
}

/** 打开今日备忘；普通窗口、不置顶，早上弹出来不至于挡住正在做的事 */
export function openMemo(): BrowserWindow {
  if (getMemoConfig().carryOver) carryOverTodos()

  const existing = getMemoWindow()
  if (existing) {
    existing.webContents.send('memo:refresh')
    existing.show()
    existing.focus()
    return existing
  }

  memoWindow = new BrowserWindow({
    width: 420,
    height: 520,
    minWidth: 360,
    minHeight: 420,
    title: '今日备忘',
    show: false,
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false
    }
  })

  memoWindow.on('ready-to-show', () => memoWindow?.show())
  memoWindow.on('closed', () => {
    memoWindow = null
  })

  if (process.env['ELECTRON_RENDERER_URL']) {
    memoWindow.loadURL(`${process.env['ELECTRON_RENDERER_URL']}/memo.html`)
  } else {
    memoWindow.loadFile(join(__dirname, '../renderer/memo.html'))
  }

  return memoWindow
}
