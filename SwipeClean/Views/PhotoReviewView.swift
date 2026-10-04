import SwiftUI
import UIKit

/// 全屏照片浏览主页（计划书 11.1）。
/// 手势方向强制约定：左滑下一张、右滑上一张、上滑标记待删除。
struct PhotoReviewView: View {
    @StateObject private var viewModel: PhotoReviewViewModel
    @State private var showReviewSheet = false
    @State private var dragOffset: CGSize = .zero

    init(viewModel: PhotoReviewViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
                PhotoCanvasView(imageState: viewModel.imageState,
                                zoomScale: $viewModel.zoomScale,
                                onZoomChanged: { viewModel.updateZoom($0) })
                Spacer()
                footer
            }
            .offset(x: dragOffset.width, y: dragOffset.height * 0.3)
            .gesture(swipeGesture, including: viewModel.zoomScale > 1 ? .subviews : .all)
        }
        .task { await viewModel.loadInitial() }
        .sheet(isPresented: $showReviewSheet) {
            DeletionReviewView(viewModel: DeletionReviewViewModel(
                reviewState: viewModel, imageService: viewModel.imageService))
        }
        .overlay(alignment: .top) {
            if let toast = viewModel.toast {
                Text(toast)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var header: some View {
        HStack {
            if let idx = viewModel.state.currentIndex {
                Text("\(idx + 1) / \(viewModel.state.currentCount)")
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
            }
            Spacer()
            if viewModel.state.deletionCount > 0 {
                Text("待删除 \(viewModel.state.deletionCount)")
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }

    private var footer: some View {
        HStack {
            Button("撤销") { Task { await viewModel.undoLastMark() } }
                .disabled(viewModel.state.deletionCount == 0)
            Spacer()
            Button("完成整理") { showReviewSheet = true }
                .disabled(viewModel.state.deletionCount == 0)
        }
        .padding(.horizontal, 24).padding(.bottom, 12)
    }

    // MARK: - 手势（计划书 6.2–6.5）

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                // 放大状态下：拖动只用于平移照片，不驱动切换/标记位移（计划书 6.5）
                if viewModel.zoomScale <= 1 {
                    dragOffset = value.translation
                }
            }
            .onEnded { value in
                defer { dragOffset = .zero }
                let decision = viewModel.coordinator.decideEndGesture(translation: value.translation)
                switch decision {
                case .next:
                    Task { await viewModel.swipeNext() }
                case .previous:
                    Task { await viewModel.swipePrevious() }
                case .markForDeletion:
                    Task { await viewModel.markCurrentForDeletion() }
                case .none:
                    break
                }
            }
    }
}
