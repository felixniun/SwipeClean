import Foundation

/// 会话恢复协调（计划书 10.4–10.5）。启动时调用，输出可恢复的整理状态或重建入口。
enum SessionRecoveryOutcome {
    /// 无历史会话，全新开始
    case freshStart
    /// 成功恢复
    case recovered(ReviewState)
    /// 数据损坏：提供安全重建入口，绝不触发删除
    case corrupted
}

struct SessionRecovery {
    let store: ReviewSessionStore

    /// 恢复流程（计划书 10.4）：
    /// 1. 读本地会话 → 2. 版本校验（store 内做）→ 3/5/7. 用当前可见资产集合校验队列与当前资产
    /// → 8/9. reconcile → 10. 返回可继续的会话。
    func recover(currentVisibleAssetIDs: [String]) throws -> SessionRecoveryOutcome {
        guard let snapshot = try store.load() else { return .freshStart }

        let visibleSet = Set(currentVisibleAssetIDs)

        var restored = ReviewState(assetIDs: currentVisibleAssetIDs)
        var queue = snapshot.deletionQueue
        queue.retainValid(existing: visibleSet)
        restored.restore(queue: queue, currentAssetID: snapshot.session.currentAssetID,
                         completedCount: snapshot.session.completedReviewCount)
        restored.reconcile(withExisting: visibleSet, orderedNewIDs: currentVisibleAssetIDs)
        return .recovered(restored)
    }
}
