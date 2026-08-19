import React, { useState, useEffect, useCallback } from 'react';
import { Sparkles, Target, Users, TrendingUp, Check, X } from 'lucide-react';
import { toast, Toaster } from 'sonner';

const PIXEL_FONT = `"Courier New", "DotGothic16", monospace`;

// 取自封面图的色调：夜空蓝紫、暖灯橘黄、深木棕、炉火橙、苔绿
const COLORS = {
  skyTop: '#3a2f4a',        // 夜空紫
  skyMid: '#7a5c46',        // 暖褐过渡
  lampGlow: '#f5b850',      // 路灯暖黄
  lampSoft: '#f7d089',      // 柔黄
  wood: '#8a5a3c',          // 木质
  woodDark: '#5e3d28',      // 深木
  woodDeep: '#3d2818',      // 桌面阴影
  cream: '#fdf3dd',         // 米白文字
  panel: '#fff6e4',         // 卡片米白
  panelInk: '#3a2a1a',      // 卡片深字
  muted: '#a07d55',         // 次要文字
  night: '#241d33',
  border: '#241d33',        // 深描边
  amber: '#f5b850',         // 暖灯橘
  ember: '#d9622b',         // 炉火橙
  green: '#6f8a52',         // 苔绿
  sub: '#8a7a5c',           // 次要文字
  tagText: '#241d33',
};

function pixelBorder(color = COLORS.border, size = 4) {
  return {
    boxShadow: `${size}px 0 0 0 ${color}, -${size}px 0 0 0 ${color}, 0 ${size}px 0 0 ${color}, 0 -${size}px 0 0 ${color}, ${size}px ${size}px 0 0 ${color}, -${size}px -${size}px 0 0 ${color}, ${size}px -${size}px 0 0 ${color}, -${size}px ${size}px 0 0 ${color}`,
  };
}

// 像素角色：棕卷发·橄榄开衫男生
const BOY_MATRIX = [
  '......HHHH......',
  '....HHHHHHHH....',
  '...HHHHHHHHHH...',
  '..HHHHHHHHHHHH..',
  '..HHSSSSSSSSHH..',
  '..HSSSSSSSSSSH..',
  '..HSSEESSEESSH..',
  '..HSSSSSSSSSSH..',
  '..HSSSSMMSSSSH..',
  '...SSSSSSSSSS...',
  '.....SSSSSS.....',
  '....CTTTTTTC....',
  '...CCTTTTTTCC...',
  '..CCCTTBBTTCCC..',
  '..CCCTTTTTTCCC..',
  '..CCCTTBBTTCCC..',
  '..CCCTTTTTTCCC..',
  '..SCCTTTTTTCCS..',
  '..CCCC....CCCC..',
  '...PPPPPPPPPP...',
  '...PPPP..PPPP...',
  '...PPPP..PPPP...',
  '...PPPP..PPPP...',
  '...PPPP..PPPP...',
  '..OOOOO..OOOOO..',
];

const BOY_PALETTE = {
  H: '#4a3121',
  S: '#f0c9a0',
  E: '#2c2333',
  M: '#c9603f',
  C: '#7d7135',
  T: '#e2cfa4',
  B: '#5e5227',
  P: '#2a2a3a',
  O: '#5e3d28',
};

// 像素角色：黑长发·白开衫灰阔腿裤女生
const GIRL_MATRIX = [
  '......KKKK......',
  '....KKKKKKKK....',
  '...KKKKKKKKKK...',
  '..KKKKKKKKKKKK..',
  '..KKKSSSSSSKKK..',
  '..KKSSSSSSSSKK..',
  '..KKSEESSEESKK..',
  '..KKSSSSSSSSKK..',
  '..KKSSSMMSSSKK..',
  '..KKKSSSSSSKKK..',
  '..KKKSSSSSSKKK..',
  '..KKKCTTTTCKKK..',
  '..KKCCTTTTCCKK..',
  '..KCCCTTTTCCCK..',
  '..CCCTTTTTTCCC..',
  '..CCCTTTTTTCCC..',
  '..CCCTTTTTTCCC..',
  '..SCCTTTTTTCCS..',
  '..CCCC....CCCC..',
  '...PPPPPPPPPP...',
  '..PPPPP..PPPPP..',
  '..PPPPP..PPPPP..',
  '..PPPPP..PPPPP..',
  '..PPPPP..PPPPP..',
  '..OOOOO..OOOOO..',
];

