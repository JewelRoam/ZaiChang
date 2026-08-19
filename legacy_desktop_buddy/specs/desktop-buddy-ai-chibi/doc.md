# AI 生成真 Q 版形象设计文档（desktop-buddy-ai-chibi）

## 0. 先纠正一件事

上一轮我说「我已经把改造方案写到 `.comate/specs/desktop-buddy-ai-chibi/doc.md`」，但我实际上没有创建这个文件，这份文档是现在才写的。方案内容和我当时口述的一致，但「已经写好了」这句话当时不成立。

## 1. 为什么必须改代码

百炼的图像模型**不支持 OpenAI 兼容模式**，阿里云文档原文：「通过 DashScope 原生接口调用，不支持 OpenAI 兼容（compatible-mode）模式」。它和我现在实现的 `/images/edits` 在三个层面都不一样：

| 维度 | 现有实现（OpenAI 兼容） | 百炼 DashScope |
|---|---|---|
| 请求体 | multipart/form-data，字段 `image` + `prompt` | JSON，`input.messages[0].content` 里放 `{"image":...}` 和 `{"text":...}` |
| 图片传入 | 二进制文件 | 公网 URL 或 `data:image/png;base64,...` 字符串 |
| 返回 | `data[0].b64_json` 或 `data[0].url` | `output.choices[0].message.content[0].image`，是 OSS 临时 URL |
| 有效期 | — | **URL 24 小时后失效，必须立刻下载转存** |

所以直接把百炼地址填进现在的「图像接口地址」一定失败。

## 2. 另一个必须处理的事实：qwen 不保证透明背景

`qwen-image-edit` 系列输出 PNG，但**不保证透明通道**——提示词里写「transparent background」大概率得到的是白底或灰底。而桌面搭子必须是透明背景，否则形象是个矩形色块贴在桌面上。

因此 Q 版的正确流水线要反过来：

```
原图 → AI 生成 Q 版（带底色）→ 抠图去底 → 落盘为 chibi-ai.png
```

而不是 v2 里设计的「先抠图再拿抠图结果去生成」。这意味着 **AI Q 版这条链路依赖抠图服务**。处理策略：
- 配了抠图接口 → 生成后自动抠一次，用户无感
- 没配 → 保留带底色的结果，但在界面上明确提示「这张有背景，配上抠图接口后重新生成会更好」，不假装成功

## 3. 配置与数据模型变更

```ts
interface ModelConfig {
  // …既有字段
  imageStyle: 'openai' | 'dashscope'   // 新增，默认 dashscope
  imageEndpoint: string                // 新增，DashScope 的完整请求地址
}
```

`imageEndpoint` 用**完整 URL** 而不是 base + 拼路径。原因：DashScope 的多模态生成路径较长，且阿里云正在推「业务空间专属域名」，未来路径可能变；让用户直接粘贴文档里的地址，比我在代码里硬编码路径更抗变化。设置页给出默认值作为 placeholder，报 404 时提示用户去文档页复制最新地址。

## 4. 实现要点

```ts
// src/main/avatar/chibi.ts
const CHIBI_PROMPT_ZH = [
  '把画面中的人物改成可爱的 Q 版卡通形象：',
  '头部放大，头身比约 1:1.2，四肢短小圆润；',
  '五官简化但保留原有发型、发色、服装配色和标志性配饰，让人一眼认得出是同一个角色；',
  '线条干净，柔和的赛璐璐上色，颜色明亮饱和；',
  '纯白色背景，全身，正面朝向观众，居中构图；',
  '不要文字、不要水印、不要边框、不要多余人物。'
].join('')

async function generateChibiDashScope(opts): Promise<Buffer> {
  const b64 = (await sharp(src).png().toBuffer()).toString('base64')
  const res = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({
      model,                                   // qwen-image-edit-plus / qwen-image-2.0
      input: { messages: [{ role: 'user', content: [
        { image: `data:image/png;base64,${b64}` },
        { text: CHIBI_PROMPT_ZH }
      ]}]},
      parameters: { n: 1, watermark: false, prompt_extend: true, size: '1024*1024' }
    }),
    signal   // 90s 超时，图像编辑比对话慢
  })
  // 响应结构可能随版本调整，用递归查找第一个图片 URL / base64，而不是死绑路径
  const url = findImageUrl(await res.json())
  return Buffer.from(await (await fetch(url)).arrayBuffer())  // 立刻下载，URL 24h 失效
}
```

提示词用中文：qwen 系列对中文提示词的语义遵循明显好于英文，这是它相对国际模型的主要优势之一，没理由不用。

响应解析用递归查找而非 `output.choices[0].message.content[0].image` 死路径：阿里云的模型和响应字段在半年内改过多次，死绑路径会让一次小改动直接打断功能；递归找「第一个像图片 URL 或 base64 的字符串」更耐用，代价只是几行工具函数。

## 5. 影响文件

| 类型 | 路径 | 说明 |
|---|---|---|
| 修改 | `src/shared/types.ts` | `ModelConfig` 加 `imageStyle`、`imageEndpoint` |
| 修改 | `src/main/store.ts` | 新字段默认值（`dashscope` + 官方默认地址） |
| 修改 | `src/main/avatar/chibi.ts` | 新增 `generateChibiDashScope()`、中文 prompt、`findImageUrl()`；90s 超时 |
| 修改 | `src/main/avatar/manager.ts` | Q 版生成后若配了抠图接口则自动抠一次；源图改回用原图 |
| 修改 | `src/renderer/components/SettingsView.tsx` | 图像接口协议下拉、完整地址输入、模型名提示、结果带底色时的提示文案 |
| 修改 | `README.md` | 百炼配置说明与「Q 版依赖抠图」的说明 |

## 6. 边界与异常

| 场景 | 处理 |
|---|---|
| 地址填成 base（少了路径） | 404，提示「这个地址不对，去文档页复制完整的 HTTP 调用地址」 |
| 北京/新加坡 key 与地址混用 | 鉴权失败，提示「检查地域：北京和新加坡的 key 和地址不能混用」 |
| 免费额度用尽 | 透传阿里云的欠费/额度报错原文，不改写成模糊文案 |
| RPM 限流（图像编辑只有 2 RPM） | 429 时提示「一分钟只能生成 2 张，等等再点」 |
| 生成成功但抠图失败 | 保留带底色的 Q 版，提示抠图失败原因，不丢弃已花钱生成的结果 |
| OSS URL 下载失败 | 明确报「生成成功但下载失败」，并说明结果已计费，可重试生成 |
| 响应里找不到图片 | 报「接口返回里没有图片数据」，并把响应前 200 字打进日志 |

## 7. 验收标准

1. 设置页协议选 DashScope、填完整地址和 `qwen-image-edit-plus`、点「AI Q 版」→ 得到一张真正的 Q 版形象。
2. 配了 rembg 时结果自动透明；没配时结果带底色且有明确提示。
3. 地址错、key 错地域、限流、额度不足四种失败都有可读的具体提示。
4. 生成的 Q 版落盘在 `avatars/{id}/chibi-ai.png`，重启后仍在（不依赖 OSS URL）。
