import React, { useState, useEffect, useRef, useCallback } from 'react'
import { Upload, Play, Trash2, Loader2 } from 'lucide-react'
import { toast, Toaster } from 'sonner'

const STORAGE_PREFIX = 'pixel_tv_video_'
const SHARED_KEY = 'pixel_tv_shared_video'

function Starfield() {
  const stars = React.useMemo(() => {
    const arr = []
    for (let i = 0; i < 70; i++) {
      arr.push({
        left: Math.random() * 100,
        top: Math.random() * 65,
        size: Math.random() > 0.8 ? 4 : 2,
        opacity: 0.4 + Math.random() * 0.6,
        delay: Math.random() * 3
      })
    }
    return arr
  }, [])

  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none">
      {stars.map((s, i) => (
        <div
          key={i}
          className="absolute animate-pulse"
          style={{
            left: `${s.left}%`,
            top: `${s.top}%`,
            width: `${s.size}px`,
            height: `${s.size}px`,
            backgroundColor: '#f5ecc8',
            opacity: s.opacity,
            animationDelay: `${s.delay}s`,
            imageRendering: 'pixelated'
          }}
        />
      ))}
    </div>
  )
}

function TVScreen({ videoUrl, uploading, onPick, onClear }) {
  return (
    <div
      className="relative w-full h-full overflow-hidden flex items-center justify-center"
      style={{
        backgroundColor: videoUrl ? '#000' : '#1a2145',
        boxShadow: 'inset 0 0 30px rgba(0,0,0,0.7)',
        imageRendering: 'pixelated'
      }}
    >
      {/* 扫描线 */}
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          backgroundImage: 'repeating-linear-gradient(to bottom, rgba(255,255,255,0.05) 0px, rgba(255,255,255,0.05) 2px, transparent 2px, transparent 6px)'
        }}
      />

      {videoUrl ? (
        <>
          <video
            src={videoUrl}
            controls
            className="w-full h-full object-contain relative z-10"
            style={{ backgroundColor: '#000' }}
          />
          <button
            onClick={onClear}
            className="absolute z-20 top-2 right-2 flex items-center gap-1 px-2 py-1 text-white"
            style={{ backgroundColor: 'rgba(0,0,0,0.6)', fontSize: '14px' }}
          >
            <Trash2 size={16} />
            <span>重传</span>
          </button>
        </>
      ) : (
        <button
          onClick={onPick}
          disabled={uploading}
          className="relative z-10 flex flex-col items-center justify-center gap-3 w-full h-full disabled:opacity-70"
          style={{ color: '#f5ecc8' }}
        >
          {uploading ? (
            <>
              <Loader2 size={56} className="animate-spin" />
              <span style={{ fontSize: '16px' }}>上传中…</span>
            </>
          ) : (
            <>
              <Upload size={64} strokeWidth={2.5} />
              <span className="font-bold" style={{ fontSize: '16px', letterSpacing: '2px' }}>
                点击上传视频
              </span>
              <span style={{ fontSize: '14px', color: '#9aa3c7', letterSpacing: '2px' }}>
                MP4 / WebM 等格式
              </span>
            </>
          )}
        </button>
      )}
    </div>
  )
}

