# 环境与部署路线

更新时间：2026-10-04

## 当前已知条件

| 项目 | 状态 |
| --- | --- |
| Windows PC + VS Code + Git | ✅ 可用 |
| GitHub 账号 | ✅ 已有 |
| GitHub 私有仓库 | ❌ 未创建（本机无 gh CLI，需手动在 github.com 创建，或 `scoop install gh` 后 `gh auth login`） |
| Swift 工具链（Windows） | ❌ 未安装；仅编写源码，不编译 |
| Mac / 云 Mac | ❌ 未确认 |
| iPhone XS Max / iOS 18 | ✅ 目标真机 |
| Apple Developer 免费签名 | ❌ 待在 Mac 上验证 |
| Bundle Identifier | 暂定 `com.ian.swipeclean`，在 Xcode 工程创建时确定 |
| Xcode 版本要求 | 需支持 iOS 18 SDK（Xcode 16 及以上；macOS 需 Sonoma 14.5+）。以实际可用 Mac 为准 |

## 阶段 A：Windows 准备（本次执行）

- [x] 本地 Git 仓库初始化（`main` 分支）
- [x] `.gitignore`（排除证书、签名材料、个人照片）
- [x] 工程目录结构与源码
- [x] XCTest 测试文件（待 macOS 运行）
- [ ] GitHub 私有仓库创建并推送（需用户操作）
- [ ] 准备测试图片及预期行为清单（部分见 docs/TEST_EXPECTATIONS.md，可后续补充）

## 阶段 B：获得 macOS 环境

优先顺序：借用 Mac → 短期云 Mac → （仅在项目值得长期维护后）购买。

云 Mac 租用前必须确认：macOS 版本兼容目标 Xcode、可用自有 Apple 账号签名、真机安装途径（注意：远程桌面通常无法直接访问本地 USB 设备，需确认方案）、源码与产物取回、凭据清理。

## 阶段 C：第一次 Xcode 构建（里程碑）

1. 安装 Xcode 16+，克隆仓库。
2. 在 Xcode 中创建标准 SwiftUI App 工程（Bundle ID：`com.ian.swipeclean`，部署目标 iOS 18），将本仓库 `SwipeClean/SwipeClean/` 与 `SwipeCleanTests/` 下源码挂载进 target。
3. 配置免费个人开发签名（接受有效期与设备数限制，先不购买开发者会员）。
4. 连接 iPhone XS Max，构建最小 App 并真机启动。
5. 将 Xcode 版本、签名方式、结果记录到 `docs/PROGRESS.md`。

**验收门槛：真实 iPhone 成功启动最小 App。在此之前所有功能均为"开发中"，不得标记完成。**

## 安全红线

- Apple 账号密码、证书私钥（.p12/.pem/.key）、描述文件不提交 GitHub，不交给云 Mac 服务方。
- 不提交用户照片、真实资产列表。
- 租用云 Mac 结束后：撤销该机器上的签名证书、退出 Apple 账号、清理钥匙串。
