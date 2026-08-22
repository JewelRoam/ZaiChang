# 在场网页页

这里是《在场》一页式展示网站的独立源码目录。

## 本地预览

在仓库根目录启动任意静态服务器，例如：

```bash
python3 -m http.server 4173
```

然后打开 <http://127.0.0.1:4173/docs/pages/>。这样页面才能读取仓库中归档的图片和视频素材。

页面源码会引用 `assets/` 中的网页素材，并保持 `docs/archived_pages/` 不变：

- `docs/pages/scenes/*.png`：网页首屏场景牌组，点击可随机切换
- `docs/pages/assets/logo.jpg`：网页 Logo
- `docs/pages/assets/cover.png`：Demo 视频封面
- `docs/pages/assets/memory/*.png`：记忆卡片展示图
- `docs/pages/assets/ZaiChang_ad_vid.mp4`：由发布工作流从归档目录复制的视频

本地预览时，视频会回退读取 `docs/archived_pages/ZaiChang_ad_vid.mp4`；发布产物会把视频放进 `assets/`，不需要复制一份到源码目录。
- `在场/MemoryCardArt/*.png`
- `docs/archived_pages/ZaiChang_ad_vid.mp4`

后续启用 GitHub Project Pages 时，可以把这个目录作为静态站点入口，或者将它作为 GitHub Actions 的发布源。页面目前不依赖构建工具，便于先确定内容和视觉，再决定是否引入 Vite。
