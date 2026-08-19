import { useEffect, useMemo, useState } from 'react'
import type {
  AvatarForm,
  AvatarMeta,
  AvatarPreview,
  BuddyStatus,
  DiagnoseResult,
  LineStyle,
  MemoConfig,
  ModelConfig,
  MotionConfig,
  MotionFreq,
  Persona
} from '@shared/types'

type Toast = { kind: 'ok' | 'err'; text: string } | null
type Busy = 'matting' | 'chibi' | 'test' | 'lines' | null

const MOOD_TEXT: Record<string, string> = {
  sleepy: '睡意朦胧',
  lonely: '有点孤单',
  low: '还有点生分',
  normal: '平静',
  happy: '心情不错'
}

export function SettingsView(): JSX.Element {
  const [avatars, setAvatars] = useState<AvatarMeta[]>([])
  const [previews, setPreviews] = useState<Record<string, AvatarPreview>>({})
  const [activeId, setActiveId] = useState<string | null>(null)
  const [activeForm, setActiveForm] = useState<AvatarForm>('original')
  const [selId, setSelId] = useState<string | null>(null)
  const [selForm, setSelForm] = useState<AvatarForm>('original')
  const [model, setModel] = useState<ModelConfig | null>(null)
  const [memo, setMemo] = useState<MemoConfig | null>(null)
  const [motion, setMotion] = useState<MotionConfig | null>(null)
  const [status, setStatus] = useState<BuddyStatus | null>(null)
  const [idleChat, setIdleChat] = useState(true)
  const [toast, setToast] = useState<Toast>(null)
  const [busy, setBusy] = useState<Busy>(null)
  const [diag, setDiag] = useState<DiagnoseResult | null>(null)
  const [saved, setSaved] = useState(false)
  const [persona, setPersona] = useState<Persona | null>(null)
  const [clickText, setClickText] = useState('')
  const [idleText, setIdleText] = useState('')

  const notify = (kind: 'ok' | 'err', text: string): void => {
    setToast({ kind, text })
    setTimeout(() => setToast(null), 5000)
  }

  const loadAvatars = async (): Promise<AvatarMeta[]> => {
    const list = await window.buddy.listAvatars()
    setAvatars(list)
    const entries = await Promise.all(
      list.map(async (a) => [a.id, await window.buddy.getAvatarPreview(a.id)] as const)
    )
    setPreviews(Object.fromEntries(entries))
    return list
  }

  useEffect(() => {
    void (async () => {
      const list = await loadAvatars()
      const active = await window.buddy.getActiveAvatar()
      setActiveId(active.id)
      setActiveForm(active.form)
      setSelId(active.id ?? list[0]?.id ?? null)
      setSelForm(active.form)
      setModel(await window.buddy.getModelConfig())
      setMemo(await window.buddy.getMemoConfig())
      setMotion(await window.buddy.getMotionConfig())
      setStatus(await window.buddy.getStatus())
      setIdleChat(await window.buddy.getIdleChat())
    })()
    return window.buddy.onAvatarChanged((a) => {
      setActiveId(a.id)
      setActiveForm(a.form)
      void loadAvatars()
    })
  }, [])
  const selected = useMemo(() => avatars.find((a) => a.id === selId) ?? null, [avatars, selId])

  // 选中的形象变了，载入它的人格
  useEffect(() => {
    void window.buddy.getPersona(selId).then((p) => {
      setPersona(p)
      setClickText((p.lines?.click ?? []).join('\n'))
      setIdleText((p.lines?.idle ?? []).join('\n'))
    })
  }, [selId])

  const modelReady = !!model?.baseUrl && !!model?.apiKey && !!model?.model

  const onSavePersona = async (): Promise<void> => {
    if (!persona) return
    const click = clickText.split('\n').map((s) => s.trim()).filter(Boolean)
    const idle = idleText.split('\n').map((s) => s.trim()).filter(Boolean)
    const next = await window.buddy.setPersona(selId, {
      ...persona,
      lines: click.length || idle.length ? { click, idle } : null
    })
    setPersona(next)
    notify('ok', '性格已保存，对话历史一起清了（避免旧语气串味）')
  }

  const onGenerateLines = async (): Promise<void> => {
    if (!persona) return
    // 先保存性格，否则生成用的是上一次保存的描述
    await window.buddy.setPersona(selId, persona)
    setBusy('lines')
    const res = await window.buddy.generatePersonaLines(selId)
    setBusy(null)
    if (!res.ok) {
      notify('err', res.error)
      return
    }
    setClickText(res.click.join('\n'))
    setIdleText(res.idle.join('\n'))
    notify(
      'ok',
      res.padded
        ? `生成了 ${res.click.length} 条点击语录（部分用内置补齐），确认后点「保存性格」`
        : `生成了 ${res.click.length} 条点击语录，确认后点「保存性格」`
    )
  }

  const selPreview = selId ? previews[selId] : undefined

  /** 预览区大图：按选中形态 + 是否用抠图结果解析 */
  const previewUrl = useMemo(() => {
    if (!selPreview || !selected) return null
    if (selForm === 'chibi') return selPreview.chibiAi ?? selPreview.chibi ?? selPreview.original
    return selected.useCutout ? (selPreview.cutout ?? selPreview.original) : selPreview.original
  }, [selPreview, selected, selForm])

  const thumbUrl = (a: AvatarMeta): string | null => {
    const p = previews[a.id]
    if (!p) return null
    return (a.useCutout ? p.cutout : null) ?? p.original ?? p.chibi
  }

  const isApplied = selId === activeId && selForm === activeForm
  const aiChibiReady =
    !!(model?.imageApiKey.trim() || model?.apiKey) &&
    (model?.imageStyle === 'dashscope' ? !!model.imageEndpoint : !!model?.imageBaseUrl)
  const mattingReady = !!model?.mattingUrl

  const onUpload = async (): Promise<void> => {
    const res = await window.buddy.pickAvatar()
    if (res.ok && res.meta) {
      await loadAvatars()
      setSelId(res.meta.id)
      notify('ok', `已导入「${res.meta.name}」，抠好图后点「应用到桌面」`)
    } else if (res.error) {
      notify('err', res.error)
    }
  }

  const onMatting = async (): Promise<void> => {
    if (!selId) return
    setBusy('matting')
    const res = await window.buddy.removeAvatarBackground(selId)
    setBusy(null)
    await loadAvatars()
    res.ok ? notify('ok', '抠图完成，Q 版也用抠图结果重做了') : notify('err', res.error ?? '抠图失败')
  }

  const onAiChibi = async (): Promise<void> => {
    if (!selId) return
    const force = !!selected?.chibiAiPath
    if (force && !confirm('已经有 AI Q 版了，重新生成会再消耗一次额度，确定吗？')) return
    setBusy('chibi')
    const res = await window.buddy.generateAiChibi(selId, force)
    setBusy(null)
    await loadAvatars()
    if (res.ok) {
      setSelForm('chibi')
      notify(res.warning ? 'err' : 'ok', res.warning ?? 'AI Q 版生成好了')
    } else {
      notify('err', res.error ?? 'AI Q 版生成失败')
    }
  }

  const onApply = async (): Promise<void> => {
    await window.buddy.switchAvatar(selId, selForm)
    notify('ok', '已应用到桌面')
  }

  const onTest = async (): Promise<void> => {
    if (!model) return
    await window.buddy.setModelConfig(model)
    setBusy('test')
    setDiag(null)
    setDiag(await window.buddy.testConnection())
    setBusy(null)
  }

  const saveModel = async (): Promise<void> => {
    if (!model) return
    setModel(await window.buddy.setModelConfig(model))
    setSaved(true)
    setTimeout(() => setSaved(false), 2000)
  }

  const missing = model
    ? [
        !model.baseUrl.trim() && '接口地址',
        !model.apiKey.trim() && 'apiKey',
        !model.model.trim() && '模型名'
      ].filter(Boolean)
    : []
  return (
    <div className="wrap">
      {toast && <div className={`toast ${toast.kind}`}>{toast.text}</div>}

      <section>
        <h2>形象</h2>
        <p className="hint">
          点缩略图只是预览，不会动桌面上的搭子；选好形象和形态后点「应用到桌面」才生效。
          （托盘和右键菜单里的形态切换是快捷操作，即时生效。）
        </p>
        <div className="two-col">
          <div className="lib">
            <div className="grid">
              {avatars.map((a) => (
                <div
                  key={a.id}
                  className={`card ${selId === a.id ? 'sel' : ''} ${activeId === a.id ? 'active' : ''}`}
                  onClick={() => setSelId(a.id)}
                  title={a.broken ? '素材文件已丢失' : a.name}
                >
                  <div className="thumb">
                    {a.broken ? (
                      <span className="broken">素材丢失</span>
                    ) : (
                      thumbUrl(a) && <img src={thumbUrl(a)!} alt={a.name} />
                    )}
                  </div>
                  <div className="card-name">{a.name}</div>
                  <div className="tags">
                    {activeId === a.id && <em className="tag on">使用中</em>}
                    {a.cutoutPath && <em className="tag">已抠图</em>}
                    {a.chibiAiPath && <em className="tag">AI Q 版</em>}
                  </div>
                  <button
                    className="del"
                    title="删除"
                    onClick={async (e) => {
                      e.stopPropagation()
                      await window.buddy.deleteAvatar(a.id)
                      const list = await loadAvatars()
                      if (selId === a.id) setSelId(list[0]?.id ?? null)
                    }}
                  >
                    ×
                  </button>
                </div>
              ))}
              <button className="card upload" onClick={onUpload}>
                ＋ 上传形象
              </button>
            </div>
            <p className="hint small">
              支持 PNG / JPG / WebP，10MB 以内，短边 ≥128px。上传后建议先「AI 抠图」去掉背景。
            </p>
          </div>

          <div className="preview">
            <div className="big">
              {previewUrl ? <img src={previewUrl} alt="预览" /> : <span className="none">还没有形象，先上传一张</span>}
            </div>
            <div className="row">
              <label>
                <input type="radio" checked={selForm === 'original'} onChange={() => setSelForm('original')} />
                原始形态
              </label>
              <label>
                <input type="radio" checked={selForm === 'chibi'} onChange={() => setSelForm('chibi')} />
                Q 版形态
              </label>
            </div>
            {selected && (
              <label className="row">
                <input
                  type="checkbox"
                  checked={selected.useCutout}
                  disabled={!selected.cutoutPath}
                  onChange={async (e) => {
                    await window.buddy.setUseCutout(selected.id, e.target.checked)
                    await loadAvatars()
                  }}
                />
                使用抠图结果（去背景）
              </label>
            )}
            <div className="row ops">
              <button
                disabled={!selId || !mattingReady || busy !== null || !!selected?.broken}
                title={mattingReady ? '' : '需要先在下方填写抠图接口地址'}
                onClick={onMatting}
              >
                {busy === 'matting' ? '抠图中…' : 'AI 抠图'}
              </button>
              <button
                disabled={!selId || !aiChibiReady || busy !== null || !!selected?.broken}
                title={aiChibiReady ? '' : '需要先填写图像接口地址和 apiKey'}
                onClick={onAiChibi}
              >
                {busy === 'chibi'
                  ? '生成中…'
                  : selected?.chibiAiPath
                    ? '重新生成 AI Q 版'
                    : 'AI Q 版'}
              </button>
            </div>
            <button className="primary block" disabled={!selId || isApplied} onClick={onApply}>
              {isApplied ? '已是当前形象' : '应用到桌面'}
            </button>
            <p className="hint small">
              Q 版优先用 AI 产物；没有 AI 产物时用本地卡通化（头部放大 + 身体压缩），后者对半身像效果最好。
            </p>

            <div className="persona">
              <h3>性格{selId ? '（这个形象专属）' : '（默认，未选形象时生效）'}</h3>
              {persona && (
                <>
                  <label className="field">
                    <span>名字</span>
                    <input
                      value={persona.name}
                      maxLength={10}
                      onChange={(e) => setPersona({ ...persona, name: e.target.value })}
                    />
                  </label>
                  <label className="field">
                    <span>性格描述（{persona.prompt.length}/500）</span>
                    <textarea
                      rows={4}
                      value={persona.prompt}
                      maxLength={500}
                      placeholder="例如：有点毒舌但其实很关心我，喜欢吐槽我摸鱼，说话简短"
                      onChange={(e) => setPersona({ ...persona, prompt: e.target.value })}
                    />
                  </label>
                  <label className="field">
                    <span>语录风格（没生成 AI 语录时用这套）</span>
                    <select
                      value={persona.style}
                      onChange={(e) =>
                        setPersona({ ...persona, style: e.target.value as LineStyle })
                      }
                    >
                      <option value="default">标准 · 轻松略调侃</option>
                      <option value="genki">元气 · 热情爱鼓励</option>
                      <option value="cool">高冷 · 话少克制</option>
                      <option value="savage">毒舌 · 嘴硬爱怼</option>
                      <option value="gentle">温柔 · 体贴关心</option>
                    </select>
                  </label>
                  <div className="row ops">
                    <button disabled={busy !== null || !modelReady} onClick={onGenerateLines}>
                      {busy === 'lines' ? '生成中…' : '按性格生成语录'}
                    </button>
                    <button className="primary" onClick={onSavePersona}>
                      保存性格
                    </button>
                  </div>
                  <label className="field">
                    <span>点击语录（一行一句，共 {clickText.split('\n').filter(Boolean).length} 条）</span>
                    <textarea
                      rows={6}
                      value={clickText}
                      onChange={(e) => setClickText(e.target.value)}
                    />
                  </label>
                  <label className="field">
                    <span>空闲语录（一行一句，共 {idleText.split('\n').filter(Boolean).length} 条）</span>
                    <textarea
                      rows={4}
                      value={idleText}
                      onChange={(e) => setIdleText(e.target.value)}
                    />
                  </label>
                  <p className="hint small">
                    语录框留空则用上面选的风格包（每套 30 条点击 + 12 条空闲）。点击台词是本地随机取的，
                    不会实时调模型——所以点一下就有反应，也不花钱。
                  </p>
                </>
              )}
            </div>
          </div>
        </div>
      </section>
      <section>
        <h2>模型配置</h2>
        <p className="hint">
          OpenAI 兼容接口。三项必填：接口地址、apiKey、模型名——缺任意一项对话都用不了。
          apiKey 以明文保存在本机配置文件里，不要在共用电脑上填写。
        </p>
        {missing.length > 0 && <div className="warn">还没填：{missing.join('、')}</div>}
        {model && (
          <div className="form">
            <label className="field">
              <span>接口地址（baseUrl）</span>
              <input
                className={!model.baseUrl.trim() ? 'bad' : ''}
                value={model.baseUrl}
                placeholder="https://xxx.com/v1"
                onChange={(e) => setModel({ ...model, baseUrl: e.target.value })}
              />
            </label>
            <label className="field">
              <span>apiKey</span>
              <input
                className={!model.apiKey.trim() ? 'bad' : ''}
                type="password"
                value={model.apiKey}
                onChange={(e) => setModel({ ...model, apiKey: e.target.value })}
              />
            </label>
            <label className="field">
              <span>模型名</span>
              <input
                className={!model.model.trim() ? 'bad' : ''}
                value={model.model}
                placeholder="例如 gpt-4o-mini"
                onChange={(e) => setModel({ ...model, model: e.target.value })}
              />
            </label>
            <label className="field">
              <span>temperature（{model.temperature}）</span>
              <input
                type="range"
                min={0}
                max={2}
                step={0.1}
                value={model.temperature}
                onChange={(e) => setModel({ ...model, temperature: Number(e.target.value) })}
              />
            </label>
            <label className="field">
              <span>图像 / 抠图服务的 apiKey（和对话不同家时填这里）</span>
              <input
                type="password"
                value={model.imageApiKey}
                placeholder="留空则用上面对话的 apiKey"
                onChange={(e) => setModel({ ...model, imageApiKey: e.target.value })}
              />
            </label>
            <label className="field">
              <span>图像接口协议</span>
              <select
                value={model.imageStyle}
                onChange={(e) =>
                  setModel({ ...model, imageStyle: e.target.value as 'openai' | 'dashscope' })
                }
              >
                <option value="dashscope">阿里云百炼 DashScope（推荐，qwen 图像编辑）</option>
                <option value="openai">OpenAI 兼容（/images/edits）</option>
              </select>
            </label>
            {model.imageStyle === 'dashscope' ? (
              <label className="field">
                <span>图像接口地址（完整地址，含路径）</span>
                <input
                  value={model.imageEndpoint}
                  placeholder="https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
                  onChange={(e) => setModel({ ...model, imageEndpoint: e.target.value })}
                />
              </label>
            ) : (
              <label className="field">
                <span>图像接口地址（base，如 .../v1）</span>
                <input
                  value={model.imageBaseUrl}
                  placeholder="留空则禁用 AI Q 版"
                  onChange={(e) => setModel({ ...model, imageBaseUrl: e.target.value })}
                />
              </label>
            )}
            <label className="field">
              <span>图像模型名</span>
              <input
                value={model.imageModel}
                placeholder={
                  model.imageStyle === 'dashscope' ? 'qwen-image-edit-plus' : 'gpt-image-1'
                }
                onChange={(e) => setModel({ ...model, imageModel: e.target.value })}
              />
            </label>
            <label className="field">
              <span>图像模型名</span>
              <input
                value={model.imageModel}
                placeholder="例如 gpt-image-1"
                onChange={(e) => setModel({ ...model, imageModel: e.target.value })}
              />
            </label>
            <label className="field">
              <span>抠图接口地址（AI 抠图用，可留空）</span>
              <input
                value={model.mattingUrl}
                placeholder="rembg 形态填完整地址；OpenAI 形态填 .../v1"
                onChange={(e) => setModel({ ...model, mattingUrl: e.target.value })}
              />
            </label>
            <label className="field">
              <span>抠图接口协议</span>
              <select
                value={model.mattingStyle}
                onChange={(e) =>
                  setModel({ ...model, mattingStyle: e.target.value as 'rembg' | 'openai' })
                }
              >
                <option value="rembg">rembg 风格（multipart 上传，直接返回 PNG）</option>
                <option value="openai">OpenAI 兼容（/images/edits）</option>
              </select>
            </label>
            <div className="row">
              <button className="primary" onClick={saveModel}>
                保存
              </button>
              <button disabled={busy !== null} onClick={onTest}>
                {busy === 'test' ? '测试中…' : '测试连接'}
              </button>
              {saved && <span className="ok-text">已保存</span>}
            </div>
            {diag && (
              <div className={`diag ${diag.ok ? (diag.toolsSupported ? 'ok' : 'warn') : 'err'}`}>
                {diag.message}
              </div>
            )}
          </div>
        )}
      </section>
      <section>
        <h2>备忘录</h2>
        {memo && (
          <div className="form">
            <label className="row">
              <input
                type="checkbox"
                checked={memo.enabled}
                onChange={async (e) => setMemo(await window.buddy.setMemoConfig({ enabled: e.target.checked }))}
              />
              每天定时弹出今日备忘
            </label>
            <label className="field short">
              <span>弹出时间（HH:mm）</span>
              <input
                value={memo.popupTime}
                placeholder="09:00"
                onChange={(e) => setMemo({ ...memo, popupTime: e.target.value })}
                onBlur={async () => setMemo(await window.buddy.setMemoConfig({ popupTime: memo.popupTime }))}
              />
            </label>
            <label className="row">
              <input
                type="checkbox"
                checked={memo.carryOver}
                onChange={async (e) => setMemo(await window.buddy.setMemoConfig({ carryOver: e.target.checked }))}
              />
              昨天没做完的事自动带到今天
            </label>
            <div className="row">
              <button onClick={() => window.buddy.openMemo()}>现在打开今日备忘</button>
            </div>
            <p className="hint small">
              启动时如果已经过了弹出时间、且当天还没弹过，会补弹一次。单条事项可以设提醒时间，
              到点由搭子用气泡提醒；提醒只在应用运行期间有效。
            </p>
          </div>
        )}
      </section>

      <section>
        <h2>互动</h2>
        {status && (
          <div className="status-card">
            <div className="status-row">
              <span className="status-label">好感度</span>
              <div className="bar">
                <i style={{ width: `${status.affinity}%` }} />
              </div>
              <span className="status-val">{status.affinity}</span>
            </div>
            <div className="status-row">
              <span className="status-label">精力</span>
              <div className="bar energy">
                <i style={{ width: `${status.energy}%` }} />
              </div>
              <span className="status-val">{status.energy}</span>
            </div>
            <div className="status-row">
              <span className="status-label">心情</span>
              <span className="mood">{MOOD_TEXT[status.mood]}</span>
              {status.daysSinceSeen > 0 && (
                <span className="hint small">已 {status.daysSinceSeen} 天没互动</span>
              )}
              <button
                className="ghost"
                onClick={async () => {
                  if (!confirm('重置后好感度回到初始值 20，确定吗？')) return
                  setStatus(await window.buddy.resetStatus())
                  notify('ok', '状态已重置')
                }}
              >
                重置状态
              </button>
            </div>
            <p className="hint small">
              点它、和它说话、完成备忘录事项都会积累好感度（每天上限有限制）；连续几天不理会慢慢下降。
              好感度和精力会同时影响它的语气、动作幅度和活跃程度——深夜会犯困，动作变小变少，也不会主动找你说话。
            </p>
          </div>
        )}
        <label className="row">
          <input
            type="checkbox"
            checked={idleChat}
            onChange={(e) => {
              setIdleChat(e.target.checked)
              void window.buddy.setIdleChat(e.target.checked)
            }}
          />
          空闲 10 分钟后主动跟我说话
        </label>
        {motion && (
          <>
            <label className="field short">
              <span>自己做动作的频率</span>
              <select
                value={motion.freq}
                onChange={async (e) =>
                  setMotion(
                    await window.buddy.setMotionConfig({
                      freq: e.target.value as MotionFreq
                    })
                  )
                }
              >
                <option value="off">关（只保留呼吸和点击动作）</option>
                <option value="low">低（1-2.5 分钟一次）</option>
                <option value="normal">正常（20-60 秒一次）</option>
                <option value="high">高（8-25 秒一次）</option>
              </select>
            </label>
            <label className="row">
              <input
                type="checkbox"
                checked={motion.allowMove}
                onChange={async (e) =>
                  setMotion(await window.buddy.setMotionConfig({ allowMove: e.target.checked }))
                }
              />
              允许在桌面上走动（会移动搭子的位置，走完自己回来）
            </label>
            <p className="hint small">
              动作幅度和节奏跟着性格走：元气爱跳、高冷只轻微晃、毒舌爱抖。搭子隐藏或你在用全屏应用时，
              动画会自动停下来不耗电。
            </p>
          </>
        )}
        <p className="hint small">
          内置能力：定时提醒、打开网页或 /Applications 里的应用、记备忘录、闲聊。
        </p>
      </section>
    </div>
  )
}
