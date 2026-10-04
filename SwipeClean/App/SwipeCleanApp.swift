import SwiftUI

@main
struct SwipeCleanApp: App {
    @StateObject private var viewModel: PhotoReviewViewModel
    @StateObject private var permission = PermissionObserver()

    init() {
        // 阶段 5 前可切换为 makeMockPhotoReviewViewModel()
        _viewModel = StateObject(wrappedValue: AppDependencies.makePhotoReviewViewModel())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch permission.state {
                case .authorized, .limited:
                    PhotoReviewView(viewModel: viewModel)
                case .notDetermined, .deniedOrRestricted:
                    PermissionView(state: permission.state) {
                        permission.state = await permission.service.requestAccess()
                    }
                }
            }
            .animation(.default, value: permission.state)
        }
    }
}

/// 权限状态观察（计划书 9.1.5：权限状态变化要有对应 UI）。
@MainActor
final class PermissionObserver: ObservableObject {
    let service = PhotoLibraryService()
    @Published var state: PhotoPermissionState

    init() {
        state = service.currentState()
    }
}
