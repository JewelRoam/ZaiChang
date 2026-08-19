import React, { useState, useEffect, useRef } from 'react';
import { Home, Coffee, Users, Radio, Sparkles, Cpu, MonitorSmartphone, Mic, Cloud, Lamp, ImagePlus, ChevronRight, ChevronLeft, Image as ImageIcon } from 'lucide-react';

const STORAGE_KEY = 'zaichang_solution_content_v1';

const COLORS = {
  skyTop: '#3a2f4a',
  skyMid: '#7a5c46',
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
  amber: '#f5a623',
};

const pixelBorder = {
  border: `3px solid ${COLORS.woodDeep}`,
  boxShadow: `4px 4px 0 ${COLORS.woodDeep}`,
  imageRendering: 'pixelated',
};

function Editable({ value, onChange, style, className, as = 'span' }) {
  const Tag = as;
  return (
    <Tag
      className={className}
      contentEditable
      suppressContentEditableWarning
      spellCheck={false}
      onBlur={(e) => onChange(e.currentTarget.textContent)}
      style={{ outline: 'none', cursor: 'text', ...style }}
    >
      {value}
    </Tag>
  );
}

function PixelLampDesk() {
  return (
    <svg width="200" height="150" viewBox="0 0 40 30" shapeRendering="crispEdges" style={{ imageRendering: 'pixelated' }}>
      <polygon points="24,9 30,9 37,26 17,26" fill={COLORS.lampSoft} opacity="0.28" />
      <polygon points="25,10 29,10 33,24 21,24" fill="#ffe0a0" opacity="0.34" />
      <rect x="23" y="6" width="8" height="1" fill="#d9773c" />
      <rect x="22" y="7" width="10" height="1" fill="#e8894a" />
      <rect x="22" y="8" width="10" height="1" fill="#e8894a" />
      <rect x="21" y="9" width="12" height="1" fill="#c86a34" />
      <rect x="26" y="5" width="2" height="1" fill="#8a6136" />
      <rect x="25" y="10" width="4" height="1" fill="#fff3d0" />
      <rect x="26" y="10" width="2" height="2" fill={COLORS.lampGlow} />
      <rect x="20" y="10" width="2" height="2" fill="#8a6136" />
      <rect x="19" y="12" width="2" height="2" fill="#8a6136" />
      <rect x="18" y="14" width="2" height="3" fill={COLORS.wood} />
      <rect x="18" y="17" width="2" height="4" fill="#8a6136" />
      <rect x="15" y="21" width="8" height="1" fill={COLORS.woodDark} />
      <rect x="14" y="22" width="10" height="2" fill={COLORS.wood} />
      <rect x="14" y="22" width="10" height="1" fill="#956338" />
      <rect x="1" y="24" width="38" height="5" fill={COLORS.woodDark} />
      <rect x="1" y="24" width="38" height="1" fill="#8a5c30" />
      <rect x="4" y="26" width="10" height="1" fill={COLORS.woodDeep} />
      <rect x="20" y="27" width="14" height="1" fill={COLORS.woodDeep} />
      <rect x="4" y="20" width="5" height="4" fill="#f4e3c6" />
      <rect x="4" y="20" width="5" height="1" fill="#fff6e0" />
      <rect x="9" y="21" width="1" height="2" fill="#d8c39c" />
      <rect x="5" y="18" width="1" height="1" fill="#e7d3ad" opacity="0.7" />
      <rect x="7" y="17" width="1" height="1" fill="#e7d3ad" opacity="0.7" />
      <rect x="11" y="22" width="6" height="2" fill="#6b7a3d" />
      <rect x="11" y="21" width="6" height="1" fill="#8a9a4d" />
      <rect x="12" y="20" width="5" height="1" fill="#b5563f" />
      <rect x="12" y="19" width="5" height="1" fill="#c96a4f" />
      <rect x="34" y="21" width="4" height="3" fill="#a5623a" />
      <rect x="34" y="21" width="4" height="1" fill="#bd7647" />
      <rect x="35" y="18" width="1" height="3" fill="#5d7a34" />
      <rect x="37" y="18" width="1" height="3" fill="#5d7a34" />
      <rect x="36" y="17" width="1" height="4" fill="#7a9a44" />
    </svg>
  );
}

