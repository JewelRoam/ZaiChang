import { useEffect, useRef } from 'react'
import { Pet } from './components/Pet'
import { Bubble } from './components/Bubble'
import { ChatPanel } from './components/ChatPanel'
import { useBuddy } from './store/useBuddy'
import { breatheDuration, isMoveMotion, nextMotionDelay, pickMotion } from './anim/motions'

const IDLE_MS = 10 * 60 * 1000
const IDLE_CHECK_MS = 30 * 1000

export default function App(): JSX.Element {
  const setAvatar = useBuddy((s) => s.setAvatar)
  const setLines = useBuddy((s) => s.setLines)
  const showBubble = useBuddy((s) => s.showBubble)
  const pickLine = useBuddy((s) => s.pickLine)
  const panelOpen = useBuddy((s) => s.panelOpen)
  const setMotionStyle = useBuddy((s) => s.setMotionStyle)
  const setMotionConfig = useBuddy((s) => s.setMotionConfig)
  const setStatus = useBuddy((s) => s.setStatus)

  const lastActivity = useRef(Date.now())
  const idleEnabled = useRef(true)
  const interactive = useRef(false)
  const lastAvatarId = useRef<string | null>(null)

  // 初始化：形象、台词库、开场问候、空闲开关
  useEffect(() => {
    let alive = true
    void (async () => {
      const [active, lines, idle] = await Promise.all([
        window.buddy.getActiveAvatar(),
        window.buddy.getLines(),
        window.buddy.getIdleChat()
      ])
      if (!alive) return
      setAvatar(active)
      lastAvatarId.current = active.id
      setLines(lines)
      const [persona, motion] = await Promise.all([
        window.buddy.getPersona(active.id),
        window.buddy.getMotionConfig()
      ])
      if (!alive) return
      setMotionStyle(persona.style)
      setMotionConfig(motion)
      idleEnabled.current = idle
      const hello = lines.welcome[Math.floor(Math.random() * Math.max(1, lines.welcome.length))]
      if (hello) showBubble(hello, 4000)
    })()
    return () => {
      alive = false
    }
  }, [setAvatar, setLines, showBubble, setMotionStyle, setMotionConfig])

  // 主进程推送
  useEffect(() => {
    const reloadLines = async (greet: boolean): Promise<void> => {
      const lines = await window.buddy.getLines()
      setLines(lines)
      if (greet && lines.welcome.length > 0) {
        showBubble(lines.welcome[Math.floor(Math.random() * lines.welcome.length)], 4000)
      }
    }
    const offBubble = window.buddy.onBubble((p) => showBubble(p.text, p.durationMs))
    const offAvatar = window.buddy.onAvatarChanged((a) => {
      setAvatar(a)
      // 只有形象真的换了才重载语录并打招呼；切形态、抠图完成之类的广播不打扰用户
      const changed = a.id !== lastAvatarId.current
      lastAvatarId.current = a.id
      if (changed) {
        void reloadLines(true)
        // 性格换了，动作池和节奏也要跟着换
        void window.buddy.getPersona(a.id).then((p) => setMotionStyle(p.style))
      }
    })
    const offLines = window.buddy.onLinesChanged(() => void reloadLines(false))
    const offMotion = window.buddy.onMotionChanged((c) => setMotionConfig(c))
    const offIdle = window.buddy.onIdleChatChanged((v) => {
      idleEnabled.current = v
    })
    return () => {
      offBubble()
      offAvatar()
      offLines()
      offMotion()
      offIdle()
    }
  }, [setAvatar, setLines, showBubble, setMotionStyle, setMotionConfig])

  // 点击穿透：只在命中态发生变化时才发 IPC
  useEffect(() => {
    const onMove = (e: MouseEvent): void => {
      const el = document.elementFromPoint(e.clientX, e.clientY)
      const hit = !!el?.closest('[data-interactive]')
      if (hit !== interactive.current) {
        interactive.current = hit
        void window.buddy.setInteractive(hit)
      }
    }
    window.addEventListener('mousemove', onMove)
    return () => window.removeEventListener('mousemove', onMove)
  }, [])

  // 空闲主动搭话
  useEffect(() => {
    const touch = (): void => {
      lastActivity.current = Date.now()
    }
    window.addEventListener('mousedown', touch)
    window.addEventListener('keydown', touch)
    const timer = setInterval(() => {
      if (!idleEnabled.current) return
      // 深夜不主动说话：半夜被搭子搭话是惊悚而不是陪伴
      if (useBuddy.getState().status?.mood === 'sleepy') return
      if (Date.now() - lastActivity.current < IDLE_MS) return
      lastActivity.current = Date.now()
      const line = pickLine('idle')
      if (line) showBubble(line, 5000)
    }, IDLE_CHECK_MS)
    return () => {
      clearInterval(timer)
      window.removeEventListener('mousedown', touch)
      window.removeEventListener('keydown', touch)
    }
  }, [pickLine, showBubble])

  // 状态：每分钟拉一次（跨小时精力会变），并把呼吸时长写进 CSS 变量
  useEffect(() => {
    const pull = async (): Promise<void> => {
      const status = await window.buddy.getStatus()
      setStatus(status)
      document.documentElement.style.setProperty('--breathe-duration', breatheDuration(status))
    }
    void pull()
    const timer = setInterval(() => void pull(), 60_000)
    return () => clearInterval(timer)
  }, [setStatus])

  // 自发动作：不点它也会偶尔动一下
  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | null = null
    let stopped = false

    const schedule = (): void => {
      const { motionFreq, motionStyle, status } = useBuddy.getState()
      const delay = nextMotionDelay(motionFreq, motionStyle, status)
      if (delay === 0 || stopped) return // 频率设为「关」
      timer = setTimeout(() => {
        const s = useBuddy.getState()
        // 三道闸门：不打断其他状态、面板打开时不打扰、窗口不可见时不空耗
        if (s.anim === 'idle' && !s.panelOpen && !document.hidden) {
          const name = pickMotion(s.motionStyle, s.allowMove, s.lastMotion, s.status)
          if (s.playMotion(name) && isMoveMotion(name)) {
            void window.buddy.strollPet()
          }
        }
        schedule()
      }, delay)
    }

    const onVisibility = (): void => {
      document.body.classList.toggle('hidden', document.hidden)
      if (timer) clearTimeout(timer)
      if (!document.hidden) schedule()
    }

    document.addEventListener('visibilitychange', onVisibility)
    schedule()
    return () => {
      stopped = true
      if (timer) clearTimeout(timer)
      document.removeEventListener('visibilitychange', onVisibility)
    }
  }, [])

  return (
    <div className={`stage ${panelOpen ? 'stage-panel' : ''}`}>
      <ChatPanel />
      <Bubble />
      <Pet />
    </div>
  )
}