const GIRL_PALETTE = {
  K: '#241c1c',
  S: '#f0c9a0',
  E: '#2c2333',
  M: '#c9603f',
  C: '#efe9dd',
  T: '#2c2333',
  P: '#565663',
  O: '#e8e8e8',
};

function PixelCharacter({ matrix, palette, cellSize = 5 }) {
  const cols = matrix[0].length;
  const rows = matrix.length;
  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: `repeat(${cols}, ${cellSize}px)`,
        gridTemplateRows: `repeat(${rows}, ${cellSize}px)`,
        imageRendering: 'pixelated',
      }}
    >
      {matrix.flatMap((row, r) =>
        row.split('').map((ch, c) => {
          const color = palette[ch];
          return (
            <div
              key={`${r}-${c}`}
              style={{ width: cellSize, height: cellSize, backgroundColor: color || 'transparent' }}
            />
          );
        })
      )}
    </div>
  );
}

// 封面像素小屋（还原封面角色）
const HUT_MATRIX = [
  '....P..............P....',
  '.......LLLLLLLLL........',
  '......LLLLLLLLLLL.......',
  '......LLLLLLLLLLL.......',
  '........L.....L........',
  '........L.....L........',
  '.......LL.....L........',
  '......LDL.....L........',
  '......LL..FFFFFFFFF.....',
  '.....LDL.FSSSSSSSSSF....',
  '.....LL..FSCCCCCCCSF....',
  '.....LDL.FSCEC.CECSF....',
  '.....LL..FSCCCCCCCSF....',
  '.....LDL.FSCKCMCKCSF....',
  '.....LL..FSCCCCCCCSF....',
  '.....LL..FFFFFFFFFFF....',
  '.....LL.LLLLLLLLLLLLL...',
  'P....LL.LLLLLLLLLLLLL..P',
];

const HUT_PALETTE = {
  L: '#c9a06a',
  D: '#8a5a3c',
  F: '#7d5230',
  S: '#fdf3dd',
  C: '#ffffff',
  E: '#3a2a1a',
  K: '#e5a08a',
  M: '#c9603f',
  P: '#f5b850',
};

function CozyHutPixel({ cellSize = 6 }) {
  const cols = HUT_MATRIX[0].length;
  const rows = HUT_MATRIX.length;
  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: `repeat(${cols}, ${cellSize}px)`,
        gridTemplateRows: `repeat(${rows}, ${cellSize}px)`,
        imageRendering: 'pixelated',
      }}
    >
      {HUT_MATRIX.flatMap((row, r) =>
        row.split('').map((ch, c) => {
          const color = HUT_PALETTE[ch];
          return (
            <div
              key={`${r}-${c}`}
              style={{ width: cellSize, height: cellSize, backgroundColor: color || 'transparent' }}
            />
          );
        })
      )}
    </div>
  );
}

const ILLUS_KEY = 'highlight_illustration_url';

function buildImagePickerContext() {
  return {
    payload: {
      aiPrompt: '温馨像素风格的木质小屋，屋内有一个白色圆脸的可爱角色露出笑脸，暖色调，深棕色背景，8-bit 像素艺术，图中不含文字。',
      searchKeyword: '像素小屋',
    },
  };
}

// 封面插画图片槽位（可上传/替换真实图片）
// 抠掉图片背景：采样四角颜色作为背景色，将相近像素设为透明
function removeBackground(url, threshold = 42) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
      try {
        const canvas = document.createElement('canvas');
        canvas.width = img.naturalWidth;
        canvas.height = img.naturalHeight;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0);
        const w = canvas.width;
        const h = canvas.height;
        const imageData = ctx.getImageData(0, 0, w, h);
        const d = imageData.data;
        const corners = [
          [0, 0],
          [w - 1, 0],
          [0, h - 1],
          [w - 1, h - 1],
        ];
        let br = 0;
        let bg = 0;
        let bb = 0;
        corners.forEach(([x, y]) => {
          const i = (y * w + x) * 4;
          br += d[i];
          bg += d[i + 1];
          bb += d[i + 2];
        });
        br /= 4;
        bg /= 4;
        bb /= 4;
        for (let i = 0; i < d.length; i += 4) {
          const dist = Math.sqrt(
            (d[i] - br) ** 2 + (d[i + 1] - bg) ** 2 + (d[i + 2] - bb) ** 2
          );
          if (dist < threshold) {
            d[i + 3] = 0;
          } else if (dist < threshold * 1.8) {
            d[i + 3] = Math.round(((dist - threshold) / (threshold * 0.8)) * 255);
          }
        }
        ctx.putImageData(imageData, 0, 0);
        resolve(canvas.toDataURL('image/png'));
      } catch (e) {
        reject(e);
      }
    };
    img.onerror = reject;
    img.src = url;
  });
}

