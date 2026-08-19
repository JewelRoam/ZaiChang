import React, { useState, useEffect, useRef } from 'react'
import { Play, Image as ImageIcon, Video, Sparkles, Upload, Trash2, Home, Coffee, Users, Radio } from 'lucide-react'
import { toast, Toaster } from 'sonner'

const COLORS = {
  skyTop: '#3a2f4a',
  skyMid: '#7a5c46',
  amber: '#f5b850',
  lampGlow: '#f5b850',
  lampSoft: '#f7d089',
  wood: '#8a5a3c',
  woodDark: '#5e3d28',
  woodDeep: '#3d2818',
  cream: '#fdf3dd',
  panel: '#fff6e4',
  panelInk: '#4a3524',
  muted: '#a07d55',
  night: '#241d33',
}

const pixelBorder = {
  border: `3px solid ${COLORS.woodDark}`,
  boxShadow: `6px 6px 0 ${COLORS.woodDeep}`,
}

const PHOTO_KEY = 'showcase_photos_v1'
const VIDEO_KEY = 'showcase_videos_v1'
const FEATURE_KEY = 'showcase_features_v1'

function Editable({ value, onChange, as = 'span', className = '', style = {} }) {
  const Tag = as
  const ref = useRef(null)
  const handleBlur = () => {
    const text = ref.current ? ref.current.innerText : ''
    if (text !== value) onChange(text)
  }
  return (
    <Tag
      ref={ref}
      className={className}
      style={{ fontFamily: `'Courier New', monospace`, outline: 'none', ...style }}
      contentEditable
      suppressContentEditableWarning
      onBlur={handleBlur}
    >
      {value}
    </Tag>
  )
}

function PixelTitle({ icon: Icon, text }) {
  return (
    <div className="flex items-center gap-2 mb-4">
      <div
        className="flex items-center justify-center"
        style={{
          width: 34,
          height: 34,
          backgroundColor: COLORS.lampGlow,
          border: `3px solid ${COLORS.woodDark}`,
          boxShadow: `3px 3px 0 ${COLORS.woodDeep}`,
        }}
      >
        <Icon size={18} color={COLORS.woodDeep} strokeWidth={2.5} />
      </div>
      <h3
        style={{
          fontFamily: `'Courier New', monospace`,
          color: COLORS.cream,
          fontSize: 20,
          letterSpacing: 2,
          textShadow: `2px 2px 0 ${COLORS.woodDeep}`,
        }}
        className="font-bold"
      >
        {text}
      </h3>
      <div className="flex-1 flex items-center gap-1 ml-1">
        {Array.from({ length: 3 }).map((_, i) => (
          <Sparkles key={i} size={10} color={COLORS.lampGlow} />
        ))}
        <div style={{ flex: 1, height: 3, backgroundColor: COLORS.wood }} />
      </div>
    </div>
  )
}

const ICON_MAP = { Home, Coffee, Users, Radio, Sparkles }

function FeatureCard({ icon: Icon, item, onChange }) {
  return (
    <div className="p-3 flex flex-col gap-2" style={{ background: COLORS.panel, ...pixelBorder }}>
      <div className="flex items-center gap-2">
        <div
          className="flex items-center justify-center"
          style={{ width: 34, height: 34, background: COLORS.lampSoft, border: `3px solid ${COLORS.woodDeep}` }}
        >
          <Icon size={18} color={COLORS.woodDeep} strokeWidth={2.5} />
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          <Editable value={item.title} onChange={(v) => onChange('title', v)} style={{ color: COLORS.panelInk, fontSize: '16px', fontWeight: 700, letterSpacing: '1px' }} />
          <Editable
            value={item.badge}
            onChange={(v) => onChange('badge', v)}
            className="px-2"
            style={{ background: COLORS.woodDark, color: COLORS.cream, fontSize: '14px', border: `2px solid ${COLORS.woodDeep}` }}
          />
        </div>
      </div>
      <Editable as="p" value={item.desc} onChange={(v) => onChange('desc', v)} style={{ color: COLORS.woodDark, fontSize: '14px', lineHeight: 1.7 }} />
    </div>
  )
}

