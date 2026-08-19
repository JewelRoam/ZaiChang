import { useEffect, useRef } from 'react'
import { animClass } from '../anim/state'
import { pickMotion, isMoveMotion } from '../anim/motions'
import { useBuddy } from '../store/useBuddy'
import defaultAvatar from '../assets/default-avatar'

const DRAG_THRESHOLD = 4

export function Pet(): JSX.Element {
  const avatar = useBuddy((s) => s.avatar)
  const anim = useBuddy((s) => s.anim)
  const showBubble = useBuddy((s) => s.showBubble)
  const pickLine = useBuddy((s) => s.pickLine)
  const togglePanel = useBuddy((s) => s.togglePanel)
  const playMotion = useBuddy((s) => s.playMotion)
  const lastMotion = useBuddy((s) => s.lastMotion)
  const motionStyle = useBuddy((s) => s.motionStyle)
  const status = useBuddy((s) => s.status)
  const setStatus = useBuddy((s) => s.setStatus)

  const dragging = useRef(false)
  const moved = useRef(false)
  const lastPos = useRef({ x: 0, y: 0 })
  const clickTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    const onMove = (e: MouseEvent): void => {
      if (!dragging.current) return
      const dx = e.screenX - lastPos.current.x
      const dy = e.screenY - lastPos.current.y
      if (!moved.current && Math.abs(dx) + Math.abs(dy) < DRAG_THRESHOLD) return
      moved.current = true
      lastPos.current = { x: e.screenX, y: e.screenY }
      window.buddy.movePet(dx, dy)
    }
    const onUp = (): void => {
      if (!dragging.current) return
      dragging.current = false
      if (moved.current) window.buddy.movePetEnd()
    }
    window.addEventListener('mousemove', onMove)
    window.addEventListener('mouseup', onUp)
    return () => {
      window.removeEventListener('mousemove', onMove)
      window.removeEventListener('mouseup', onUp)
    }
  }, [])

  const onMouseDown = (e: React.MouseEvent): void => {
    if (e.button !== 0) return
    dragging.current = true
    moved.current = false
    lastPos.current = { x: e.screenX, y: e.screenY }
  }

  // 用延时区分单击/双击：双击时取消已排队的单击反馈
  const onClick = (): void => {
    if (moved.current) return
    if (clickTimer.current) clearTimeout(clickTimer.current)
    clickTimer.current = setTimeout(() => {
      const line = pickLine('click')
      if (line) showBubble(line, 3000)
      // 点击动作按性格随机取，走动类动作不放进点击池——点一下就跑走很奇怪
      const name = pickMotion(motionStyle, false, lastMotion, status)
      if (!isMoveMotion(name)) playMotion(name)
      // 互动加好感度，主进程会做每日上限约束
      void window.buddy.bumpStatus('click').then(setStatus)
    }, 220)
  }

  const onDoubleClick = (): void => {
    if (clickTimer.current) clearTimeout(clickTimer.current)
    togglePanel()
  }

  return (
    <div
      className="pet-wrap"
      data-interactive="true"
      onMouseDown={onMouseDown}
      onClick={onClick}
      onDoubleClick={onDoubleClick}
      onContextMenu={(e) => {
        e.preventDefault()
        window.buddy.showContextMenu()
      }}
    >
      <img
        className={animClass(anim)}
        src={avatar.url ?? defaultAvatar}
        alt="桌面搭子"
        draggable={false}
      />
    </div>
  )
}