function PixelTV({ children }) {
  return (
    <div
      className="relative"
      style={{
        width: 'min(96vw, 150vh)',
        maxWidth: '1440px'
      }}
    >
      {/* 天线 */}
      <div className="absolute left-1/2 -translate-x-1/2" style={{ bottom: '100%', width: '18%', height: '10vh', minHeight: '60px' }}>
        <div
          className="absolute"
          style={{ left: '42%', bottom: 0, width: '10px', height: '110%', backgroundColor: '#8a5a3c', transform: 'rotate(22deg)', transformOrigin: 'bottom' }}
        />
        <div
          className="absolute"
          style={{ right: '42%', bottom: 0, width: '10px', height: '110%', backgroundColor: '#8a5a3c', transform: 'rotate(-22deg)', transformOrigin: 'bottom' }}
        />
        <div
          className="absolute left-1/2 -translate-x-1/2"
          style={{ bottom: 0, width: '24px', height: '24px', backgroundColor: '#a06a44' }}
        />
      </div>

      {/* 电视机身 */}
      <div
        className="relative w-full flex items-stretch p-[3%]"
        style={{
          backgroundColor: '#7a4f34',
          borderRadius: '18px',
          boxShadow: '0 0 0 6px #5c3b26, 0 20px 40px rgba(0,0,0,0.5)',
          imageRendering: 'pixelated'
        }}
      >
        {/* 屏幕外框（16:9） */}
        <div
          className="p-[1.4%]"
          style={{ width: '76%', backgroundColor: '#3a2617', borderRadius: '10px' }}
        >
          <div className="w-full overflow-hidden" style={{ aspectRatio: '16 / 9', borderRadius: '6px' }}>
            {children}
          </div>
        </div>

        {/* 控制区 */}
        <div className="flex-1 flex flex-col items-center justify-start gap-[8%] pl-[3%] pt-[4%]">
          <div style={{ width: '52%', aspectRatio: '1', backgroundColor: '#e2c27a', borderRadius: '50%', boxShadow: 'inset -3px -3px 0 rgba(0,0,0,0.2)' }} />
          <div style={{ width: '52%', aspectRatio: '1', backgroundColor: '#e2c27a', borderRadius: '50%', boxShadow: 'inset -3px -3px 0 rgba(0,0,0,0.2)' }} />
          <div className="flex gap-[10%] mt-[4%]" style={{ width: '52%' }}>
            <div style={{ flex: 1, aspectRatio: '1 / 2.2', backgroundColor: '#3a2617' }} />
            <div style={{ flex: 1, aspectRatio: '1 / 2.2', backgroundColor: '#3a2617' }} />
          </div>
        </div>
      </div>

      {/* 底座 */}
      <div
        className="mx-auto"
        style={{ width: '92%', height: '3vh', minHeight: '18px', backgroundColor: '#3d2f52', borderRadius: '0 0 12px 12px' }}
      />
    </div>
  )
}

export default function App() {
  const [videoUrl, setVideoUrl] = useState('')
  const [uploading, setUploading] = useState(false)
  const [userEmail, setUserEmail] = useState('')
  const fileInputRef = useRef(null)

  useEffect(() => {
    let mounted = true
    ;(async () => {
      try {
        const info = await Ku.getUserInfo()
        const email = (info?.email || 'anonymous').toLowerCase()
        if (mounted) setUserEmail(email)
      } catch (e) {
        if (mounted) setUserEmail('anonymous')
      }
      try {
        const saved = await Ku.dataStorage.getItem(SHARED_KEY)
        if (mounted && saved) setVideoUrl(saved)
      } catch (e) {}
    })()
    return () => { mounted = false }
  }, [])

  const handlePick = useCallback(() => {
    if (fileInputRef.current) fileInputRef.current.click()
  }, [])

  const handleFileChange = useCallback(async (e) => {
    const file = e.target.files && e.target.files[0]
    e.target.value = ''
    if (!file) return
    if (!file.type.startsWith('video/')) {
      toast.error('请选择视频文件')
      return
    }
    if (file.size > 200 * 1024 * 1024) {
      toast.error('视频不能超过 200MB')
      return
    }
    setUploading(true)
    try {
      const { url } = await Ku.uploadFile(file)
      setVideoUrl(url)
      await Ku.dataStorage.setItem(SHARED_KEY, url)
      toast.success('上传成功')
    } catch (err) {
      toast.error('上传失败，请重试')
    } finally {
      setUploading(false)
    }
  }, [userEmail])

  const handleClear = useCallback(async () => {
    setVideoUrl('')
    try {
      await Ku.dataStorage.removeItem(SHARED_KEY)
    } catch (e) {}
  }, [userEmail])

  return (
    <div
      className="relative w-full flex items-center justify-center overflow-hidden"
      style={{
        minHeight: '100vh',
        background: 'linear-gradient(180deg, #0f1330 0%, #1e2148 45%, #3a2e50 75%, #6b5340 100%)'
      }}
    >
      <Starfield />

      <div className="relative z-10 flex items-center justify-center w-full px-2 py-12">
        <PixelTV>
          <TVScreen
            videoUrl={videoUrl}
            uploading={uploading}
            onPick={handlePick}
            onClear={handleClear}
          />
        </PixelTV>
      </div>

      <input
        ref={fileInputRef}
        type="file"
        accept="video/*"
        className="hidden"
        onChange={handleFileChange}
      />

      <Toaster position="top-center" richColors />
    </div>
  )
}