function PixelStoveScene() {
  // 参考封面阁楼场景：右侧火炉 + 木架 + 盆栽，像素风
  return (
    <svg width="100%" height="150" viewBox="0 0 120 40" preserveAspectRatio="xMidYMax meet" shapeRendering="crispEdges" style={{ imageRendering: 'pixelated', display: 'block' }}>
      {/* 地板木纹 */}
      <rect x="0" y="34" width="120" height="6" fill="#4a3120" />
      <rect x="0" y="34" width="120" height="1" fill="#5e3d28" />
      <rect x="15" y="37" width="30" height="1" fill="#3d2818" />
      <rect x="60" y="36" width="40" height="1" fill="#3d2818" />
      {/* 左侧木架 */}
      <rect x="4" y="14" width="30" height="20" fill="#6e4526" />
      <rect x="4" y="14" width="30" height="2" fill="#8a5c30" />
      <rect x="4" y="23" width="30" height="2" fill="#5e3d28" />
      <rect x="6" y="16" width="6" height="6" fill="#b5563f" />
      <rect x="13" y="16" width="6" height="6" fill="#4f6a8a" />
      <rect x="20" y="17" width="5" height="5" fill="#6b7a3d" />
      <rect x="26" y="16" width="6" height="6" fill="#c9863a" />
      <rect x="7" y="25" width="7" height="7" fill="#7a9a44" />
      <rect x="16" y="26" width="6" height="6" fill="#a5623a" />
      <rect x="24" y="25" width="7" height="7" fill="#9a4f6a" />
      {/* 盆栽 */}
      <rect x="8" y="8" width="6" height="6" fill="#5d7a34" />
      <rect x="9" y="6" width="4" height="3" fill="#7a9a44" />
      <rect x="8" y="14" width="6" height="2" fill="#a5623a" />
      {/* 火炉 */}
      <rect x="92" y="10" width="22" height="24" fill="#2b2b30" />
      <rect x="92" y="10" width="22" height="2" fill="#40404a" />
      <rect x="102" y="0" width="4" height="10" fill="#333338" />
      {/* 炉门火光 */}
      <rect x="96" y="18" width="14" height="12" fill="#3a1e0e" />
      <rect x="98" y="22" width="10" height="8" fill="#e8621f" />
      <rect x="100" y="24" width="6" height="6" fill="#f5a623" />
      <rect x="101" y="26" width="4" height="4" fill="#f7d089" />
      <rect x="99" y="20" width="2" height="2" fill="#f5a623" />
      <rect x="105" y="21" width="2" height="2" fill="#e8621f" />
      {/* 炉旁柴火 */}
      <rect x="115" y="26" width="5" height="8" fill="#6e4526" />
      <rect x="115" y="26" width="5" height="2" fill="#8a5c30" />
    </svg>
  );
}

function PixelDesk({ size = 62 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" shapeRendering="crispEdges" style={{ imageRendering: 'pixelated' }}>
      <rect x="2" y="9" width="16" height="2" fill="#8a5c30" />
      <rect x="2" y="9" width="16" height="1" fill="#a5713d" />
      <rect x="3" y="11" width="2" height="6" fill="#6e4526" />
      <rect x="15" y="11" width="2" height="6" fill="#6e4526" />
      <rect x="11" y="11" width="6" height="5" fill="#7a4f2c" />
      <rect x="11" y="13" width="6" height="1" fill="#5e3d28" />
      <rect x="13" y="12" width="1" height="1" fill="#f5b850" />
      <rect x="4" y="3" width="4" height="2" fill="#f5b850" />
      <rect x="4" y="2" width="4" height="1" fill="#f7d089" />
      <rect x="5" y="5" width="1" height="4" fill="#8a6136" />
      <rect x="3" y="8" width="4" height="1" fill="#8a6136" />
      <rect x="9" y="6" width="4" height="3" fill="#b5563f" />
      <rect x="9" y="6" width="4" height="1" fill="#c96a4f" />
    </svg>
  );
}

