import { useBuddy } from '../store/useBuddy'

export function Bubble(): JSX.Element | null {
  const bubble = useBuddy((s) => s.bubble)
  const anim = useBuddy((s) => s.anim)
  const hideBubble = useBuddy((s) => s.hideBubble)

  if (anim === 'thinking') {
    return (
      <div className="bubble" data-interactive="true">
        <span className="dots">
          <i />
          <i />
          <i />
        </span>
      </div>
    )
  }

  if (!bubble) return null

  return (
    <div className="bubble" data-interactive="true" onClick={hideBubble}>
      {bubble}
    </div>
  )
}
