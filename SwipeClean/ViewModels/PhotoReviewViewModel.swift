import Foundation
import SwiftUI

/// 浏览主 ViewModel（计划书 4.3）。
///
/// 职责：当前资产、导航、待删除队列、撤销、进度、会话持久化、资产变化协调。
/// 不直接调用 PhotoKit 删除——真实删除只发生在 DeletionReviewViewModel 确认后。
@MainActor
final class PhotoReviewViewModel: ObservableObject {
    @Published private(set) var state: ReviewState
    @Published var imageState: ImageLoadState = .idle
    /// 当前照片的缩放比例（由 PhotoCanvasView 回写）
    @Published var zoomScale: CGFloat = 1
    @Published var isAnimating = false
    @Published var toast: String?

    let imageService: PhotoImageService
    private let repository: PhotoRepository
    private let store: ReviewSessionStore
    let coordinator = GestureCoordinator()

    init(repository: PhotoRepository, imageService: PhotoImageService, store: ReviewSessionStore) {
        self.repository = repository
        self.imageService = imageService
        self.store = store
        self.state = ReviewState(assetIDs: [])
    }

    // MARK: - 启动加载与恢复

    func loadInitial() async {
        do {
            let ids = try await repository.fetchAssetIDs()
            switch try store.load() {
            case .some(let snapshot):
                var restored = ReviewState(assetIDs: ids)
                var queue = snapshot.deletionQueue
                queue.retainValid(existing: Set(ids))
                restored.restore(queue: queue, currentAssetID: snapshot.session.currentAssetID,
                                 completedCount: snapshot.session.completedReviewCount)
                state = restored
            case nil:
                state = ReviewState(assetIDs: ids)
            }
            await loadCurrentImage()
        } catch {
            toast = "会话恢复失败，已重新开始"
            // 数据损坏时的安全重建入口：不触发删除（计划书 10.4）
            try? store.clear()
        }
    }

    // MARK: - 导航（左滑下一张 / 右滑上一张）

    func swipeNext() async {
        guard let next = state.goNext() else { return }
        await onCurrentChanged(to: next)
    }

    func swipePrevious() async {
        guard let prev = state.goPrevious() else { return }
        await onCurrentChanged(to: prev)
    }

    private func onCurrentChanged(to assetID: String) async {
        // 切换照片时的状态重置（计划书 6.6）
        zoomScale = 1
        imageState = .idle
        await loadCurrentImage()
        prefetchNeighbors(of: assetID)
        saveSession()
    }

    private func loadCurrentImage() async {
        guard let id = state.currentAssetID else { return }
        imageState = .loading
        let result = await imageService.loadFullImage(assetID: id)
        // 防止异步回调串台：只有仍是当前资产才应用（计划书 6.6）
        if state.currentAssetID == id {
            imageState = result
        }
    }

    private func prefetchNeighbors(of assetID: String) {
        guard let idx = state.currentIndex else { return }
        var neighbors: [String] = []
        if idx + 1 < state.currentCount { neighbors.append(state.assetIDs[idx + 1]) }
        if idx > 0 { neighbors.append(state.assetIDs[idx - 1]) }
        imageService.prefetch(assetIDs: neighbors)
    }

    // MARK: - 上滑标记（绝不触发真实删除）

    func markCurrentForDeletion() async {
        coordinator.isAnimating = true
        defer { coordinator.isAnimating = false }
        if let _ = state.markCurrentForDeletion() {
            toast = "已加入待删除队列"
        }
        zoomScale = 1
        imageState = .idle
        await loadCurrentImage()
        saveSession()
    }

    // MARK: - 撤销

    func undoLastMark() async {
        guard let id = state.undoLastMark() else { return }
        toast = "已撤销标记"
        if state.currentAssetID == id {
            await loadCurrentImage()
        }
        saveSession()
    }

    // MARK: - 缩放（计划书 6.5）

    func updateZoom(_ scale: CGFloat) {
        zoomScale = scale
        if scale > 1 {
            state.setMode(.zoomed)
        } else {
            state.setMode(.normal)
        }
    }

    // MARK: - 照片库变化（计划书 14.2）

    func handleLibraryChange(newIDs: [String]) async {
        state.reconcile(withExisting: Set(newIDs), orderedNewIDs: newIDs)
        await loadCurrentImage()
        saveSession()
    }

    // MARK: - 持久化（计划书 10.3）

    private func saveSession() {
        let snapshot = SessionSnapshot(
            session: ReviewSession(
                schemaVersion: ReviewSession.currentSchemaVersion
            ),
            deletionQueue: state.deletionQueue,
            lastUndoableAction: nil,
            lastUpdatedAt: Date()
        )
        var snapshot = snapshot
        snapshot.session.currentAssetID = state.currentAssetID
        snapshot.session.completedReviewCount = state.completedReviewCount
        do {
            try store.save(snapshot)
        } catch {
            toast = "进度保存失败"
        }
    }
}