function PixelGramophone({ size = 62 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" shapeRendering="crispEdges" style={{ imageRendering: 'pixelated' }}>
      <rect x="4" y="12" width="10" height="5" fill="#7a4f2c" />
      <rect x="4" y="12" width="10" height="1" fill="#a5713d" />
      <rect x="4" y="16" width="10" height="1" fill="#5e3d28" />
      <rect x="8" y="11" width="3" height="1" fill="#3d2818" />
      <rect x="12" y="5" width="1" height="7" fill="#5e3d28" />
      <polygon points="11,2 18,0 18,8 11,6" fill="#f5b850" />
      <polygon points="12,3 16,2 16,6 12,5" fill="#f7d089" />
      <rect x="18" y="0" width="1" height="8" fill="#d9773c" />
    </svg>
  );
}

function PixelCloud({ size = 62 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" shapeRendering="crispEdges" style={{ imageRendering: 'pixelated' }}>
      {/* 顶部小云团 */}
      <rect x="7" y="4" width="3" height="1" fill="#f6fafd" />
      <rect x="6" y="5" width="5" height="1" fill="#f6fafd" />
      <rect x="11" y="5" width="4" height="1" fill="#f6fafd" />
      {/* 主体隆起 */}
      <rect x="5" y="6" width="6" height="2" fill="#eef4fa" />
      <rect x="10" y="6" width="6" height="2" fill="#eef4fa" />
      <rect x="4" y="8" width="13" height="2" fill="#e4edf5" />
      <rect x="3" y="10" width="15" height="2" fill="#dfe8f0" />
      {/* 底部阴影层 */}
      <rect x="3" y="12" width="15" height="2" fill="#c9d6e2" />
      <rect x="4" y="14" width="13" height="1" fill="#b3c4d2" />
      {/* 高光 */}
      <rect x="6" y="6" width="4" height="1" fill="#ffffff" />
      <rect x="5" y="8" width="6" height="1" fill="#f6fafd" />
      {/* 左右圆角收边 */}
      <rect x="2" y="11" width="1" height="1" fill="#dfe8f0" />
      <rect x="18" y="9" width="1" height="1" fill="#eef4fa" />
    </svg>
  );
}

function PixelDisk({ size = 62 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" shapeRendering="crispEdges" style={{ imageRendering: 'pixelated' }}>
      {/* 数据库/存储柱体 */}
      <rect x="4" y="4" width="12" height="12" fill="#6e4526" />
      <rect x="4" y="4" width="12" height="12" fill="none" />
      {/* 顶部椭圆盘 */}
      <rect x="5" y="3" width="10" height="2" fill="#a5713d" />
      <rect x="6" y="2" width="8" height="1" fill="#c9863a" />
      <rect x="7" y="4" width="6" height="1" fill="#5e3d28" />
      {/* 分层缝 */}
      <rect x="4" y="8" width="12" height="1" fill="#5e3d28" />
      <rect x="4" y="12" width="12" height="1" fill="#5e3d28" />
      {/* 底部盘 */}
      <rect x="5" y="15" width="10" height="2" fill="#5e3d28" />
      {/* 存储指示灯 */}
      <rect x="12" y="6" width="2" height="1" fill="#f5b850" />
      <rect x="12" y="10" width="2" height="1" fill="#7a9a44" />
      <rect x="12" y="14" width="2" height="1" fill="#f5b850" />
      {/* 高光 */}
      <rect x="5" y="5" width="1" height="10" fill="#8a5c30" />
    </svg>
  );
}

function PixelLetter({ size = 62 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" shapeRendering="crispEdges" style={{ imageRendering: 'pixelated' }}>
      <rect x="3" y="5" width="14" height="10" fill="#fdf3dd" />
      <rect x="3" y="5" width="14" height="1" fill="#8a5c30" />
      <rect x="3" y="14" width="14" height="1" fill="#8a5c30" />
      <rect x="3" y="5" width="1" height="10" fill="#8a5c30" />
      <rect x="16" y="5" width="1" height="10" fill="#8a5c30" />
      <polygon points="4,6 10,11 16,6" fill="#f5b850" />
      <polygon points="5,6 10,10 15,6" fill="#f7d089" />
    </svg>
  );
}

