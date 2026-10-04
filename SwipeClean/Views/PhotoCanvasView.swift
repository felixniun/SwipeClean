import SwiftUI

/// 照片画布（计划书 11.2）：
/// - 默认完整展示（aspectFit），不裁切边缘，黑色画布。
/// - 双指缩放（1x–4x），放大后单指拖动平移。
/// - 切换照片时由 ViewModel 重置缩放。
struct PhotoCanvasView: View {
    let imageState: ImageLoadState
    @Binding var zoomScale: CGFloat
    var onZoomChanged: (CGFloat) -> Void

    @State private var pinchBase: CGFloat = 1
    @State private var panOffset: CGSize = .zero

    var body: some View {
        ZStack {
            switch imageState {
            case .idle, .loading:
                ProgressView().tint(.white)
            case .failed(let reason):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.icloud")
                        .font(.largeTitle)
                    Text("照片加载失败").font(.headline)
                    Text(reason).font(.caption).foregroundStyle(.secondary)
                }
                .foregroundStyle(.white.opacity(0.7))
            case .loaded(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoomScale)
                    .offset(panOffset)
            }
        }
        .simultaneousGesture(zoomGesture)
        .simultaneousGesture(panGesture)
        .animation(.easeOut(duration: 0.15), value: zoomScale)
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposed = pinchBase * value
                zoomScale = min(max(proposed, 1), 4)
            }
            .onEnded { _ in
                pinchBase = zoomScale
                // 缩放回 1 时复位平移（计划书 6.5）
                if zoomScale <= 1.001 { panOffset = .zero }
                onZoomChanged(zoomScale)
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard zoomScale > 1 else { return }
                panOffset = CGSize(
                    width: value.translation.width,
                    height: value.translation.height
                )
            }
            .onEnded { _ in
                // 平移边界钳制：由真机调参细化（计划书 6.3）
            }
    }
}