function IllustrationSlot() {
  const [imageUrl, setImageUrl] = useState('');
  const [displayUrl, setDisplayUrl] = useState('');
  const [isHovered, setIsHovered] = useState(false);
  const [isReadonly, setIsReadonly] = useState(false);

  useEffect(() => {
    Ku.getDocMetadata()
      .then((info) => setIsReadonly(info?.status === 'readonly'))
      .catch(() => {});
    Ku.dataStorage
      .getItem(ILLUS_KEY)
      .then((v) => {
        if (typeof v === 'string' && v) setImageUrl(v);
      })
      .catch(() => {});
  }, []);

  useEffect(() => {
    if (!imageUrl) {
      setDisplayUrl('');
      return;
    }
    let alive = true;
    removeBackground(imageUrl)
      .then((u) => {
        if (alive) setDisplayUrl(u);
      })
      .catch(() => {
        if (alive) setDisplayUrl(imageUrl);
      });
    return () => {
      alive = false;
    };
  }, [imageUrl]);

  const pickImage = async () => {
    try {
      const result = await Ku.image.openPickerDialog(buildImagePickerContext());
      if (result?.url) {
        setImageUrl(result.url);
        await Ku.dataStorage.setItem(ILLUS_KEY, result.url);
        toast.success('封面已更新', { position: 'top-center' });
      }
    } catch (e) {
      console.error('配图失败:', e);
    }
  };

  const previewImage = () => {
    if (imageUrl) Ku.editor.preview([imageUrl]);
  };

  return (
    <div
      className="relative mb-3 flex items-center justify-center overflow-hidden"
      style={{ backgroundColor: 'transparent', minHeight: '160px' }}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      {imageUrl ? (
        <img
          src={displayUrl || imageUrl}
          alt="产品封面"
          className={`object-contain ${isReadonly ? 'cursor-zoom-in' : ''}`}
          style={{
            width: '100%',
            maxHeight: '260px',
            imageRendering: 'pixelated',
          }}
          onClick={isReadonly ? previewImage : undefined}
        />
      ) : (
        <div className="flex items-center justify-center p-2" style={{ opacity: 0.9 }}>
          <CozyHutPixel cellSize={window.isMobile ? 4 : 6} />
        </div>
      )}

      {!isReadonly && isHovered && (
        <div className="absolute inset-0 flex items-center justify-center gap-2" style={{ backgroundColor: 'rgba(36,29,51,0.35)' }}>
          <button
            onClick={pickImage}
            className="px-3 py-1"
            style={{ backgroundColor: COLORS.panel, color: COLORS.panelInk, border: `3px solid ${COLORS.border}`, fontFamily: PIXEL_FONT, fontSize: '14px' }}
          >
            配图
          </button>
          {imageUrl && (
            <button
              onClick={previewImage}
              className="px-3 py-1"
              style={{ backgroundColor: COLORS.panel, color: COLORS.panelInk, border: `3px solid ${COLORS.border}`, fontFamily: PIXEL_FONT, fontSize: '14px' }}
            >
              预览
            </button>
          )}
        </div>
      )}
    </div>
  );
}

// 突出的漫画分格小标题
function ComicHeading({ children, color }) {
  return (
    <div
      className="inline-block px-3 py-1 mb-2"
      style={{
        backgroundColor: color,
        color: COLORS.tagText,
        fontFamily: PIXEL_FONT,
        fontSize: '16px',
        fontWeight: 'bold',
        border: `3px solid ${COLORS.border}`,
        boxShadow: `3px 3px 0 0 ${COLORS.border}`,
        letterSpacing: '1px',
      }}
    >
      {children}
    </div>
  );
}