function ColumnHeader({ icon: Icon, title, onTitle }) {
  return (
    <div className="flex items-center gap-2 mb-1">
      <div
        className="flex items-center justify-center"
        style={{ width: 38, height: 38, background: COLORS.lampGlow, border: `3px solid ${COLORS.woodDeep}` }}
      >
        <Icon size={20} color={COLORS.woodDeep} strokeWidth={2.5} />
      </div>
      <Editable value={title} onChange={onTitle} className="leading-none" style={{ color: COLORS.cream, fontSize: '26px', fontWeight: 800, letterSpacing: '3px' }} />
    </div>
  );
}

function PhotoAlbum({ photos, current, caption, onCaptionChange, onNext, onAdd, onDelete, onMove, uploading }) {
  const hasPhotos = photos.length > 0;
  return (
    <div className="flex flex-col gap-3 flex-1">
      {/* 相片顶框：可编辑标题 */}
      <div
        className="flex items-center gap-2 px-3 py-2"
        style={{ background: COLORS.woodDark, border: `3px solid ${COLORS.woodDeep}`, boxShadow: `4px 4px 0 ${COLORS.woodDeep}` }}
      >
        <ImageIcon size={16} color={COLORS.lampSoft} strokeWidth={2.5} />
        <Editable
          value={caption}
          onChange={onCaptionChange}
          className="flex-1"
          style={{ color: COLORS.lampSoft, fontSize: '14px', fontWeight: 700, letterSpacing: '1px' }}
        />
      </div>
      {/* 1:1 相片展示区，点击空白切换下一张 */}
      <div
        onClick={hasPhotos ? onNext : undefined}
        className="relative w-full overflow-hidden select-none"
        style={{
          background: COLORS.panel,
          borderLeft: `3px solid ${COLORS.woodDeep}`,
          borderRight: `3px solid ${COLORS.woodDeep}`,
          borderBottom: `3px solid ${COLORS.woodDeep}`,
          boxShadow: `4px 4px 0 ${COLORS.woodDeep}`,
          imageRendering: 'pixelated',
          aspectRatio: '1 / 1',
          cursor: hasPhotos ? 'pointer' : 'default',
        }}
      >
        {hasPhotos ? (
          <>
            <img
              src={photos[current]}
              alt={`photo-${current}`}
              className="w-full h-full"
              style={{ objectFit: 'cover', imageRendering: 'auto', display: 'block' }}
            />
            {/* 右下角下一张提示 */}
            <div
              className="absolute flex items-center gap-1 px-2 py-1"
              style={{ right: 8, bottom: 8, background: COLORS.woodDeep, color: COLORS.lampSoft, fontSize: '14px' }}
            >
              <span>点击切换</span>
              <ChevronRight size={16} color={COLORS.lampSoft} strokeWidth={2.5} />
            </div>
            {/* 左上角序号 */}
            <div
              className="absolute px-2 py-1"
              style={{ left: 8, top: 8, background: COLORS.woodDeep, color: COLORS.cream, fontSize: '14px', letterSpacing: '1px' }}
            >
              <span>{`${current + 1} / ${photos.length}`}</span>
            </div>
          </>
        ) : (
          <div className="w-full h-full flex flex-col items-center justify-center gap-2" style={{ color: COLORS.muted }}>
            <ImageIcon size={48} color={COLORS.muted} strokeWidth={1.5} />
            <span style={{ fontSize: '14px' }}>还没有相片，点击下方按钮上传</span>
          </div>
        )}
      </div>

      {/* 底部工具行 */}
      <div className="flex items-center gap-2">
        <label
          className="flex items-center gap-2 px-3 py-2"
          style={{ background: COLORS.lampGlow, color: COLORS.woodDeep, fontSize: '14px', border: `3px solid ${COLORS.woodDeep}`, boxShadow: `3px 3px 0 ${COLORS.woodDeep}`, cursor: uploading ? 'wait' : 'pointer', fontWeight: 700 }}
        >
          <ImagePlus size={18} color={COLORS.woodDeep} strokeWidth={2.5} />
          <span>{uploading ? '上传中…' : '添加相片'}</span>
          <input type="file" accept="image/*" multiple style={{ display: 'none' }} disabled={uploading} onChange={onAdd} />
        </label>
        {photos.length > 1 && (
          <div className="flex items-center gap-2">
            <button
              onClick={() => onMove(-1)}
              className="flex items-center gap-1 px-2 py-2"
              style={{ background: COLORS.woodDark, color: COLORS.cream, fontSize: '14px', border: `3px solid ${COLORS.woodDeep}`, boxShadow: `3px 3px 0 ${COLORS.woodDeep}`, cursor: 'pointer', fontWeight: 700 }}
            >
              <ChevronLeft size={16} color={COLORS.cream} strokeWidth={2.5} />
              <span>前移</span>
            </button>
            <button
              onClick={() => onMove(1)}
              className="flex items-center gap-1 px-2 py-2"
              style={{ background: COLORS.woodDark, color: COLORS.cream, fontSize: '14px', border: `3px solid ${COLORS.woodDeep}`, boxShadow: `3px 3px 0 ${COLORS.woodDeep}`, cursor: 'pointer', fontWeight: 700 }}
            >
              <span>后移</span>
              <ChevronRight size={16} color={COLORS.cream} strokeWidth={2.5} />
            </button>
          </div>
        )}
        {photos.length > 0 && (
          <span style={{ color: COLORS.cream, fontSize: '14px' }}>{`共 ${photos.length} 张 · 点击相片切换`}</span>
        )}
      </div>
    </div>
  );
}

