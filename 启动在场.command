#!/bin/zsh

# Build and launch the current macOS target from this repository.
set -u

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_FILE="$PROJECT_DIR/在场.xcodeproj"
SCHEME="在场"
DERIVED_DATA_DIR="$PROJECT_DIR/.derived-data"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/Debug/在场.app"

if [[ ! -d "$PROJECT_FILE" ]]; then
  print -u2 "找不到项目：$PROJECT_FILE"
  exit 1
fi

NO_BUILD=false
if [[ "${1:-}" == "--no-build" ]]; then
  NO_BUILD=true
fi

if [[ "$NO_BUILD" != true || ! -x "$APP_PATH/Contents/MacOS/在场" ]]; then
  print "正在构建在场…"
  /usr/bin/xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    build
fi

if [[ ! -x "$APP_PATH/Contents/MacOS/在场" ]]; then
  print -u2 "构建完成，但找不到应用：$APP_PATH"
  exit 1
fi

# Close the currently running copy so the user always opens this build.
/usr/bin/osascript -e 'tell application "在场" to quit' >/dev/null 2>&1 || true
/usr/bin/open "$APP_PATH"
print "已启动：$APP_PATH"
