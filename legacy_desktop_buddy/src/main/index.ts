import { app, BrowserWindow, screen } from 'electron'
import { clearAllReminders } from './scheduler'
import { initMemoSchedule, stopMemoSchedule } from './memo/schedule'
import { registerIpc } from './ipc'
import { registerBuddyProtocolHandler, registerBuddyScheme } from './protocol'
import { getPetPosition, setPetPosition } from './store'
import { createTray, refreshTrayMenu } from './tray'
import {
  createPetWindow,
  defaultPetPosition,
  getPetWindow,
  isPositionVisible
} from './windows/petWindow'

registerBuddyScheme()

const gotLock = app.requestSingleInstanceLock()
if (!gotLock) {
  console.warn('[buddy] 已有实例在运行，本次启动退出')
  app.quit()
} else {
  app.on('second-instance', () => {
    const win = getPetWindow()
    if (win) {
      win.show()
      refreshTrayMenu()
    }
  })

  app.whenReady().then(() => {
    registerBuddyProtocolHandler()
    registerIpc()

    const win = createPetWindow(getPetPosition())
    win.on('show', refreshTrayMenu)
    win.on('hide', refreshTrayMenu)
    createTray()
    initMemoSchedule()

    // 分辨率/显示器变化后，窗口跑到屏幕外就复位
    screen.on('display-metrics-changed', resetPetIfOffscreen)
    screen.on('display-removed', resetPetIfOffscreen)

    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) createPetWindow(getPetPosition())
    })
  })

  // 托盘常驻应用，关掉窗口不退出
  app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit()
  })

  app.on('before-quit', () => {
    clearAllReminders()
    stopMemoSchedule()
  })
}

function resetPetIfOffscreen(): void {  const win = getPetWindow()
  if (!win) return
  const [x, y] = win.getPosition()
  if (isPositionVisible({ x, y })) return
  const pos = defaultPetPosition()
  win.setPosition(pos.x, pos.y)
  setPetPosition(pos)
}
