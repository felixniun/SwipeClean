# 开发进度记录

按计划书 15.4 格式记录。**未经实际验证的任务标记为未完成。**

## 阶段 0：环境与仓库准备 — 开发中

日期：2026-10-04（Windows 端）

### 完成内容

- 本地 Git 仓库初始化，`.gitignore` 建立并排除证书/个人照片。
- 工程目录结构建立（对应计划书 4.2）。
- 全部核心源码与 XCTest 测试编写完成（未编译）。
- 环境与部署文档 `docs/ENVIRONMENT.md`。

### 新增/修改文件

见 Git 提交记录。核心源码：

- `SwipeClean/SwipeClean/Models/`：PhotoItem、ReviewSession、DeletionQueue、ReviewAction、ReviewState（状态机 + 纯逻辑，可在 macOS 上用 XCTest 验证）
- `SwipeClean/SwipeClean/Services/GestureCoordinator.swift`：手势仲裁纯逻辑
- `SwipeClean/SwipeClean/Services/DeletionService.swift`：删除结果状态机
- `SwipeClean/SwipeClean/Persistence/`：LocalSessionStore（Codable JSON）
- `SwipeClean/SwipeClean/Repositories/`：协议 + MockPhotoRepository + PhotoKitRepository
- `SwipeClean/SwipeClean/ViewModels/`、`Views/`、`App/`：SwiftUI 层
- `SwipeCleanTests/`：5 个测试文件

### 测试结果

- ❌ 未运行（Windows 无 Swift 工具链）。测试需在 macOS/Xcode 中首次运行。

### 构建结果

- ❌ 未构建（无 .xcodeproj，需在 macOS 上创建标准工程后挂载源码）。
- ❌ 未真机测试。

### 未解决问题（待用户确认）

1. GitHub 私有仓库未创建（无 gh CLI）：请手动创建或安装 gh 后推送。
2. 借用 Mac / 云 Mac 方案未确认 —— 第一优先级（计划书 18.3）。
3. 视频 / Live Photo 是否纳入 V1 —— 当前按"仅静态图片"实现，查询过滤 `mediaType == .image`。

## 阶段 1：空工程与第一次真机验证 — 未开始

前置：macOS 环境就绪。
