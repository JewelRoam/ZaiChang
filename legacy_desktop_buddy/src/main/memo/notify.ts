import { BrowserWindow } from 'electron'

/** 备忘录数据变化后通知所有窗口刷新（对话新增 todo、定时带过来等场景） */
export function notifyMemoChanged(): void {
  BrowserWindow.getAllWindows().forEach((w) => w.webContents.send('memo:refresh'))
}
