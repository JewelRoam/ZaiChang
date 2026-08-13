# 在场

《在场》是一个同时支持 macOS、iOS 和 iPadOS 的 SwiftUI 项目。仓库不包含任何可用 API Key；AI 功能通过本机 `api.yaml` 配置。

## 本地 API 配置

### 1. 创建私有配置

在项目根目录执行：

```bash
mkdir -p .secrets
cp 在场/Config/api.example.yaml .secrets/api.yaml
```

编辑 `.secrets/api.yaml`：

```yaml
text:
  provider: openai
  api_key: "YOUR_TEXT_API_KEY"
  base_url: https://your-openai-compatible-service.example/v1
  model: your-text-model

image:
  provider: dashscope
  api_key: "YOUR_DASHSCOPE_API_KEY"
  base_url: ""
  endpoint: https://your-dashscope-workspace.example/api/v1/services/aigc/multimodal-generation/generation
  model: qwen-image-edit-plus
  size: 1024x1024
  scene_model: qwen-image-3.0
  scene_size: 1664x928

matting:
  provider: removebg
  api_key: "YOUR_REMOVE_BG_API_KEY"
  endpoint: https://api.remove.bg/v1.0/removebg
```

配置职责：

- `text`：OpenAI-compatible `/chat/completions`，用于文本整理和后续在场建议。
- `image.model`：DashScope 图像编辑模型，用于好友照片生成桌宠。
- `image.scene_model`：DashScope 文字生图模型，用于生成无人物场景背景。
- `matting`：remove.bg，用于把生成图片处理成透明 PNG；不配置时仍可生图，但结果可能带背景。

三个服务相互独立，不要把文本模型 Key 当作图像 Key 使用。

### 2. 安装配置

```bash
./scripts/install-api-config.sh .secrets/api.yaml
```

脚本会把配置以 `600` 权限安装到：

```text
~/Library/Application Support/Zaichang/api.yaml
~/Library/Containers/com.zhengenrong.zaichang/Data/Library/Application Support/Zaichang/api.yaml
```

第二个路径供 Xcode 中启用 App Sandbox 的 macOS App 使用。修改 YAML 后需要重新运行安装脚本并重启 App。

如修改了 Bundle Identifier：

```bash
ZAICHANG_BUNDLE_ID=com.example.zaichang \
  ./scripts/install-api-config.sh .secrets/api.yaml
```

### 3. 运行验证

在 Xcode 中打开 `在场.xcodeproj`，选择 `在场` Scheme 和 `My Mac`，然后运行。进入“同桌”后选择好友照片，生成流程应依次执行：

```text
照片 -> DashScope 生成 Q 版桌宠 -> remove.bg 去背景 -> 透明桌宠预览
```

如果图像服务没有配置，MVP 会退回本地 Mock。远程服务配置错误时，界面会显示失败原因并允许重新生成。

## 安全约束

- 不要把真实 Key 写入 `在场/Config/api.example.yaml`。
- 不要把含 Key 的 YAML 添加到 Xcode Target 或 Copy Bundle Resources。
- `.secrets/` 和所有 `api.yaml` 已由 `.gitignore` 忽略。
- 当前 YAML 适合本地开发，不适合发布给终端用户。正式分发前应由服务端代理第三方 API，并把用户令牌存进 Keychain。
- iOS/iPadOS 真机不能读取 Mac 的 Application Support 配置。移动端正式接入需要 Keychain、App 内设置或后端签发的短期凭据。

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

单元测试不读取真实 API Key，也不会调用外部付费服务。

## 本地演示指令

先启动本地指令服务：

```bash
python3 scripts/demo-control-server.py
```

再在 Xcode Scheme 的 `Run > Arguments > Environment Variables` 中添加：

```text
ZAICHANG_DEMO_CONTROL_URL = http://127.0.0.1:8765
```

推进当前倒计时、延时在场建议和拍一拍冷却：

```bash
curl -X POST http://127.0.0.1:8765/commands/advance-time \
  -H 'Content-Type: application/json' \
  -d '{"seconds":300}'
```

模拟当前同桌拍了拍我：

```bash
curl -X POST http://127.0.0.1:8765/commands/receive-nudge
```

服务只监听 `127.0.0.1`；未设置 `ZAICHANG_DEMO_CONTROL_URL` 时，App 不会启动指令轮询。
