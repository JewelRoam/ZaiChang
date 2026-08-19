import { getPetWindow } from './windows/petWindow'

/** 向桌面搭子推一条气泡；窗口被隐藏时先显示出来 */
export function pushBubble(text: string, durationMs = 3000): void {
  const win = getPetWindow()
  if (!win) return
  if (!win.isVisible()) win.show()
  win.webContents.send('bubble:push', { text, durationMs })
}
