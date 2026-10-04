# SwipeClean

iOS 照片整理 App：全屏浏览系统照片库，上滑将照片暂存到待删除队列，复核确认后通过 PhotoKit 批量删除。

完整需求与技术规划见 `docs/DEVELOPMENT_PLAN.md`（如未入库，参考项目计划书 V1.0）。

## 强制约定

1. **左滑下一张，右滑上一张。** 任何实现、动画、测试不得反向。
2. **上滑只标记待删除，绝不立即调用 PhotoKit 删除。**
3. 删除必须经过：标记 → 撤销窗口 → 复核界面 → 明确确认 → 资产/授权校验 → PhotoKit 请求 → 按实际回调更新状态。
4. 以 `PHAsset.localIdentifier` 识别照片，不依赖数组索引。
5. 按需加载 + 相邻预取，不一次性加载全部原图。
6. 本地优先：无后端、无上传、无第三方遥测。

## 目录结构

```text
docs/                      开发计划书、环境部署文档、进度记录
SwipeClean/                App 源码（待在 macOS/Xcode 中创建 .xcodeproj 后挂载）
  App/                     入口与依赖装配
  Models/                  PhotoItem、ReviewSession、DeletionQueue、ReviewAction、ReviewState
  Views/                   SwiftUI 视图
  ViewModels/              浏览与复核 ViewModel
  Services/                手势仲裁、图像加载、删除服务、照片库服务
  Repositories/            PhotoRepository 协议 + Mock + PhotoKit 实现
  Persistence/             会话持久化与恢复
SwipeCleanTests/           XCTest 单元测试
```

## 构建环境（当前状态）

- 开发机：Windows + VS Code + Git（无 Swift 工具链，无法在本地编译）
- 构建路径：macOS + Xcode（待获得，见 `docs/ENVIRONMENT.md`）
- 目标设备：iPhone XS Max / iOS 18
- 部署目标：iOS 18

在获得 macOS 环境前，Windows 端只产出源码与文档；所有 Swift 代码**未经编译验证**，首次在 Xcode 中构建时可能需要修正。

## 开发阶段

见 `docs/PROGRESS.md`。每个阶段完成时按计划书 15.4 格式记录改动文件、测试结果、构建结果和未解决问题。
