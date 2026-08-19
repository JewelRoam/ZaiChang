import { useEffect, useRef, useState } from 'react'
import { useBuddy } from '../store/useBuddy'

export function ChatPanel(): JSX.Element | null {
  const open = useBuddy((s) => s.panelOpen)
  const messages = useBuddy((s) => s.messages)
  const sending = useBuddy((s) => s.sending)
  const addMessage = useBuddy((s) => s.addMessage)
  const setSending = useBuddy((s) => s.setSending)
  const setAnim = useBuddy((s) => s.setAnim)
  const showBubble = useBuddy((s) => s.showBubble)
  const setPanelOpen = useBuddy((s) => s.setPanelOpen)

  const [text, setText] = useState('')
  const listRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (open) inputRef.current?.focus()
  }, [open])

  useEffect(() => {
    listRef.current?.scrollTo({ top: listRef.current.scrollHeight })
  }, [messages, sending])

  if (!open) return null

  const send = async (): Promise<void> => {
    const value = text.trim()
    if (!value || sending) return
    setText('')
    addMessage('user', value)
    setSending(true)
    setAnim('thinking')
    const res = await window.buddy.chat(value)
    setSending(false)
    addMessage('buddy', res.text)
    setAnim('talking')
    showBubble(res.text, 4000)
    if (!res.ok && res.kind === 'no-config') window.buddy.openSettings()
  }

  return (
    <div className="panel" data-interactive="true">
      <div className="panel-head">
        <span>搭搭</span>
        <button className="ghost" onClick={() => setPanelOpen(false)} title="收起">
          ×
        </button>
      </div>
      <div className="panel-list" ref={listRef}>
        {messages.length === 0 && (
          <div className="tip">试试说：20 分钟后提醒我喝水 / 打开 https://www.baidu.com</div>
        )}
        {messages.map((m) => (
          <div key={m.id} className={`msg msg-${m.role}`}>
            {m.text}
          </div>
        ))}
        {sending && <div className="msg msg-buddy">…</div>}
      </div>
      <div className="panel-input">
        <button
          className="ghost voice"
          disabled
          title="MVP 暂不支持语音输入"
          onClick={() => window.buddy.startAsr()}
        >
          🎤
        </button>
        <input
          ref={inputRef}
          value={text}
          placeholder="想让我干点啥…"
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.nativeEvent.isComposing) send()
            if (e.key === 'Escape') setPanelOpen(false)
          }}
        />
        <button className="primary" disabled={sending || !text.trim()} onClick={send}>
          发送
        </button>
      </div>
    </div>
  )
}
