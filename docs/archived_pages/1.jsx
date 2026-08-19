import React, { useState, useEffect, useCallback } from 'react';
import { Lightbulb, HeartCrack, Compass, Users, Sparkles, Check, X, Moon, BookOpen, Feather } from 'lucide-react';
import { toast, Toaster } from 'sonner';

const PIXEL_FONT = `'Nunito', 'Quicksand', 'Comic Sans MS', 'PingFang SC', 'Microsoft YaHei', 'Segoe UI', sans-serif`;

const COLORS = {
  // 背景夜色暖木
  skyTop: '#3a2f4a',
  skyMid: '#7a5c46',
  lampGlow: '#f5b850',
  lampSoft: '#f7d089',
  wood: '#8a5a3c',
  woodDark: '#5e3d28',
  woodDeep: '#3d2818',
  // 书皮（棕色）
  coverBrown: '#6b4326',
  coverBrownHi: '#7d5230',
  coverBrownDark: '#4a2d17',
  coverEdge: '#2f1c0e',
  // 内页（旧书泛黄）
  pageCream: '#e9d5a8',
  pageCreamShade: '#ddc492',
  pageLine: '#c9ad78',
  gutter: '#b89a68',
  pageEdge: '#d8c391',
  pageEdgeDark: '#c2a870',
  // 文字
  ink: '#5b4126',
  inkSoft: '#6b5231',
  gold: '#c9962e',
  goldBright: '#e0a84a',
};

function PixelStyles() {
  return (
    <style>{`
      @keyframes zc-twinkle { 0%,100%{ opacity: 0.25; } 50%{ opacity: 1; } }
      @keyframes zc-lampglow { 0%,100%{ opacity: 0.55; } 50%{ opacity: 1; } }
    `}</style>
  );
}

// 顶部标题（书籍扉页题名）
function BookTitleBanner() {
  return (
    <div
      style={{
        position: 'relative',
        background: `linear-gradient(180deg, #1a1226 0%, #241832 45%, #2c1f1a 80%, ${COLORS.woodDeep} 130%)`,
        border: `3px solid ${COLORS.woodDeep}`,
        boxShadow: `4px 4px 0 0 ${COLORS.woodDeep}`,
        padding: '40px 20px',
        overflow: 'hidden',
      }}
      className="mb-4"
    >
      <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
        {[
          { l: '8%', t: '22%', s: 3 }, { l: '20%', t: '58%', s: 2 }, { l: '35%', t: '30%', s: 2 },
          { l: '52%', t: '18%', s: 3 }, { l: '68%', t: '50%', s: 2 }, { l: '82%', t: '28%', s: 3 },
          { l: '90%', t: '62%', s: 2 }, { l: '44%', t: '68%', s: 2 },
          { l: '4%', t: '48%', s: 2 }, { l: '14%', t: '80%', s: 3 }, { l: '28%', t: '12%', s: 2 },
          { l: '40%', t: '48%', s: 2 }, { l: '48%', t: '82%', s: 3 }, { l: '60%', t: '32%', s: 2 },
          { l: '64%', t: '76%', s: 2 }, { l: '74%', t: '14%', s: 2 }, { l: '78%', t: '66%', s: 3 },
          { l: '86%', t: '46%', s: 2 }, { l: '94%', t: '20%', s: 2 }, { l: '96%', t: '80%', s: 3 },
          { l: '30%', t: '70%', s: 2 }, { l: '56%', t: '60%', s: 2 }, { l: '12%', t: '38%', s: 2 },
        ].map((st, i) => (
          <div
            key={i}
            style={{
              position: 'absolute', left: st.l, top: st.t,
              width: `${st.s}px`, height: `${st.s}px`,
              backgroundColor: COLORS.lampSoft,
              boxShadow: `0 0 6px ${COLORS.lampGlow}`,
              animation: `zc-twinkle 2.6s ease-in-out ${i * 0.3}s infinite`,
            }}
          />
        ))}
      </div>
      <div
        style={{
          position: 'absolute', right: '6%', top: '18px',
          width: '24px', height: '24px', borderRadius: '50%',
          boxShadow: `8px 5px 0 0 ${COLORS.lampGlow}`,
          pointerEvents: 'none',
        }}
      />
      <div className="flex items-center justify-between flex-wrap gap-3" style={{ position: 'relative' }}>
        <div>
          <div className="flex items-center gap-2" style={{ marginBottom: '6px' }}>
            <Sparkles size={16} color={COLORS.lampGlow} />
            <span style={{ color: COLORS.lampGlow, fontSize: '14px', letterSpacing: '2px', fontFamily: PIXEL_FONT }}>
              PART 01 · 创意背景
            </span>
          </div>
          <h1
            style={{
              color: COLORS.lampGlow,
              fontSize: window.isMobile ? '46px' : '68px',
              fontFamily: PIXEL_FONT,
              letterSpacing: '10px',
              margin: 0,
              textShadow: `4px 4px 0 ${COLORS.woodDeep}`,
              lineHeight: 1.1,
            }}
          >
            创意来源
          </h1>
          <p style={{ color: COLORS.pageCream, fontSize: '16px', marginTop: '8px', fontFamily: PIXEL_FONT }}>
            翻开这本书 —— 一个想法如何诞生
          </p>
        </div>
      </div>
    </div>
  );
}