function ProductFeatures() {
  const defaults = [
    { iconName: 'Home', title: '像素小屋', badge: '核心界面', desc: '常驻 Mac 桌面的像素小屋，可见角色、状态与房间变化，也能随时收起为菜单栏图标，减少对工作的干扰。' },
    { iconName: 'Coffee', title: '在场', badge: '状态陪伴', desc: '选择「专注中」「休息一下」「想安静待着」等状态。AI 结合时间、日程与习惯，让角色亮灯、放环境音、整理待办或提醒休息。' },
    { iconName: 'Users', title: '同桌', badge: '轻互动', desc: '通过邀请码邀请好友进入同一间像素房间，各自学习工作，看到对方是否在场、专注或离开，无需持续聊天。' },
    { iconName: 'Radio', title: '留声机', badge: '异步声音', desc: '录一段语音并设置送达时机，如「对方结束工作后」「今晚睡前」。到达后留声机亮起播放，让声音成为可等待的物件。' },
    { iconName: 'Sparkles', title: 'AI 陪伴角色', badge: '有限记忆', desc: '基于授权形成有限记忆：作息、目标、重要日期与陪伴边界。优先简短行动，提醒可关闭，记忆可查看与删除。' },
  ]
  const [features, setFeatures] = useState(defaults)

  useEffect(() => {
    Ku.dataStorage.getItem(FEATURE_KEY).then((v) => {
      if (Array.isArray(v) && v.length) setFeatures(v)
    }).catch(() => {})
  }, [])

  const updateFeature = (idx, key, val) => {
    setFeatures((prev) => {
      const next = prev.map((f, i) => (i === idx ? { ...f, [key]: val } : f))
      Ku.dataStorage.setItem(FEATURE_KEY, next).catch(() => {})
      return next
    })
  }

  return (
    <div className="flex flex-col gap-3">
      <PixelTitle icon={Home} text="产品功能" />
      {features.map((f, i) => (
        <FeatureCard
          key={i}
          icon={ICON_MAP[f.iconName] || Sparkles}
          item={f}
          onChange={(key, val) => updateFeature(i, key, val)}
        />
      ))}
    </div>
  )
}