function EditableBlock({ storageKey, placeholder, defaultValue = '' }) {
  const [value, setValue] = useState('');
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState('');

  useEffect(() => {
    let alive = true;
    Ku.dataStorage
      .getItem(storageKey)
      .then((v) => {
        if (alive) setValue(typeof v === 'string' && v ? v : defaultValue);
      })
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, [storageKey]);

  const save = useCallback(async () => {
    try {
      await Ku.dataStorage.setItem(storageKey, draft);
      setValue(draft);
      setEditing(false);
      toast.success('已保存', { position: 'top-center' });
    } catch (e) {
      toast.error('保存失败，请重试', { position: 'top-center' });
    }
  }, [draft, storageKey]);

  const cancel = () => {
    setEditing(false);
    setDraft(value);
  };

  if (editing) {
    return (
      <div>
        <textarea
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          rows={3}
          className="w-full p-2 outline-none resize-y"
          style={{
            fontFamily: PIXEL_FONT,
            fontSize: '14px',
            color: COLORS.panelInk,
            backgroundColor: '#fffaf0',
            border: `3px solid ${COLORS.amber}`,
          }}
          placeholder={placeholder}
        />
        <div className="flex gap-2 mt-2">
          <button
            onClick={save}
            className="flex items-center gap-1 px-3 py-1"
            style={{ backgroundColor: COLORS.green, color: COLORS.cream, border: `3px solid ${COLORS.border}`, fontFamily: PIXEL_FONT, fontSize: '14px' }}
          >
            <Check size={14} />
            <span>保存</span>
          </button>
          <button
            onClick={cancel}
            className="flex items-center gap-1 px-3 py-1"
            style={{ backgroundColor: '#b0a58f', color: COLORS.night, border: `3px solid ${COLORS.border}`, fontFamily: PIXEL_FONT, fontSize: '14px' }}
          >
            <X size={14} />
            <span>取消</span>
          </button>
        </div>
      </div>
    );
  }

  return (
    <div
      onDoubleClick={() => {
        setDraft(value);
        setEditing(true);
      }}
      title="双击编辑"
    >
      {value ? (
        <p
          className="whitespace-pre-wrap leading-relaxed"
          style={{ fontFamily: PIXEL_FONT, fontSize: '14px', color: COLORS.panelInk }}
        >
          {value}
        </p>
      ) : (
        <p
          className="italic"
          style={{ fontFamily: PIXEL_FONT, fontSize: '14px', color: COLORS.sub }}
        >
          {placeholder}
        </p>
      )}
    </div>
  );
}

// 单个漫画分格
function ComicPanel({ label, color, storageKey, placeholder, defaultValue }) {
  return (
    <div
      className="relative p-3 flex flex-col"
      style={{ backgroundColor: COLORS.panel, ...pixelBorder(COLORS.border, 4) }}
    >
      <ComicHeading color={color}>{label}</ComicHeading>
      <EditableBlock storageKey={storageKey} placeholder={placeholder} defaultValue={defaultValue} />
    </div>
  );
}

// 一个板块（漫画章节）
function ComicChapter({ icon: Icon, tagColor, title, subtitle, storagePrefix, points, cols, illustration }) {
  return (
    <div
      className="p-4 flex flex-col h-full"
      style={{ backgroundColor: COLORS.wood, ...pixelBorder(COLORS.border, 4) }}
    >
      <div className="flex items-center gap-2 mb-4 mt-1 flex-wrap">
        <div
          className="flex items-center justify-center"
          style={{ width: '36px', height: '36px', backgroundColor: tagColor, border: `3px solid ${COLORS.border}` }}
        >
          <Icon size={20} color={COLORS.tagText} />
        </div>
        <div>
          <h3 style={{ fontFamily: PIXEL_FONT, fontSize: '18px', fontWeight: 'bold', color: COLORS.cream }}>
            {title}
          </h3>
          <span style={{ fontFamily: PIXEL_FONT, fontSize: '14px', fontWeight: 'bold', color: COLORS.lampSoft, letterSpacing: '1px' }}>
            {subtitle}
          </span>
        </div>
      </div>

      {illustration && <IllustrationSlot />}

      <div
        className={`grid gap-4 flex-1 ${cols === 2 ? 'grid-cols-1 sm:grid-cols-2' : 'grid-cols-1'}`}
      >
        {points.map((p) => (
          <ComicPanel
            key={p.key}
            label={p.label}
            color={tagColor}
            storageKey={`${storagePrefix}_${p.key}`}
            placeholder={p.placeholder}
            defaultValue={p.default || ''}
          />
        ))}
      </div>
    </div>
  );
}

export default function App() {
  const chapters = [
    {
      icon: Sparkles,
      tagColor: COLORS.ember,
      title: '产品特点',
      subtitle: 'FEATURES',
      storagePrefix: 'highlight_feature_v3',
      cols: 2,
      illustration: true,
      points: [
        { key: 'copresence', label: '轻社交的在场感', placeholder: '双击编辑……', default: '共享时间与空间，沉默、离开、晚回都不尴尬。' },
        { key: 'voice', label: '异步留声', placeholder: '双击编辑……', default: '语音留声机，会在特定时刻响起的陪伴。' },
        { key: 'desktop', label: '定制形象', placeholder: '双击编辑……', default: '常驻 Mac 桌面的像素小屋，随时间与状态生长。' },
        { key: 'boundary', label: '有边界的情感', placeholder: '双击编辑……', default: '不制造依赖，AI 与真实关系边界清晰可控。' },
      ],
    },
    {
      icon: Users,
      tagColor: COLORS.green,
      title: '目标用户群体广泛',
      subtitle: 'AUDIENCE',
      storagePrefix: 'highlight_audience_v3',
      cols: 1,
      points: [
        { key: 'core', label: '核心画像', placeholder: '双击编辑……', default: '独居、异地求学、创作者、远程办公者——需要专注又不想孤军奋战。' },
        { key: 'extend', label: '典型场景', placeholder: '双击编辑……', default: '异地情侣、好友、学习搭子——不缺聊天工具，缺「同频在场感」。' },
        { key: 'scale', label: '延伸空间', placeholder: '双击编辑……', default: '桌搭文化爱好者——愿为氛围与情感价值付费。' },
      ],
    },
    {
      icon: TrendingUp,
      tagColor: COLORS.amber,
      title: '市场价值',
      subtitle: 'MARKET VALUE',
      storagePrefix: 'highlight_market_v3',
      cols: 1,
      points: [
        { key: 'size', label: '市场规模', placeholder: '双击编辑：目标市场规模与增长……' },
        { key: 'model', label: '赛道验证', placeholder: '双击编辑：赛道热度与验证信号……' },
        { key: 'advantage', label: '竞争优势', placeholder: '双击编辑：差异化竞争优势……' },
      ],
    },
  ];

  return (
    <div
      className="min-h-screen w-full p-4 sm:p-6"
      style={{
        backgroundImage: `linear-gradient(to bottom, ${COLORS.skyTop} 0%, ${COLORS.skyMid} 55%, ${COLORS.lampGlow} 100%)`,
      }}
    >
      <Toaster richColors />
      <div className="mx-auto" style={{ maxWidth: '1440px' }}>
        <div
          className="relative p-4 sm:p-6 mb-8 flex items-center justify-between gap-4 flex-wrap"
          style={{
            backgroundImage: `linear-gradient(to bottom, ${COLORS.skyTop} 0%, #4a3a63 60%, #6a4d7a 100%)`,
            ...pixelBorder(COLORS.border, 4),
          }}
        >
          <div className="text-left">
            <div className="flex items-center gap-2">
              <Sparkles size={22} color={COLORS.amber} />
              <span style={{ fontFamily: PIXEL_FONT, fontSize: '14px', fontWeight: 'bold', color: COLORS.amber, letterSpacing: '2px' }}>
                PART 04
              </span>
            </div>
            <h1
              className="mt-2"
              style={{ fontFamily: PIXEL_FONT, fontSize: '76px', fontWeight: 'bold', color: COLORS.lampGlow, textShadow: `3px 3px 0 ${COLORS.border}` }}
            >
              项目亮点
            </h1>
            <p className="mt-1" style={{ fontFamily: PIXEL_FONT, fontSize: '14px', fontWeight: 'bold', color: COLORS.lampSoft }}>
              PROJECT HIGHLIGHTS
            </p>
          </div>

          <div className="flex items-end gap-3 pr-2">
            <PixelCharacter matrix={BOY_MATRIX} palette={BOY_PALETTE} cellSize={window.isMobile ? 4 : 6} />
            <PixelCharacter matrix={GIRL_MATRIX} palette={GIRL_PALETTE} cellSize={window.isMobile ? 4 : 6} />
          </div>
        </div>

        {/* 三章漫画横向并列 */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-5 items-stretch">
          {chapters.map((c) => (
            <ComicChapter key={c.storagePrefix} {...c} />
          ))}
        </div>
      </div>
    </div>
  );
}