function TechStep({ icon: Icon, index, label, onChange, onIndexChange }) {
  return (
    <div className="flex items-center gap-3">
      <Editable
        value={index}
        onChange={onIndexChange}
        className="flex items-center justify-center flex-shrink-0"
        style={{ width: 40, height: 40, background: COLORS.lampGlow, border: `3px solid ${COLORS.woodDeep}`, color: COLORS.woodDeep, fontSize: '18px', fontWeight: 800 }}
      />
      <div
        className="flex items-center justify-center flex-shrink-0"
        style={{ width: 84, height: 84, background: COLORS.lampSoft, border: `3px solid ${COLORS.woodDeep}`, boxShadow: `4px 4px 0 ${COLORS.woodDeep}` }}
      >
        <Icon size={64} />
      </div>
      <div className="px-4 py-4 flex items-center flex-1" style={{ background: COLORS.panel, ...pixelBorder, minHeight: 72, maxWidth: 420 }}>
        <Editable value={label} onChange={onChange} style={{ color: COLORS.panelInk, fontSize: '17px', lineHeight: 1.55, fontWeight: 600 }} />
      </div>
    </div>
  );
}

export default function ZaichangPixelSolution() {
  const [heading, setHeading] = useState('实现方案');
  const [intro, setIntro] = useState('《在场》是一款常驻 Mac 桌面的 AI 陪伴像素小屋，把陪伴变成安静、温暖且不打扰的存在。');
  const [leftTitle, setLeftTitle] = useState('产品原型');
  const [rightTitle, setRightTitle] = useState('技术实现');
  const [footer, setFooter] = useState('端云协同 · 让「在场」在桌面与移动端同时被感知');

  const [photos, setPhotos] = useState([]);
  const [captions, setCaptions] = useState([]);
  const [current, setCurrent] = useState(0);
  const [uploading, setUploading] = useState(false);

  const [tech, setTech] = useState([
    { icon: PixelDesk, order: '1', label: 'SwiftUI + SpriteKit 构建 Mac 窗口与像素场景' },
    { icon: PixelGramophone, order: '2', label: 'AVFoundation 完成录音与播放' },
    { icon: PixelCloud, order: '3', label: '云端数据库 + 实时通信同步同桌状态' },
    { icon: PixelLetter, order: '4', label: '小程序接收邀请 / 录制留声 / 查看好友状态' },
    { icon: PixelDisk, order: '5', label: '本地持久化 Application Support' },
  ]);

  const loadedRef = useRef(false);

  useEffect(() => {
    let alive = true;
    Ku.dataStorage.getItem(STORAGE_KEY).then((saved) => {
      if (!alive || !saved) {
        loadedRef.current = true;
        return;
      }
      if (saved.heading != null) setHeading(saved.heading);
      if (saved.intro != null) setIntro(saved.intro);
      if (saved.leftTitle != null) setLeftTitle(saved.leftTitle);
      if (saved.rightTitle != null) setRightTitle(saved.rightTitle);
      if (saved.footer != null) setFooter(saved.footer);
      if (Array.isArray(saved.photos)) setPhotos(saved.photos);
      if (Array.isArray(saved.captions)) setCaptions(saved.captions);
      if (Array.isArray(saved.tech)) {
        setTech((prev) => prev.map((t, i) => (saved.tech[i] ? { ...t, ...saved.tech[i], icon: t.icon } : t)));
      }
      loadedRef.current = true;
    }).catch(() => {
      loadedRef.current = true;
    });
    return () => {
      alive = false;
    };
  }, []);

  useEffect(() => {
    if (!loadedRef.current) return;
    const payload = {
      heading,
      intro,
      leftTitle,
      rightTitle,
      footer,
      photos,
      captions,
      tech: tech.map(({ order, label }) => ({ order, label })),
    };
    Ku.dataStorage.setItem(STORAGE_KEY, payload).catch(() => {});
  }, [heading, intro, leftTitle, rightTitle, footer, photos, captions, tech]);

  const handleNext = () => {
    setCurrent((c) => (photos.length ? (c + 1) % photos.length : 0));
  };

  const handleDeletePhoto = () => {
    if (!photos.length) return;
    const idx = Math.min(current, photos.length - 1);
    const nextPhotos = photos.filter((_, i) => i !== idx);
    const nextCaptions = captions.filter((_, i) => i !== idx);
    setPhotos(nextPhotos);
    setCaptions(nextCaptions);
    setCurrent((c) => Math.max(0, Math.min(c, nextPhotos.length - 1)));
    persist({ photos: nextPhotos, captions: nextCaptions });
  };

  const handleMovePhoto = (dir) => {
    if (photos.length < 2) return;
    const idx = Math.min(current, photos.length - 1);
    const target = idx + dir;
    if (target < 0 || target >= photos.length) return;
    const nextPhotos = [...photos];
    const nextCaptions = [...captions];
    [nextPhotos[idx], nextPhotos[target]] = [nextPhotos[target], nextPhotos[idx]];
    [nextCaptions[idx], nextCaptions[target]] = [nextCaptions[target], nextCaptions[idx]];
    setPhotos(nextPhotos);
    setCaptions(nextCaptions);
    setCurrent(target);
    persist({ photos: nextPhotos, captions: nextCaptions });
  };

  const persist = (patch) => {
    const payload = {
      heading,
      intro,
      leftTitle,
      rightTitle,
      footer,
      photos,
      captions,
      tech: tech.map(({ order, label }) => ({ order, label })),
      ...patch,
    };
    return Ku.dataStorage.setItem(STORAGE_KEY, payload).catch(() => {});
  };

  const handleAddPhotos = async (e) => {
    const files = Array.from(e.target.files || []);
    e.target.value = '';
    if (!files.length) return;
    setUploading(true);
    try {
      const urls = [];
      for (const file of files) {
        const res = await Ku.uploadFile(file);
        if (res && res.url) urls.push(res.url);
      }
      if (urls.length) {
        const nextPhotos = [...photos, ...urls];
        const nextCaptions = [...captions, ...urls.map(() => '输入相片标题')];
        setPhotos(nextPhotos);
        setCaptions(nextCaptions);
        // 上传成功后立即显式落盘，避免仅依赖 effect 导致发布/重挂载时列表丢失
        await persist({ photos: nextPhotos, captions: nextCaptions });
      }
    } catch (err) {
      // 上传失败静默处理
    } finally {
      setUploading(false);
    }
  };

  const updateCaption = (idx, val) => {
    setCaptions((prev) => {
      const next = [...prev];
      next[idx] = val;
      return next;
    });
  };

  const updateTech = (idx, val) => {
    setTech((prev) => prev.map((t, i) => (i === idx ? { ...t, label: val } : t)));
  };
  const updateTechOrder = (idx, val) => {
    setTech((prev) => prev.map((t, i) => (i === idx ? { ...t, order: val } : t)));
  };

  return (
    <div
      className="w-full min-h-screen p-2 md:p-3"
      style={{ background: `linear-gradient(${COLORS.skyTop}, ${COLORS.skyMid})`, fontFamily: '"Courier New", monospace' }}
    >
      <div className="mx-auto flex flex-col gap-5" style={{ maxWidth: '1440px' }}>
        {/* 顶部标题：台灯桌面场景 */}
        <div
          className="relative p-4 md:p-6 flex flex-col md:flex-row items-center gap-4 overflow-hidden"
          style={{ background: `linear-gradient(${COLORS.skyTop}, ${COLORS.skyMid})`, ...pixelBorder }}
        >
          <div className="flex flex-col gap-2 items-center md:items-start text-center md:text-left flex-1">
            <div className="flex items-center gap-2">
              <Sparkles size={18} color={COLORS.amber} strokeWidth={2.5} />
              <span style={{ color: COLORS.amber, fontSize: '14px', letterSpacing: '2px' }}>PART 02</span>
            </div>
            <Editable
              as="h1"
              value={heading}
              onChange={setHeading}
              style={{ color: COLORS.lampGlow, fontSize: '76px', fontWeight: 600, letterSpacing: '10px', margin: 0, lineHeight: 1.1, textShadow: `3px 3px 0 ${COLORS.woodDeep}` }}
            />
            <Editable as="p" value={intro} onChange={setIntro} style={{ color: COLORS.cream, fontSize: '14px', lineHeight: 1.7 }} />
          </div>
          <PixelLampDesk />
        </div>

        {/* 两分栏主体 */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5 items-stretch">
          {/* 左：产品原型 相片集 */}
          <div className="p-3 md:p-4 flex flex-col gap-3" style={{ background: COLORS.wood, ...pixelBorder }}>
            <ColumnHeader icon={Home} title={leftTitle} onTitle={setLeftTitle} />
            <PhotoAlbum
              photos={photos}
              current={Math.min(current, Math.max(photos.length - 1, 0))}
              caption={captions[Math.min(current, Math.max(photos.length - 1, 0))] || '输入相片标题'}
              onCaptionChange={(v) => updateCaption(Math.min(current, Math.max(photos.length - 1, 0)), v)}
              onNext={handleNext}
              onAdd={handleAddPhotos}
              onDelete={handleDeletePhoto}
              onMove={handleMovePhoto}
              uploading={uploading}
            />
          </div>

          {/* 右：技术实现 */}
          <div
            className="relative p-3 md:p-4 flex flex-col gap-3 overflow-hidden"
            style={{
              backgroundColor: COLORS.wood,
              backgroundImage: `repeating-linear-gradient(0deg, ${COLORS.woodDark} 0px, ${COLORS.woodDark} 2px, transparent 2px, transparent 44px), repeating-linear-gradient(90deg, rgba(61,40,24,0.35) 0px, rgba(61,40,24,0.35) 2px, transparent 2px, transparent 120px)`,
              ...pixelBorder,
            }}
          >
            {/* 底部像素场景，减少留白 */}
            <div className="absolute left-0 right-0 bottom-0 pointer-events-none" style={{ opacity: 0.5 }}>
              <PixelStoveScene />
            </div>
            <div className="relative flex flex-col gap-3" style={{ zIndex: 1 }}>
              <ColumnHeader icon={Cpu} title={rightTitle} onTitle={setRightTitle} />
            </div>
            <div className="relative flex flex-col gap-4" style={{ zIndex: 1, marginTop: 48 }}>
              {tech.map((t, i) => (
                <TechStep key={i} icon={t.icon} index={t.order} label={t.label} onChange={(v) => updateTech(i, v)} onIndexChange={(v) => updateTechOrder(i, v)} />
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}