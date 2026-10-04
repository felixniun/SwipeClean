import Foundation

/// 浏览模式（计划书 6.1）。
enum ReviewMode: Equatable {
    case normal
    case zoomed
    case reviewingDeletions
    case committingDeletion
    case permissionBlocked
    case loading
}

/// 删除提交状态（计划书 8.5）。
enum DeletionCommitState: Equatable {
    case pending
    case validating
    case submitting
    case completed(validAssetIDs: [String], failedAssetIDs: [String])
    case failed(reason: String)
    case needsReconciliation
}

/// 删除意图（手势仲裁的输出，仅供 ViewModel 消费）。
enum SwipeIntent: Equatable {
    case next
    case previous
    case markForDeletion
    case none
}

/// 浏览状态机核心。纯逻辑、不依赖 PhotoKit / SwiftUI，可在任意平台被 XCTest 覆盖。
///
/// 强制约定：左滑下一张、右滑上一张、上滑只标记待删除（计划书 6.2 / 最终执行原则 1、2）。
struct ReviewState {
    private(set) var assetIDs: [String]
    /// 当前资产标识（不是索引——索引只在这里内部使用）
    private(set) var currentAssetID: String?
    private(set) var deletionQueue = DeletionQueue()
    private(set) var history = ReviewActionHistory()
    private(set) var mode: ReviewMode = .normal
    private(set) var commitState: DeletionCommitState = .pending
    /// 已确认提交且成功的资产不计入撤销范围（计划书 8.6）
    private(set) var completedReviewCount = 0

    var currentIndex: Int? {
        guard let id = currentAssetID else { return nil }
        return assetIDs.firstIndex(of: id)
    }

    var currentCount: Int { assetIDs.count }
    var deletionCount: Int { deletionQueue.count }
    var reviewedCount: Int {
        // 已浏览 = 总数 - 尚未浏览过的数量。用 current 之后位置近似会导致恢复后漂移，
        // 因此以“曾经成为 current 的资产数”记录在 completedReviewCount + 当前，由 ViewModel 维护。
        completedReviewCount
    }

    init(assetIDs: [String], currentAssetID: String? = nil) {
        self.assetIDs = assetIDs
        self.currentAssetID = currentAssetID ?? assetIDs.first
    }

    // MARK: - 导航（阶段 2 验收核心）

    /// 左滑：下一张。已在最后一张时返回 nil（首尾边界行为明确，不循环）。
    @discardableResult
    mutating func goNext() -> String? {
        guard modeAllowsNavigation else { return nil }
        guard let idx = currentIndex, idx + 1 < assetIDs.count else { return nil }
        currentAssetID = assetIDs[idx + 1]
        return currentAssetID
    }

    /// 右滑：上一张。已在第一张时返回 nil。
    @discardableResult
    mutating func goPrevious() -> String? {
        guard modeAllowsNavigation else { return nil }
        guard let idx = currentIndex, idx > 0 else { return nil }
        currentAssetID = assetIDs[idx - 1]
        return currentAssetID
    }

    private var modeAllowsNavigation: Bool {
        switch mode {
        case .normal, .zoomed, .loading:
            return true
        case .reviewingDeletions, .committingDeletion, .permissionBlocked:
            return false
        }
    }

    // MARK: - 上滑标记（绝不触发真实删除）

    /// 上滑标记待删除并进入下一张（计划书 8.1）。返回产生的 ReviewAction（供持久化），失败返回 nil。
    mutating func markCurrentForDeletion(now: Date = Date()) -> ReviewAction? {
        guard modeAllowsNavigation, mode == .normal else { return nil }
        guard let id = currentAssetID else { return nil }
        let action = ReviewAction(
            actionType: .markForDeletion,
            assetID: id,
            previousAssetID: id,
            createdAt: now
        )
        guard deletionQueue.add(id, at: now, actionID: action.id) else {
            // 已在队列中：不产生重复项，但仍前进到下一张
            _ = goNext()
            return nil
        }
        history.push(action)
        completedReviewCount += 1
        _ = goNext()
        return action
    }

    // MARK: - 撤销（计划书 6.8）

    /// 撤销最近一次可撤销的待删除标记。返回被撤销的资产标识；无可撤销操作返回 nil。
    mutating func undoLastMark(now: Date = Date()) -> String? {
        guard case .normal = mode else { return nil }
        guard let action = history.popLast(), action.actionType == .markForDeletion else { return nil }
        deletionQueue.remove(action.assetID)
        // 恢复浏览位置：回到被撤销的资产（若仍可见）；否则尝试其前驱，再否则保持当前位置。
        if assetIDs.contains(action.assetID) {
            currentAssetID = action.assetID
        }
        completedReviewCount = max(0, completedReviewCount - 1)
        history.push(ReviewAction(actionType: .unmarkDeletion, assetID: action.assetID,
                                  previousAssetID: action.previousAssetID, createdAt: now))
        history.popLast() // unmark 动作本身不可再撤销，不入栈
        return action.assetID
    }

    // MARK: - 资产失效协调（计划书 5.5 / 14.2）

    /// 照片库变化后同步本地状态：剔除失效资产，为当前资产寻找合理后继。
    mutating func reconcile(withExisting existingIDs: Set<String>, orderedNewIDs: [String]? = nil) {
        let newIDs = orderedNewIDs ?? assetIDs.filter { existingIDs.contains($0) }
        assetIDs = newIDs
        deletionQueue.retainValid(existing: existingIDs)
        if let id = currentAssetID, existingIDs.contains(id), newIDs.contains(id) {
            return
        }
        currentAssetID = newIDs.first
    }

    /// 复核界面：按标识移出队列（不是撤销栈操作）。
    @discardableResult
    mutating func removeFromQueue(_ assetID: String) -> Bool {
        deletionQueue.remove(assetID)
    }

    // MARK: - 模式切换

    /// 从持久化快照恢复（计划书 10.4）。仅恢复校验后仍有效的队列与位置。
    mutating func restore(queue: DeletionQueue, currentAssetID: String?, completedCount: Int) {
        deletionQueue = queue
        completedReviewCount = completedCount
        if let id = currentAssetID, assetIDs.contains(id) {
            self.currentAssetID = id
        }
    }

    mutating func setMode(_ newMode: ReviewMode) { mode = newMode }
    mutating func setCommitState(_ newState: DeletionCommitState) { commitState = newState }

    /// 提交删除成功后：从队列移除已成功资产并刷新集合（计划书 8.4）。
    mutating func commitCompleted(successIDs: [String], failedIDs: [String]) {
        for id in successIDs {
            deletionQueue.remove(id)
        }
        commitState = .completed(validAssetIDs: successIDs, failedAssetIDs: failedIDs)
    }
}