// 内页中的一「章」内容（放在书页里）
function PageChapter({ storageKey, icon: Icon, index, title, hint, placeholder }) {
  const [content, setContent] = useState('');
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState('');
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    let mounted = true;
    Ku.dataStorage
      .getItem(storageKey)
      .then((val) => {
        if (mounted && typeof val === 'string') setContent(val);
      })
      .catch(() => {})
      .finally(() => mounted && setLoaded(true));
    return () => {
      mounted = false;
    };
  }, [storageKey]);

  const startEdit = useCallback(() => {
    setDraft(content);
    setEditing(true);
  }, [content]);

  const save = useCallback(() => {
    const value = draft.trim();
    setContent(value);
    setEditing(false);
    Ku.dataStorage
      .setItem(storageKey, value)
      .then(() => toast.success('已记入书页'))
      .catch(() => toast.error('保存失败，请重试'));
  }, [draft, storageKey]);

  const cancel = useCallback(() => {
    setEditing(false);
    setDraft('');
  }, []);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', minWidth: 0, flex: 1 }}>
      {/* 章标题：手写扉页式 */}
      <div className="flex items-center gap-3" style={{ borderBottom: `2px solid ${COLORS.pageLine}`, paddingBottom: '8px' }}>
        <div
          style={{
            width: '40px', height: '40px', flexShrink: 0,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}
        >
          <Feather size={30} color={COLORS.gold} strokeWidth={2} style={{ transform: 'rotate(-8deg)' }} />
        </div>
        <div style={{ minWidth: 0, flex: 1 }}>
          <span style={{ color: COLORS.inkSoft, fontSize: '14px', fontFamily: PIXEL_FONT, letterSpacing: '3px' }}>
            {`第 0${index} 章`}
          </span>
          <h2
            style={{
              color: COLORS.ink,
              fontSize: window.isMobile ? '22px' : '26px',
              fontFamily: PIXEL_FONT,
              margin: '2px 0 0',
              letterSpacing: '4px',
              fontWeight: 'bold',
            }}
          >
            {title}
          </h2>
        </div>
      </div>

      <p
        style={{
          color: COLORS.inkSoft, fontSize: '14px', fontFamily: PIXEL_FONT, margin: '0 0 -14px',
          lineHeight: 1.5, fontStyle: 'italic', height: '38px', overflow: 'hidden',
        }}
      >
        {hint}
      </p>

      {editing ? (
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          <textarea
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            placeholder={placeholder}
            rows={5}
            style={{
              width: '100%', backgroundColor: 'rgba(255,255,255,0.5)', color: COLORS.ink,
              border: `2px solid ${COLORS.gold}`, padding: '10px', fontFamily: PIXEL_FONT,
              fontSize: '16px', lineHeight: 1.9, resize: 'vertical', outline: 'none',
              boxSizing: 'border-box', minHeight: '120px',
              backgroundImage: `repeating-linear-gradient(180deg, transparent 0px, transparent 29px, ${COLORS.pageLine} 29px, ${COLORS.pageLine} 30px)`,
            }}
          />
          <div className="flex gap-2 mt-3">
            <button
              onClick={save}
              className="flex items-center gap-1"
              style={{
                backgroundColor: COLORS.gold, color: '#fff',
                border: `2px solid ${COLORS.coverBrownDark}`, padding: '5px 12px',
                fontFamily: PIXEL_FONT, fontSize: '14px', cursor: 'pointer', fontWeight: 'bold',
              }}
            >
              <Check size={14} />
              <span>记入</span>
            </button>
            <button
              onClick={cancel}
              className="flex items-center gap-1"
              style={{
                backgroundColor: 'transparent', color: COLORS.inkSoft,
                border: `2px solid ${COLORS.inkSoft}`, padding: '5px 12px',
                fontFamily: PIXEL_FONT, fontSize: '14px', cursor: 'pointer',
              }}
            >
              <X size={14} />
              <span>取消</span>
            </button>
          </div>
        </div>
      ) : (
        <div
          onClick={startEdit}
          style={{
            cursor: 'pointer', minHeight: '90px', padding: '4px 2px',
            fontFamily: PIXEL_FONT, fontSize: '16px', lineHeight: '30px',
            color: content ? COLORS.ink : COLORS.inkSoft,
            whiteSpace: 'pre-wrap', wordBreak: 'break-word',
            backgroundImage: `repeating-linear-gradient(180deg, transparent 0px, transparent 29px, ${COLORS.pageLine} 29px, ${COLORS.pageLine} 30px)`,
          }}
        >
          {loaded ? (content || placeholder) : '加载中…'}
        </div>
      )}
    </div>
  );
}

