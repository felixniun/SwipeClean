import SwiftUI

/// 权限引导页（计划书 9.1–9.3 / 11.5）。
struct PermissionView: View {
    let state: PhotoPermissionState
    var onRequest: () async -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
            Text(title).font(.title2).fontWeight(.semibold)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            switch state {
            case .notDetermined:
                Button("允许访问照片") { Task { await onRequest() } }
                    .buttonStyle(.borderedProminent)
            case .deniedOrRestricted, .limited:
                Link("前往系统设置", destination: URL(string: UIApplication.openSettingsURLString)!)
                    .buttonStyle(.borderedProminent)
            case .authorized:
                EmptyView()
            }
        }
        .padding()
    }

    private var title: String {
        switch state {
        case .notDetermined: return "需要访问照片"
        case .deniedOrRestricted: return "照片访问被拒绝"
        case .limited: return "仅可访问部分照片"
        case .authorized: return ""
        }
    }

    private var message: String {
        switch state {
        case .notDetermined:
            return "SwipeClean 只在本机整理照片，不上传任何照片或信息。"
        case .deniedOrRestricted:
            return "请在系统设置中允许访问照片后返回。"
        case .limited:
            return "你只授权了部分照片，仅会浏览已授权的照片。可在系统设置中调整。"
        case .authorized:
            return ""
        }
    }
}
