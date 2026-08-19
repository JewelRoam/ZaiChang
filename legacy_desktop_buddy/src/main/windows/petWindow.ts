import { BrowserWindow, screen, shell } from 'electron'
import { join } from 'node:path'

export const PET_WIDTH = 420
export const PET_HEIGHT = 560

let petWindow: BrowserWindow | null = null

export function getPetWindow(): BrowserWindow | null {
  return petWindow && !petWindow.isDestroyed() ? petWindow : null
}

/** 计算默认位置：主屏右下角，留 40px 边距 */
export function defaultPetPosition(): { x: number; y: number } {
  const { workArea } = screen.getPrimaryDisplay()
  return {
    x: Math.round(workArea.x + workArea.width - PET_WIDTH - 40),
    y: Math.round(workArea.y + workArea.height - PET_HEIGHT - 40)
  }
}

/** 位置是否还落在任意一块屏幕的工作区内（允许部分重叠） */
export function isPositionVisible(pos: { x: number; y: number }): boolean {
  return screen.getAllDisplays().some((d) => {
    const a = d.workArea
    return (
      pos.x + PET_WIDTH > a.x &&
      pos.x < a.x + a.width &&
      pos.y + PET_HEIGHT > a.y &&
      pos.y < a.y + a.height
    )
  })
}

export function createPetWindow(initialPosition: { x: number; y: number } | null): BrowserWindow {
  const pos =
    initialPosition && isPositionVisible(initialPosition) ? initialPosition : defaultPetPosition()

  petWindow = new BrowserWindow({
    width: PET_WIDTH,
    height: PET_HEIGHT,
    x: pos.x,
    y: pos.y,
    transparent: true,
    frame: false,
    hasShadow: false,
    resizable: false,
    movable: true,
    maximizable: false,
    fullscreenable: false,
    skipTaskbar: true,
    show: false,
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false
    }
  })

  // screen-saver 层级保证浮在普通置顶窗口之上
  petWindow.setAlwaysOnTop(true, 'screen-saver')
  petWindow.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: false })
  // 默认全穿透，渲染进程命中形象时再关掉
  petWindow.setIgnoreMouseEvents(true, { forward: true })

  petWindow.on('ready-to-show', () => petWindow?.show())
  petWindow.on('closed', () => {
    petWindow = null
  })
  petWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url)
    return { action: 'deny' }
  })

  if (process.env['ELECTRON_RENDERER_URL']) {
    petWindow.loadURL(`${process.env['ELECTRON_RENDERER_URL']}/pet.html`)
  } else {
    petWindow.loadFile(join(__dirname, '../renderer/pet.html'))
  }

  return petWindow
}

export function setPetInteractive(interactive: boolean): void {
  const win = getPetWindow()
  if (!win) return
  win.setIgnoreMouseEvents(!interactive, { forward: true })
}