// 单页内页（米黄），含书页装订侧阴影
function BookPage({ side, children }) {
  const isLeft = side === 'left';
  return (
    <div
      style={{
        position: 'relative',
        flex: 1,
        minWidth: 0,
        backgroundColor: COLORS.pageCream,
        padding: window.isMobile ? '20px 18px' : '30px 38px',
        display: 'flex',
        flexDirection: 'column',
        gap: '22px',
        boxSizing: 'border-box',
        // 翻页弧度：靠脊侧加深，外沿高亮，模拟厚书弯曲的纸面
        backgroundImage: isLeft
          ? `linear-gradient(90deg, rgba(255,248,225,0.5) 0%, transparent 18%, transparent 78%, rgba(120,80,30,0.14) 96%, rgba(74,45,23,0.28) 100%)`
          : `linear-gradient(90deg, rgba(74,45,23,0.28) 0%, rgba(120,80,30,0.14) 4%, transparent 22%, transparent 82%, rgba(255,248,225,0.5) 100%)`,
        boxShadow: isLeft
          ? `inset -30px 0 42px -22px rgba(74,45,23,0.7)`
          : `inset 30px 0 42px -22px rgba(74,45,23,0.7)`,
      }}
    >
      {children}
    </div>
  );
}

// 桌上一摞小书
function BookStack() {
  const books = [
    { w: window.isMobile ? 92 : 128, color: COLORS.coverBrown, edge: COLORS.coverBrownDark },
    { w: window.isMobile ? 78 : 108, color: '#7a4a3a', edge: '#5a3428' },
    { w: window.isMobile ? 86 : 118, color: '#8a6d34', edge: '#5f4a20' },
  ];
  const bh = window.isMobile ? 11 : 15;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      {books.map((b, i) => (
        <div
          key={i}
          style={{
            width: `${b.w}px`,
            height: `${bh}px`,
            marginTop: i === 0 ? 0 : '-2px',
            marginLeft: i % 2 === 0 ? '0' : `${i * 4}px`,
            backgroundColor: b.color,
            border: `2px solid ${b.edge}`,
            borderRadius: '3px',
            boxShadow: `0 2px 0 0 ${b.edge}`,
            backgroundImage: `linear-gradient(90deg, ${b.edge} 0%, ${b.edge} 5px, transparent 5px), linear-gradient(90deg, transparent calc(100% - 5px), ${b.edge} calc(100% - 5px))`,
            position: 'relative',
          }}
        >
          <div
            style={{
              position: 'absolute', left: '10px', right: '10px', top: '50%',
              height: '1px', transform: 'translateY(-50%)',
              backgroundColor: COLORS.gold, opacity: 0.5,
            }}
          />
        </div>
      ))}
    </div>
  );
}