function PhotoStack() {
    const tints = ['#4a3d5e', '#5e4a3d', '#3d5e4a', '#5e5a3d', '#5e3d48']
  const slots = Array.from({ length: 15 }).map((_, i) => ({
    id: i + 1,
    label: `功能截图 ${String(i + 1).padStart(2, '0')}`,
    tint: tints[i % tints.length],
  }))
  const [order, setOrder] = useState(slots.map((s) => s.id))
  const [urls, setUrls] = useState({})
  const [bgColors, setBgColors] = useState({})
  const [uploadingId, setUploadingId] = useState(null)
  const fileRef = useRef(null)
  const targetId = useRef(null)

  useEffect(() => {
    Ku.dataStorage.getItem(PHOTO_KEY).then((v) => {
      if (v && typeof v === 'object') setUrls(v)
    }).catch(() => {})
  }, [])

  const handleImgLoad = (id, e) => {
    try {
      const img = e.target
      const w = 24
      const h = 24
      const canvas = document.createElement('canvas')
      canvas.width = w
      canvas.height = h
      const ctx = canvas.getContext('2d')
      ctx.drawImage(img, 0, 0, w, h)
      const data = ctx.getImageData(0, 0, w, h).data
      const edges = []
      for (let x = 0; x < w; x++) {
        edges.push([x, 0])
        edges.push([x, h - 1])
      }
      for (let y = 0; y < h; y++) {
        edges.push([0, y])
        edges.push([w - 1, y])
      }
      let r = 0
      let g = 0
      let b = 0
      edges.forEach(([x, y]) => {
        const i = (y * w + x) * 4
        r += data[i]
        g += data[i + 1]
        b += data[i + 2]
      })
      const n = edges.length
      const color = `rgb(${Math.round(r / n)}, ${Math.round(g / n)}, ${Math.round(b / n)})`
      setBgColors((prev) => ({ ...prev, [id]: color }))
    } catch (err) {
      // 跨域受限时忽略，退回默认色
    }
  }

  const persist = (next) => {
    setUrls(next)
    Ku.dataStorage.setItem(PHOTO_KEY, next).catch(() => {})
  }

  const handleNext = () => {
    setOrder((prev) => {
      const next = [...prev]
      const top = next.shift()
      next.push(top)
      return next
    })
  }

  const triggerUpload = (id) => {
    targetId.current = id
    if (fileRef.current) {
      fileRef.current.value = ''
      fileRef.current.click()
    }
  }

  const isHeif = (file) => {
    const name = (file.name || '').toLowerCase()
    const type = (file.type || '').toLowerCase()
    return (
      type === 'image/heic' ||
      type === 'image/heif' ||
      name.endsWith('.heic') ||
      name.endsWith('.heif')
    )
  }

  const onFileChange = async (e) => {
    const file = e.target.files && e.target.files[0]
    if (!file) return
    const id = targetId.current
    if (isHeif(file)) {
      toast.error('暂不支持 HEIF/HEIC 格式（多数浏览器无法显示），请转成 JPG 或 PNG 后再上传')
      return
    }
    setUploadingId(id)
    try {
      const { url } = await Ku.uploadFile(file)
      if (!url) throw new Error('上传返回为空')
      persist({ ...urls, [id]: url })
      toast.success('图片上传成功')
    } catch (err) {
      const msg = err && err.message ? err.message : String(err)
      toast.error(`图片上传失败：${msg}`)
    } finally {
      setUploadingId(null)
    }
  }

  const removePhoto = (id) => {
    const next = { ...urls }
    delete next[id]
    persist(next)
    toast.success('已删除图片')
  }

  const topId = order[0]

  return (
    <div className="flex flex-col items-center h-full">
      <input
        ref={fileRef}
        type="file"
        accept="image/jpeg,image/png,image/webp,image/gif"
        className="hidden"
        onChange={onFileChange}
      />
      <div
        className="relative w-full flex-1"
        style={{ minHeight: 560, maxWidth: 570, margin: '0 auto' }}
      >
        {order.map((id, idx) => {
          const slot = slots.find((s) => s.id === id)
          const offset = Math.min(idx, 4) * 4
          const isTop = idx === 0
          const url = urls[id]
          return (
            <div
              key={id}
              onClick={isTop ? handleNext : undefined}
              className="absolute mx-auto transition-all duration-300 select-none"
              style={{
                top: offset,
                width: `calc(100% - ${offset * 1.4}px)`,
                left: 0,
                right: 0,
                height: 540,
                zIndex: order.length - idx,
                transform: `rotate(${Math.min(idx, 4) * 0.5}deg)`,
                cursor: isTop ? 'pointer' : 'default',
                backgroundColor: COLORS.panel,
                border: `4px solid ${COLORS.woodDark}`,
                boxShadow: `6px 6px 0 ${COLORS.woodDeep}`,
                padding: 10,
              }}
            >
              <div
                className="w-full flex flex-col items-center justify-center relative overflow-hidden"
                style={{
                  height: 'calc(100% - 44px)',
                  backgroundColor: url ? (bgColors[id] || slot.tint) : slot.tint,
                  border: `3px ${url ? 'solid' : 'dashed'} ${COLORS.muted}`,
                }}
              >
                {url ? (
                  <img
                    src={url}
                    alt={slot.label}
                    crossOrigin="anonymous"
                    className="w-full h-full"
                    style={{ objectFit: 'contain' }}
                    onLoad={(e) => handleImgLoad(id, e)}
                    onError={() => toast.error('图片无法显示，可能是 HEIF/HEIC 等浏览器不支持的格式，请改用 JPG/PNG')}
                  />
                ) : (
                  <>
                    <ImageIcon size={60} color={COLORS.lampGlow} strokeWidth={1.5} />
                    <span
                      style={{
                        fontFamily: `'Courier New', monospace`,
                        color: COLORS.cream,
                        fontSize: 15,
                        marginTop: 10,
                        letterSpacing: 1,
                      }}
                    >
                      {slot.label}
                    </span>
                  </>
                )}

                {isTop && (
                  <div
                    className="absolute flex gap-2"
                    style={{ top: 8, right: 8 }}
                    onClick={(e) => e.stopPropagation()}
                  >
                    <button
                      onClick={() => triggerUpload(id)}
                      className="flex items-center justify-center"
                      style={{
                        width: 32,
                        height: 32,
                        backgroundColor: COLORS.lampGlow,
                        border: `2px solid ${COLORS.woodDark}`,
                        cursor: 'pointer',
                      }}
                      title="上传图片"
                    >
                      <Upload size={16} color={COLORS.woodDeep} strokeWidth={2.5} />
                    </button>
                    {url && (
                      <button
                        onClick={() => removePhoto(id)}
                        className="flex items-center justify-center"
                        style={{
                          width: 32,
                          height: 32,
                          backgroundColor: COLORS.panel,
                          border: `2px solid ${COLORS.woodDark}`,
                          cursor: 'pointer',
                        }}
                        title="删除图片"
                      >
                        <Trash2 size={16} color="#b5342b" strokeWidth={2.5} />
                      </button>
                    )}
                  </div>
                )}

                {isTop && uploadingId === id && (
                  <div
                    className="absolute inset-0 flex items-center justify-center"
                    style={{ backgroundColor: 'rgba(36,29,51,0.7)' }}
                  >
                    <span
                      style={{
                        fontFamily: `'Courier New', monospace`,
                        color: COLORS.lampGlow,
                        fontSize: 14,
                      }}
                    >
                      上传中…
                    </span>
                  </div>
                )}

                {isTop && !url && uploadingId !== id && (
                  <span
                    className="absolute"
                    style={{
                      bottom: 10,
                      fontFamily: `'Courier New', monospace`,
                      color: COLORS.lampGlow,
                      fontSize: 13,
                    }}
                  >
                    ▶ 点击空白切换 · 右上角上传
                  </span>
                )}
              </div>
              <div
                className="flex items-center justify-between px-1"
                style={{ height: 36 }}
              >
                <span
                  style={{
                    fontFamily: `'Courier New', monospace`,
                    color: COLORS.woodDark,
                    fontSize: 14,
                    fontWeight: 'bold',
                  }}
                >
                  # {String(slot.id).padStart(2, '0')}
                </span>
                <div className="flex gap-1">
                  {slots.map((s) => (
                    <div
                      key={s.id}
                      style={{
                        width: 9,
                        height: 9,
                        backgroundColor:
                          s.id === topId ? COLORS.lampGlow : COLORS.muted,
                      }}
                    />
                  ))}
                </div>
              </div>
            </div>
          )
        })}
      </div>
      <p
        style={{
          fontFamily: `'Courier New', monospace`,
          color: COLORS.cream,
          fontSize: 13,
          marginTop: 10,
          opacity: 0.85,
        }}
      >
        第 {slots.findIndex((s) => s.id === topId) + 1} / {slots.length} 张
      </p>
    </div>
  )
}

