import SwiftUI

/// 图库为空 / 无可见照片占位（计划书 11.5）。
struct EmptyLibraryView: View {
    var isLimitedPermission: Bool

    var body: some View {
        ContentUnavailableView(
            isLimitedPermission ? "没有可见照片" : "照片库为空",
            systemImage: "photo.on.rectangle",
            description: Text(isLimitedPermission
                ? "当前授权范围内没有可选照片，可在系统设置中扩大授权。"
                : "照片库中没有照片可供整理。"))
    }
}
