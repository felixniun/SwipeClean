// swift-tools-version:6.0
// Windows/macOS 双用途包：
// - Windows：跑 SwipeCleanCore 纯逻辑 + LogicTestsRunner（无 XCTest 可用）
// - macOS/Xcode：正式 App 仍由 .xcodeproj 构建，此包仅用于在 Mac 上跑 XCTest
import PackageDescription

let package = Package(
    name: "SwipeClean",
    platforms: [.iOS(.v18), .macOS(.v15)],
    targets: [
        // 平台无关核心逻辑（状态机、手势仲裁、队列、持久化、Mock 仓库）
        .target(
            name: "SwipeCleanCore",
            path: "SwipeClean",
            exclude: [
                "App",
                "Views",
                "ViewModels",
                "Resources",
                "Info.plist",
                "Services/PhotoImageService.swift",
                "Services/PhotoLibraryService.swift",
                "Services/DeletionService.swift",
                "Repositories/PhotoKitRepository.swift"
            ]
        ),
        // Windows 测试入口（Windows 工具链没有 XCTest）
        .executableTarget(
            name: "LogicTestsRunner",
            dependencies: ["SwipeCleanCore"],
            path: "WindowsTests"
        ),
        // macOS 上用 XCTest 跑完整测试
        .testTarget(
            name: "SwipeCleanTests",
            dependencies: ["SwipeCleanCore"],
            path: "SwipeCleanTests"
        )
    ]
)
