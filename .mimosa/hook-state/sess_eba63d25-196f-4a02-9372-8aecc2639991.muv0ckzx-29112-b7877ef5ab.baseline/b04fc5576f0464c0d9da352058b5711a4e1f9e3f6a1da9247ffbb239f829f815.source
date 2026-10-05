#!/bin/zsh
# SwipeClean macOS 初始化脚本（阶段 1 / 阶段 C）
# 用法：在 Mac 上克隆仓库后执行  zsh setup-mac.sh
# 覆盖：Xcode/工具检查 -> 生成 xcodeproj -> 模拟器构建启动 -> 截图验证。
# 真机（iPhone XS Max）步骤见脚本末尾输出的人工检查清单。

set -euo pipefail
cd "$(dirname "$0")"

fail() { echo "❌ $1"; exit 1; }
ok()   { echo "✅ $1"; }

# 1. 环境检查（ios-simulator 插件 preflight 的等价物：完整 Xcode 必须，仅 CLT 不够）
echo "== 1. 环境检查 =="
xcode-select -p >/dev/null 2>&1 || fail "未设置 Xcode 路径：先安装 Xcode 16+ 并运行 sudo xcode-select -s /Applications/Xcode.app"
XCODE_VERSION=$(xcodebuild -version | head -1) || fail "xcodebuild 不可用"
ok "$XCODE_VERSION"
xcrun simctl list runtimes | grep -q "iOS 18" || fail "未安装 iOS 18 模拟器 runtime（Xcode > Settings > Platforms）"
ok "iOS 18 simulator runtime"
command -v xcodegen >/dev/null 2>&1 || {
  echo "安装 xcodegen (brew install xcodegen)..."
  command -v brew >/dev/null 2>&1 && brew install xcodegen || fail "需要 Homebrew 或手动安装 xcodegen"
}
ok "xcodegen"

# 2. 生成工程
echo "== 2. 生成 SwipeClean.xcodeproj =="
xcodegen generate
ok "工程已生成（.gitignore 已排除，不入库）"

# 3. 模拟器构建 + 启动（阶段 1 验收：App 可构建可启动）
echo "== 3. 模拟器构建与启动 =="
DEVICE="iPhone 16 Pro"
UDID=$(xcrun simctl list devices available | grep "$DEVICE (" | head -1 | grep -Eo '\(([0-9A-F-]+)\)' | tr -d '()')
[ -n "$UDID" ] || fail "找不到可用模拟器 $DEVICE"
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator

xcodebuild -project SwipeClean.xcodeproj -scheme SwipeClean \
  -destination "platform=iOS Simulator,id=$UDID" build || fail "模拟器构建失败（先修编译错误，勿继续）"
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "SwipeClean.app" -path "*iphonesimulator*" | head -1)
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" com.ian.swipeclean || fail "启动失败"
sleep 3
xcrun simctl io "$UDID" screenshot build/sim-launch.png && ok "截图: build/sim-launch.png"

# 4. macOS 逻辑测试（swift test，无需模拟器）
echo "== 4. swift test（XCTest 正式结果）=="
swift test 2>&1 | tail -5 || fail "swift test 失败"

cat <<'EOF'

== 人工步骤（真机 iPhone XS Max / iOS 18）==
1. USB 连接 iPhone，解锁并在 Xcode > Devices 中信任。
2. Xcode > Settings > Accounts 登录 Apple ID（免费签名即可）。
3. project.yml 中填 DEVELOPMENT_TEAM（或 Xcode 里选择 Team）。
4. 选择真机设备，Product > Run 安装并启动。
5. 首次启动会弹出照片授权 —— 选择"允许完全访问"。
6. 记录 Xcode 版本、签名方式、结果到 docs/PROGRESS.md（阶段 1 验收门槛）。
EOF
