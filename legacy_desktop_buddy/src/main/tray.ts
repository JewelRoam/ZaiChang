import { app, Menu, Tray, nativeImage } from 'electron'
import { getActiveAvatar, setAvatarForm } from './avatar/manager'
import { broadcastAvatarChanged } from './ipc'
import { getPetWindow } from './windows/petWindow'
import { openMemo } from './windows/memoWindow'
import { openSettings } from './windows/settingsWindow'

let tray: Tray | null = null

/** 用 1x1 透明图兜底，避免没有图标资源时 Tray 创建失败 */
function trayIcon(): Electron.NativeImage {
  const img = nativeImage.createFromDataURL(
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAP0lEQVR42u3NsQ0AIAwDwez/' +
      'M7MBLaKgQ0LxnS3Zsm0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOBnHqkGAV0k1p8AAAAASUVORK5CYII='
  )
  img.setTemplateImage(true)
  return img
}

function buildMenu(): Menu {
  const win = getPetWindow()
  const visible = !!win?.isVisible()
  const form = getActiveAvatar().form
  return Menu.buildFromTemplate([
    {
      label: visible ? '隐藏搭子' : '显示搭子',
      click: () => {
        const w = getPetWindow()
        if (!w) return
        visible ? w.hide() : w.show()
        refreshTrayMenu()
      }
    },
    { type: 'separator' },
    {
      label: '原始形态',
      type: 'radio',
      checked: form === 'original',
      click: () => {
        setAvatarForm('original')
        broadcastAvatarChanged()
      }
    },
    {
      label: 'Q 版形态',
      type: 'radio',
      checked: form === 'chibi',
      click: () => {
        setAvatarForm('chibi')
        broadcastAvatarChanged()
      }
    },
    { type: 'separator' },
    { label: '今日备忘…', click: () => openMemo() },
    { label: '设置…', click: () => openSettings() },
    { label: '退出', click: () => app.quit() }
  ])
}

export function refreshTrayMenu(): void {
  tray?.setContextMenu(buildMenu())
}

export function createTray(): void {
  tray = new Tray(trayIcon())
  tray.setToolTip('桌面搭子')
  refreshTrayMenu()
}
