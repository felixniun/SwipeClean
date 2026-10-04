import Foundation
import SwiftUI

/// 复核与确认删除 ViewModel（计划书 8.2–8.6）。
@MainActor
final class DeletionReviewViewModel: ObservableObject {
    @Published private(set) var queuedAssetIDs: [String] = []
    @Published private(set) var isCommitting = false
    @Published private(set) var commitResult: DeletionCommitState = .pending
    @Published var thumbnails: [String: UIImage] = [:]

    private let reviewState: PhotoReviewViewModel
    private let deletionService = DeletionService()
    private let imageService: PhotoImageService

    init(reviewState: PhotoReviewViewModel, imageService: PhotoImageService) {
        self.reviewState = reviewState
        self.imageService = imageService
        self.queuedAssetIDs = reviewState.state.deletionQueue.assetIDs
    }

    var count: Int { queuedAssetIDs.count }

    /// 复核页出现时刷新队列（用户可能在浏览页又标记/撤销过）。
    func refreshQueue() {
        queuedAssetIDs = reviewState.state.deletionQueue.assetIDs
    }

    /// 单张移出队列（计划书 8.2）。
    func removeOne(_ assetID: String) {
        _ = reviewState.state.removeFromQueue(assetID)
        queuedAssetIDs = reviewState.state.deletionQueue.assetIDs
        loadThumbnails()
    }

    func loadThumbnails() {
        Task {
            for id in queuedAssetIDs {
                if let img = await imageService.loadThumbnail(assetID: id) {
                    thumbnails[id] = img
                }
            }
        }
    }

    /// 确认删除（计划书 8.3–8.5）：锁定重复提交 → 校验 → 提交 → 按实际结果更新。
    func confirmDeletion() async {
        guard !isCommitting else { return }
        guard !queuedAssetIDs.isEmpty else { return }
        isCommitting = true
        reviewState.state.setCommitState(.validating)

        do {
            let valid = await deletionService.validate(assetIDs: queuedAssetIDs)
            let validOrdered = queuedAssetIDs.filter { valid.contains($0) }
            let invalid = queuedAssetIDs.filter { !valid.contains($0) }
            if !invalid.isEmpty {
                // 部分资产已不存在：重新计算有效数量，提示用户（计划书 8.3.6）
                commitResult = .needsReconciliation
                queuedAssetIDs = validOrdered
                isCommitting = false
                return
            }

            reviewState.state.setCommitState(.submitting)
            let result = try await deletionService.delete(assetIDs: validOrdered)
            reviewState.state.commitCompleted(successIDs: result.deletedIDs, failedIDs: result.failedIDs)
            commitResult = .completed(validAssetIDs: result.deletedIDs, failedAssetIDs: result.failedIDs)
            queuedAssetIDs = result.failedIDs
        } catch DeletionService.DeletionError.permissionDenied {
            commitResult = .failed(reason: "权限不足，无法删除")
        } catch {
            commitResult = .failed(reason: error.localizedDescription)
        }
        isCommitting = false
    }
}
