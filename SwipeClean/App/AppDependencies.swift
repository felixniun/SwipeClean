import SwiftUI

/// 依赖装配（计划书 4.2 App/AppDependencies.swift）。
@MainActor
enum AppDependencies {
    /// 真实照片库模式（阶段 5 起启用）
    static func makePhotoReviewViewModel() -> PhotoReviewViewModel {
        PhotoReviewViewModel(
            repository: PhotoKitRepository(),
            imageService: PhotoImageService(),
            store: LocalSessionStore()
        )
    }

    /// 模拟数据模式（阶段 2–4 真机联调用，不访问系统照片库）
    static func makeMockPhotoReviewViewModel() -> PhotoReviewViewModel {
        PhotoReviewViewModel(
            repository: MockPhotoRepository(),
            imageService: PhotoImageService(),
            store: LocalSessionStore()
        )
    }
}