function VideoStack() {
  const slots = [
    { id: 1, label: '演示视频 01', tint: '#2c2540' },
  ]
  const [order, setOrder] = useState(slots.map((s) => s.id))
  const [urls, setUrls] = useState({})
  const [uploadingId, setUploadingId] = useState(null)
  const fileRef = useRef(null)
  const targetId = useRef(null)

  useEffect(() => {
    Ku.dataStorage.getItem(VIDEO_KEY).then((v) => {
      if (v && typeof v === 'object') setUrls(v)
    }).catch(() => {})
  }, [])

  const persist = (next) => {
    setUrls(next)
    Ku.dataStorage.setItem(VIDEO_KEY, next).catch(() => {})
  }

  const handleNext = () => {
    setOrder((prev) => {
      const next = [...prev]
      const top = next.shift()
      next.push(top)
      return next
    })
  }

  const triggerUpload = (id) => {
    targetId.current = id
    if (fileRef.current) {
      fileRef.current.value = ''
      fileRef.current.click()
    }
  }

  const onFileChange = async (e) => {
    const file = e.target.files && e.target.files[0]
    if (!file) return
    const id = targetId.current
    const MAX = 200 * 1024 * 1024
    if (file.size > MAX) {
      toast.error(`视频过大（${(file.size / 1024 / 1024).toFixed(1)}MB），上限 200MB，请压缩后再试`)
      return
    }
    setUploadingId(id)
    try {
      const res = await Ku.uploadFile(file, {
        onProgress: () => {},
      })
      if (!res || !res.url) throw new Error('上传返回为空')
      persist({ ...urls, [id]: res.url })
      toast.success('视频上传成功')
    } catch (err) {
      const msg = err && err.message ? err.message : String(err)
      toast.error(`视频上传失败：${msg}`)
    } finally {
      setUploadingId(null)
    }
  }

  const removeVideo = (id) => {
    const next = { ...urls }
    delete next[id]
    persist(next)
    toast.success('已删除视频')
  }

  const topId = order[0]

  return (
    <div className="flex flex-col items-center">
      <input
        ref={fileRef}
        type="file"
        accept="video/*"
        className="hidden"
        onChange={onFileChange}
      />
      <div
        className="relative w-full"
        style={{ height: 840, maxWidth: 1160, margin: '0 auto' }}
      >
        {order.map((id, idx) => {
          const slot = slots.find((s) => s.id === id)
          const offset = idx * 18
          const isTop = idx === 0
          const url = urls[id]
          return (
            <div
              key={id}
              onClick={isTop ? handleNext : undefined}
              className="absolute mx-auto transition-all duration-300 select-none"
              style={{
                top: offset,
                width: `calc(100% - ${offset * 1.4}px)`,
                height: 760,
                left: 0,
                right: 0,
                zIndex: order.length - idx,
                transform: idx === 0 ? 'none' : `rotate(${idx * -1.2}deg)`,
                cursor: isTop ? 'pointer' : 'default',
                backgroundColor: COLORS.night,
                border: `4px solid ${COLORS.woodDark}`,
                boxShadow: `6px 6px 0 ${COLORS.woodDeep}`,
                padding: 10,
              }}
            >
              <div
                className="w-full flex flex-col items-center justify-center relative overflow-hidden"
                style={{
                  height: 'calc(100% - 44px)',
                  backgroundColor: slot.tint,
                  border: `3px ${url ? 'solid' : 'dashed'} ${COLORS.muted}`,
                }}
              >
                {url ? (
                  <video
                    src={url}
                    controls
                    className="w-full h-full"
                    style={{ objectFit: 'contain', backgroundColor: '#000' }}
                    onClick={(e) => e.stopPropagation()}
                    onPointerDown={(e) => e.stopPropagation()}
                    onMouseDown={(e) => e.stopPropagation()}
                  />
                ) : (
                  <>
                    <div
                      className="flex items-center justify-center"
                      style={{
                        width: 80,
                        height: 80,
                        backgroundColor: COLORS.lampGlow,
                        border: `4px solid ${COLORS.cream}`,
                        boxShadow: `4px 4px 0 rgba(0,0,0,0.4)`,
                      }}
                    >
                      <Play size={38} color={COLORS.woodDeep} fill={COLORS.woodDeep} />
                    </div>
                    <span
                      style={{
                        fontFamily: `'Courier New', monospace`,
                        color: COLORS.cream,
                        fontSize: 15,
                        marginTop: 14,
                        letterSpacing: 1,
                      }}
                    >
                      {slot.label}
                    </span>
                  </>
                )}

                {isTop && (
                  <div
                    className="absolute flex gap-2"
                    style={{ top: 8, right: 8 }}
                    onClick={(e) => e.stopPropagation()}
                  >
                    <button
                      onClick={() => triggerUpload(id)}
                      className="flex items-center justify-center"
                      style={{
                        width: 32,
                        height: 32,
                        backgroundColor: COLORS.lampGlow,
                        border: `2px solid ${COLORS.woodDark}`,
                        cursor: 'pointer',
                      }}
                      title="上传视频"
                    >
                      <Upload size={16} color={COLORS.woodDeep} strokeWidth={2.5} />
                    </button>
                    {url && (
                      <button
                        onClick={() => removeVideo(id)}
                        className="flex items-center justify-center"
                        style={{
                          width: 32,
                          height: 32,
                          backgroundColor: COLORS.panel,
                          border: `2px solid ${COLORS.woodDark}`,
                          cursor: 'pointer',
                        }}
                        title="删除视频"
                      >
                        <Trash2 size={16} color="#b5342b" strokeWidth={2.5} />
                      </button>
                    )}
                  </div>
                )}

                {isTop && uploadingId === id && (
                  <div
                    className="absolute inset-0 flex items-center justify-center"
                    style={{ backgroundColor: 'rgba(36,29,51,0.7)' }}
                  >
                    <span
                      style={{
                        fontFamily: `'Courier New', monospace`,
                        color: COLORS.lampGlow,
                        fontSize: 14,
                      }}
                    >
                      上传中…
                    </span>
                  </div>
                )}

                {isTop && !url && uploadingId !== id && (
                  <span
                    className="absolute"
                    style={{
                      bottom: 10,
                      fontFamily: `'Courier New', monospace`,
                      color: COLORS.lampGlow,
                      fontSize: 13,
                    }}
                  >
                    ▶ 点击空白切换 · 右上角上传
                  </span>
                )}
              </div>
              <div
                className="flex items-center justify-between px-1"
                style={{ height: 36 }}
              >
                <span
                  style={{
                    fontFamily: `'Courier New', monospace`,
                    color: COLORS.lampSoft,
                    fontSize: 14,
                    fontWeight: 'bold',
                  }}
                >
                  ▶ {String(slot.id).padStart(2, '0')}
                </span>
                <div className="flex gap-1">
                  {slots.map((s) => (
                    <div
                      key={s.id}
                      style={{
                        width: 9,
                        height: 9,
                        backgroundColor:
                          s.id === topId ? COLORS.lampGlow : COLORS.muted,
                      }}
                    />
                  ))}
                </div>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

function PixelGramophone() {
  const P = 5
  const px = (n) => n * P
  const cell = (color) => ({
    position: 'absolute',
    width: P + 0.5,
    height: P + 0.5,
    backgroundColor: color,
  })

  const C = {
    rim: COLORS.cream,
    goldHi: COLORS.lampSoft,
    gold: COLORS.lampGlow,
    goldDk: '#c98a2e',
    throat: COLORS.woodDeep,
    metal: '#cdbfa2',
    metalDk: '#8f8163',
    wood: COLORS.wood,
    woodDk: COLORS.woodDark,
    woodDeep: COLORS.woodDeep,
    record: COLORS.night,
    recRed: '#b5342b',
  }

  const grid = {}
  const add = (x, y, c) => {
    grid[`${x},${y}`] = { x, y, c }
  }

  for (let x = 13; x <= 27; x++) {
    for (let y = 21; y <= 31; y++) {
      let c = C.wood
      if (x === 13 || x === 27 || y === 21 || y === 31) c = C.woodDk
      if (y >= 29) c = C.woodDeep
      add(x, y, c)
    }
  }
  for (let x = 15; x <= 25; x++) add(x, 24, C.woodDk)
  for (let x = 15; x <= 25; x++) add(x, 27, C.woodDk)
  ;[13, 26].forEach((bx) => {
    add(bx, 32, C.woodDeep)
    add(bx + 1, 32, C.woodDeep)
  })

  const pcx = 20, pcy = 19.5, prx = 7, pry = 3
  for (let x = 12; x <= 28; x++) {
    for (let y = 16; y <= 23; y++) {
      const d = Math.pow((x - pcx) / prx, 2) + Math.pow((y - pcy) / pry, 2)
      if (d <= 1) {
        const dr = Math.pow((x - pcx) / (prx - 1.6), 2) + Math.pow((y - pcy) / (pry - 0.9), 2)
        if (dr <= 1) add(x, y, C.record)
        else add(x, y, C.gold)
      }
    }
  }
  add(pcx, pcy, C.recRed)
  add(pcx - 1, pcy, C.recRed)

  const tube = [
    [11, 13], [11, 14], [11, 15], [12, 15], [12, 16], [13, 16],
    [14, 17], [15, 17], [16, 18],
  ]
  tube.forEach(([x, y]) => {
    add(x, y, C.metal)
    add(x + 1, y, C.metalDk)
  })

  const arm = [[23, 15], [22, 15], [21, 16], [20, 16], [19, 17], [18, 18]]
  arm.forEach(([x, y]) => add(x, y, C.metalDk))
  add(24, 14, C.metal)
  add(24, 15, C.metal)
  add(18, 18, C.recRed)

  const hx = 6.5, hy = 7, rx = 7.2, ry = 7
  for (let x = -1; x <= 14; x++) {
    for (let y = -1; y <= 15; y++) {
      const d = Math.sqrt(Math.pow((x - hx) / rx, 2) + Math.pow((y - hy) / ry, 2))
      if (d <= 1.02) {
        let c
        if (d > 0.9) c = C.rim
        else if (d > 0.68) c = C.goldHi
        else if (d > 0.44) c = C.gold
        else if (d > 0.22) c = C.goldDk
        else c = C.throat
        add(x, y, c)
      }
    }
  }
  ;[[9, 11], [10, 11], [10, 12], [11, 12], [11, 13]].forEach(([x, y]) =>
    add(x, y, C.goldDk)
  )

  ;[[28, 25], [29, 25], [29, 24], [29, 26]].forEach(([x, y]) => add(x, y, C.metalDk))
  add(30, 25, C.metal)

  const pixels = Object.values(grid)
  const minX = Math.min(...pixels.map((p) => p.x))
  const minY = Math.min(...pixels.map((p) => p.y))
  const maxX = Math.max(...pixels.map((p) => p.x)) + 1
  const maxY = Math.max(...pixels.map((p) => p.y)) + 1

  return (
    <div
      style={{
        position: 'relative',
        width: px(maxX - minX),
        height: px(maxY - minY),
        imageRendering: 'pixelated',
        filter: `drop-shadow(3px 3px 0 ${COLORS.woodDeep})`,
      }}
    >
      {pixels.map((p, i) => (
        <div
          key={i}
          style={{ ...cell(p.c), left: px(p.x - minX), top: px(p.y - minY) }}
        />
      ))}
    </div>
  )
}

export default function App() {
  const isMobile = typeof window !== 'undefined' && window.isMobile

  return (
    <div
      style={{
        backgroundColor: COLORS.skyTop,
        backgroundImage: `radial-gradient(${COLORS.muted}18 1px, transparent 1px)`,
        backgroundSize: '22px 22px',
        padding: isMobile ? 16 : 32,
        minHeight: '100%',
      }}
    >
      <Toaster position="top-center" richColors />
      <div style={{ maxWidth: 1440, margin: '0 auto' }}>
        <div
          className="flex items-center justify-between mb-8"
          style={{
            minHeight: isMobile ? 120 : 200,
            backgroundColor: COLORS.night,
            border: `3px solid ${COLORS.woodDark}`,
            boxShadow: `6px 6px 0 ${COLORS.woodDeep}`,
            padding: isMobile ? 16 : 32,
          }}
        >
          <div className="flex items-start gap-4">
            <div className="flex flex-col gap-3">
              <div className="flex items-center gap-2">
                <Sparkles size={16} color={COLORS.amber} strokeWidth={2.5} />
                <span
                  style={{
                    fontFamily: `'Courier New', monospace`,
                    color: COLORS.amber,
                    fontSize: 14,
                    letterSpacing: 2,
                  }}
                >
                  PART 03
                </span>
              </div>
              <h2
                style={{
                  fontFamily: `'Courier New', monospace`,
                  color: COLORS.lampGlow,
                  fontSize: isMobile ? 34 : 76,
                  lineHeight: 1,
                  letterSpacing: 4,
                  fontWeight: 500,
                  textShadow: `4px 4px 0 ${COLORS.woodDeep}`,
                }}
              >
                效果展示
              </h2>
              <p
                style={{
                  fontFamily: `'Courier New', monospace`,
                  color: COLORS.cream,
                  fontSize: isMobile ? 13 : 16,
                  letterSpacing: 1,
                  lineHeight: 1.6,
                }}
              >
                同频在场、定制桌宠、记录留声
              </p>
            </div>
          </div>
          {!isMobile && (
            <div className="flex items-center pr-4">
              <PixelGramophone />
            </div>
          )}
        </div>

        <div className="flex flex-col gap-6">
          <div
            className={isMobile ? 'flex flex-col gap-6' : 'grid gap-6'}
            style={isMobile ? {} : { gridTemplateColumns: '1fr 1fr' }}
          >
            <div
              style={{
                backgroundColor: COLORS.wood,
                border: `3px solid ${COLORS.woodDark}`,
                padding: 16,
              }}
            >
              <ProductFeatures />
            </div>

            <div
              className="flex flex-col"
              style={{
                backgroundColor: COLORS.skyMid,
                border: `3px solid ${COLORS.woodDark}`,
                padding: 16,
              }}
            >
              <PixelTitle icon={ImageIcon} text="功能展示" />
              <PhotoStack />
            </div>
          </div>

          <div
            style={{
              backgroundColor: COLORS.skyMid,
              border: `3px solid ${COLORS.woodDark}`,
              padding: 16,
            }}
          >
            <PixelTitle icon={Video} text="Demo 视频" />
            <VideoStack />
          </div>
        </div>
      </div>
    </div>
  )
}