<div align="center">

<img src="./logo.jpg" alt="在场 Logo" width="180" />

# 在场

看不见彼此的时光，我也在陪着你。

<p>
  <img src="https://img.shields.io/badge/platform-macOS%20%2F%20iOS%20%2F%20iPadOS-6b7280?style=flat-square" />
  <img src="https://img.shields.io/badge/UI-SwiftUI-0ea5e9?style=flat-square" />
  <img src="https://img.shields.io/badge/style-pixel%20art-f59e0b?style=flat-square" />
  <img src="https://img.shields.io/badge/AI-backstage-8b5cf6?style=flat-square" />
</p>

<p>
  <img src="https://img.shields.io/badge/status-MVP-10b981?style=flat-square" />
  <img src="https://img.shields.io/badge/presence-centered-ef4444?style=flat-square" />
  <img src="https://img.shields.io/badge/desktop-first-111827?style=flat-square" />
</p>

</div>

---

## PART 01 · 项目概览

《在场》是一套面向 macOS / iOS / iPadOS 的 SwiftUI 应用。它是一种常驻桌面的像素陪伴体验，把专注、同桌、留声、回忆收进同一套安静、温暖、不打扰的桌面空间；它不是把一切交给 AI，而是把 AI 放在后台，做时机识别、信息整理和行动建议，真正站在前台的始终是“人在场”的状态和关系。

| 模块 | 说明 |
| --- | --- |
| 像素小屋 | 常驻桌面的主界面，承载场景、桌宠与状态变化。 |
| 在场建议 | 在合适时机出现的轻量提示，只给可执行动作，不做聊天人格。 |
| 同桌 | 通过邀请码进入同一间房间，查看彼此是否在场、专注或离开。 |
| 留声机 | 支持文字 / 语音记录，按时送达。 |
| 回忆 | 把已完成的留声卡片统一收纳。 |
| 场景工坊 | 生成并管理不同氛围的背景场景。 |
| 桌宠 | 通过照片生成陪伴层，叠在背景前方。 |

## PART 02 · 实现方案

这部分来自早期“实现方案页”的结构：左边讲产品，右边讲技术。

### 产品原型

- 像素小屋：把桌面变成一个能被感知的空间。
- 同桌：让两个人进入同一间房间，但不用持续聊天。
- 留声机：把文字和声音变成可等待、可送达的物件。
- 回忆：把已完成的留声内容统一收纳。

### 技术实现

1. SwiftUI + SpriteKit 构建 macOS 窗口与像素场景。
2. AVFoundation 负责录音与播放。
3. 云端数据库 + 实时通信同步同桌状态。
4. 小程序接收邀请、录制留声、查看好友状态。
5. 本地持久化统一落在 Application Support。

## PART 03 · 产品功能

| 功能 | 描述 |
| --- | --- |
| 像素小屋 | 常驻 Mac 桌面的像素小屋，可见角色、状态与房间变化，也能随时收起。 |
| 在场 | 结合时间、日程与习惯，给出轻量提醒与行动建议。 |
| 同桌 | 邀请好友进入同一间像素房间，各自学习工作，看到对方是否在场。 |
| 留声机 | 录一段语音并设置送达时机，让声音成为可等待的物件。 |
| 回忆 | 把留声卡片和后续语音整理成统一的共同记忆。 |

## API 配置与设置

仓库不包含可用 API Key。运行 App 后，打开「设置 → API 设置」填写文本模型、图像模型和可选抠图服务即可。

配置会保存到本机 Application Support 下的 `api.yaml`，主应用会读取最新配置。字段含义以设置页为准；如果不确定，直接查看 `SettingsSheet.swift` 和 `APIConfiguration.swift`。

如果需要提前灌入一份配置，可以复制 `在场/Config/api.example.yaml`，填好后执行：

```bash
./scripts/install-api-config.sh /path/to/api.yaml
```

## 运行

在 Xcode 中打开 `在场.xcodeproj`，选择 `在场` Scheme 和 `My Mac`，然后运行。

开发模式下，部分流程可以通过测试注入 Mock 保持演示；主应用会优先读取本机配置并走真实链路。

## 测试

```bash
xcodebuild \
  -project 在场.xcodeproj \
  -scheme 在场 \
  -destination 'platform=macOS' \
  -only-testing:在场Tests \
  CODE_SIGNING_ALLOWED=NO \
  test
```

单元测试不会读取真实 API Key，也不会调用外部付费服务。

## 安全约束

- 不要把真实 Key 写入 `在场/Config/api.example.yaml`。
- 不要把含 Key 的 YAML 添加到 Xcode Target 或 Copy Bundle Resources。
- `.secrets/` 和所有 `api.yaml` 已由 `.gitignore` 忽略。
- 当前配置适合本地开发，不适合直接发布给终端用户。
- iOS / iPadOS 真机不能直接读取 Mac 的 Application Support 配置；正式分发时需要 Keychain、App 内设置或后端签发的短期凭据。
