import { screen } from 'electron'
import { getPetWindow, PET_HEIGHT, PET_WIDTH } from './windows/petWindow'
import { setPetPosition } from './store'

const FRAME_MS = 60

let running = false

/** 用户一拖拽就中止走动，并以当前位置为新原点 */
export function abortStroll(): void {
  running = false
}

function clampToWorkArea(x: number, y: number): { x: number; y: number } {
  const display = screen.getDisplayNearestPoint({ x, y })
  const a = display.workArea
  return {
    x: Math.min(Math.max(x, a.x), a.x + a.width - PET_WIDTH),
    y: Math.min(Math.max(y, a.y), a.y + a.height - PET_HEIGHT)
  }
}

/**
 * 在桌面上走一段再走回来。分帧移动窗口，不用动画库。
 * 目标位置先 clamp 到当前屏幕工作区，走完回原位并持久化，避免越走越偏。
 */
export async function strollPet(): Promise<void> {
  const win = getPetWindow()
  if (!win || running) return
  running = true

  const [startX, startY] = win.getPosition()
  const distance = (120 + Math.round(Math.random() * 140)) * (Math.random() < 0.5 ? -1 : 1)
  const target = clampToWorkArea(startX + distance, startY)
  const actual = target.x - startX
  if (Math.abs(actual) < 20) {
    running = false
    return
  }

  const steps = 24
  const step = async (from: number, to: number): Promise<void> => {
    for (let i = 1; i <= steps; i++) {
      if (!running) return
      const w = getPetWindow()
      if (!w) return
      const x = Math.round(from + ((to - from) * i) / steps)
      w.setPosition(x, startY)
      await new Promise((r) => setTimeout(r, FRAME_MS))
    }
  }

  await step(startX, startX + actual)
  await new Promise((r) => setTimeout(r, 200))
  await step(startX + actual, startX)

  if (running) {
    const w = getPetWindow()
    if (w) {
      w.setPosition(startX, startY)
      setPetPosition({ x: startX, y: startY })
    }
  }
  running = false
}