// 书桌与台灯：书本仿佛摆在暖光台灯下的木桌上
function DeskAndLamp() {
  return (
    <div style={{ position: 'relative', marginTop: window.isMobile ? '70px' : '110px', width: '100%' }}>
      {/* 桌面上的小书堆（左侧） */}
      <div
        style={{
          position: 'absolute',
          left: window.isMobile ? '18px' : '70px',
          bottom: window.isMobile ? '14px' : '20px',
          zIndex: 3,
        }}
      >
        <BookStack />
      </div>

      {/* 台灯（右侧） */}
      <div
        style={{
          position: 'absolute',
          right: window.isMobile ? '10px' : '60px',
          bottom: window.isMobile ? '14px' : '20px',
          zIndex: 2,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
        }}
      >
        {/* 灯罩 */}
        <div style={{ position: 'relative' }}>
          <div
            style={{
              width: window.isMobile ? '52px' : '72px',
              height: window.isMobile ? '26px' : '36px',
              background: `linear-gradient(180deg, ${COLORS.coverBrownHi} 0%, ${COLORS.coverBrown} 60%, ${COLORS.coverBrownDark} 100%)`,
              borderRadius: '50% 50% 12px 12px / 90% 90% 12px 12px',
              border: `2px solid ${COLORS.coverEdge}`,
              boxShadow: `inset 0 -4px 8px rgba(0,0,0,0.3)`,
            }}
          />
          {/* 灯口暖光 */}
          <div
            style={{
              position: 'absolute',
              left: '50%',
              bottom: '-4px',
              transform: 'translateX(-50%)',
              width: window.isMobile ? '30px' : '44px',
              height: '8px',
              backgroundColor: COLORS.lampSoft,
              borderRadius: '50%',
              boxShadow: `0 0 26px 14px ${COLORS.lampGlow}`,
              animation: 'zc-lampglow 3.2s ease-in-out infinite',
            }}
          />
        </div>
        {/* 灯杆 */}
        <div
          style={{
            width: '5px',
            height: window.isMobile ? '30px' : '46px',
            backgroundColor: COLORS.woodDark,
            marginTop: '2px',
          }}
        />
        {/* 灯座 */}
        <div
          style={{
            width: window.isMobile ? '34px' : '48px',
            height: window.isMobile ? '8px' : '11px',
            background: `linear-gradient(180deg, ${COLORS.woodDark}, ${COLORS.woodDeep})`,
            borderRadius: '6px 6px 3px 3px',
            border: `1px solid ${COLORS.coverEdge}`,
          }}
        />
      </div>

      {/* 桌面暖光晕 */}
      <div
        style={{
          position: 'absolute',
          right: window.isMobile ? '-10px' : '30px',
          bottom: window.isMobile ? '14px' : '20px',
          width: window.isMobile ? '180px' : '260px',
          height: '60px',
          background: `radial-gradient(ellipse at center, ${COLORS.lampGlow}55 0%, transparent 70%)`,
          pointerEvents: 'none',
          zIndex: 1,
        }}
      />

      {/* 桌子（仅桌面，无桌腿） */}
      <div style={{ position: 'relative', zIndex: 2 }}>
        <div
          style={{
            height: window.isMobile ? '16px' : '22px',
            background: `linear-gradient(180deg, ${COLORS.wood} 0%, ${COLORS.woodDark} 100%)`,
            borderRadius: '6px',
            border: `2px solid ${COLORS.woodDeep}`,
            boxShadow: `0 6px 0 0 ${COLORS.woodDeep}, 0 12px 18px -6px rgba(0,0,0,0.4)`,
            backgroundImage: `repeating-linear-gradient(90deg, rgba(94,61,40,0.25) 0px, rgba(94,61,40,0.25) 2px, transparent 2px, transparent 46px)`,
          }}
        />
      </div>
    </div>
  );
}

