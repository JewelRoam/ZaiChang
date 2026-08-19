// 内置兜底形象：没有上传或素材缺失时显示，用 SVG 内联避免额外资源文件
const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <ellipse cx="100" cy="182" rx="52" ry="10" fill="rgba(0,0,0,0.12)"/>
  <circle cx="100" cy="100" r="72" fill="#8ec5ff"/>
  <circle cx="100" cy="100" r="72" fill="none" stroke="#ffffff" stroke-width="6"/>
  <circle cx="76" cy="92" r="9" fill="#22314a"/>
  <circle cx="124" cy="92" r="9" fill="#22314a"/>
  <circle cx="79" cy="89" r="3" fill="#fff"/>
  <circle cx="127" cy="89" r="3" fill="#fff"/>
  <path d="M82 122 q18 16 36 0" stroke="#22314a" stroke-width="6" fill="none" stroke-linecap="round"/>
  <circle cx="58" cy="112" r="7" fill="#ff9db0" opacity="0.7"/>
  <circle cx="142" cy="112" r="7" fill="#ff9db0" opacity="0.7"/>
</svg>`

export default `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`