export default function App() {
  const sections = [
    {
      key: 'zaichang_bg_inspiration',
      icon: Lightbulb,
      title: '灵感来源',
      hint: '想法从何而来 —— 一个场景、一次观察、一份情绪',
      placeholder: '在此写下灵感来源…',
    },
    {
      key: 'zaichang_bg_companion_status',
      icon: HeartCrack,
      title: '陪伴类APP现状',
      hint: '当下同类产品做了什么，又有哪些未被满足的痛点',
      placeholder: '在此梳理陪伴类 APP 的现状与痛点…\n例如：\n· 现状：多以高频聊天、虚拟恋人、语音社交为主\n· 痛点：依赖持续对话，易造成打扰与压力。',
    },
    {
      key: 'zaichang_bg_positioning',
      icon: Compass,
      title: '产品定位',
      hint: '我们的产品是什么？',
      placeholder: '在此写下产品定位…\n例如：一款为专注人群打造的沉浸式陪伴空间。',
    },
    {
      key: 'zaichang_bg_users',
      icon: Users,
      title: '目标用户',
      hint: '核心用户是谁、有什么需求、在什么场景使用',
      placeholder: '在此写下目标用户…\n例如：18-35 岁的自由职业者、学生与远程工作者。',
    },
  ];

  const leftSections = sections.slice(0, 2);
  const rightSections = sections.slice(2, 4);

  return (
    <div
      style={{
        minHeight: '100vh',
        width: '100%',
        background: `linear-gradient(180deg, ${COLORS.skyTop} 0%, ${COLORS.skyMid} 55%, ${COLORS.lampGlow} 140%)`,
        padding: window.isMobile ? '14px' : '24px',
        fontFamily: PIXEL_FONT,
        position: 'relative',
        overflow: 'hidden',
        boxSizing: 'border-box',
      }}
    >
      <PixelStyles />
      <div
        style={{
          position: 'absolute', inset: 0, pointerEvents: 'none',
          backgroundImage: `radial-gradient(rgba(253,243,221,0.12) 1.5px, transparent 1.5px)`,
          backgroundSize: '22px 22px',
        }}
      />
      <Toaster position="top-center" richColors />

      <div style={{ maxWidth: '1440px', width: '100%', margin: '0 auto', position: 'relative', boxSizing: 'border-box' }}>
        <BookTitleBanner />

        {/* 一本翻开的书 */}
        <div
          style={{
            position: 'relative',
            // 棕色书皮外框
            backgroundColor: COLORS.coverBrown,
            backgroundImage: `linear-gradient(180deg, ${COLORS.coverBrownHi} 0%, ${COLORS.coverBrown} 40%, ${COLORS.coverBrownDark} 100%)`,
            border: `3px solid ${COLORS.coverEdge}`,
            borderRadius: '10px',
            boxShadow: `
              10px 0 0 -1px ${COLORS.pageEdge},
              14px 0 0 -1px ${COLORS.pageEdgeDark},
              18px 0 0 -1px ${COLORS.pageEdge},
              22px 0 0 -1px ${COLORS.pageEdgeDark},
              26px 0 0 -1px ${COLORS.pageEdge},
              -10px 0 0 -1px ${COLORS.pageEdge},
              -14px 0 0 -1px ${COLORS.pageEdgeDark},
              -18px 0 0 -1px ${COLORS.pageEdge},
              -22px 0 0 -1px ${COLORS.pageEdgeDark},
              -26px 0 0 -1px ${COLORS.pageEdge},
              30px 18px 0 0 ${COLORS.woodDeep},
              -30px 18px 0 0 ${COLORS.woodDeep}
            `,
            padding: window.isMobile ? '14px' : '22px',
            margin: window.isMobile ? '0 30px' : '0 34px',
            boxSizing: 'border-box',
          }}
        >
          {/* 书皮内烫金压线边框 */}
          <div
            style={{
              position: 'absolute', inset: window.isMobile ? '6px' : '9px',
              border: `1px solid ${COLORS.gold}`, borderRadius: '6px',
              opacity: 0.4, pointerEvents: 'none', zIndex: 3,
            }}
          />

          {/* 内页容器 */}
          <div
            style={{
              position: 'relative',
              display: 'flex',
              flexDirection: window.isMobile ? 'column' : 'row',
              borderRadius: '4px',
              overflow: 'hidden',
              boxShadow: `inset 0 0 0 1px ${COLORS.coverBrownDark}`,
            }}
          >
            <BookPage side="left">
              {leftSections.map((s, i) => (
                <PageChapter
                  key={s.key}
                  storageKey={s.key}
                  icon={s.icon}
                  index={i + 1}
                  title={s.title}
                  hint={s.hint}
                  placeholder={s.placeholder}
                />
              ))}
            </BookPage>

            {/* 中缝装订线 */}
            {!window.isMobile && (
              <div
                style={{
                  width: '26px',
                  flexShrink: 0,
                  background: `linear-gradient(90deg, rgba(255,248,225,0.4) 0%, ${COLORS.gutter} 22%, ${COLORS.coverBrownDark} 50%, ${COLORS.gutter} 78%, rgba(255,248,225,0.4) 100%)`,
                  boxShadow: `inset 0 0 14px rgba(74,45,23,0.5)`,
                }}
              />
            )}
            {window.isMobile && (
              <div style={{ height: '8px', background: `linear-gradient(180deg, ${COLORS.gutter}, ${COLORS.coverBrownDark}, ${COLORS.gutter})` }} />
            )}

            <BookPage side="right">
              {rightSections.map((s, i) => (
                <PageChapter
                  key={s.key}
                  storageKey={s.key}
                  icon={s.icon}
                  index={i + 3}
                  title={s.title}
                  hint={s.hint}
                  placeholder={s.placeholder}
                />
              ))}
            </BookPage>
          </div>

          {/* 书签丝带 */}
          <div
            style={{
              position: 'absolute',
              top: window.isMobile ? '12px' : '18px',
              right: window.isMobile ? '40px' : '70px',
              width: '14px',
              height: window.isMobile ? '46px' : '64px',
              backgroundColor: COLORS.gold,
              clipPath: 'polygon(0 0, 100% 0, 100% 100%, 50% 78%, 0 100%)',
              boxShadow: `2px 2px 0 0 ${COLORS.woodDeep}`,
              zIndex: 4,
            }}
          />
        </div>

        {/* 书桌与台灯 */}
        <DeskAndLamp />
      </div>
    </div>
  );
}