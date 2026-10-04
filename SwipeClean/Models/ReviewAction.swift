import Foundation

/// 整理操作记录（计划书 5.4）。撤销针对具体操作记录，而不是简单地把索引减一。
struct ReviewAction: Codable, Equatable, Identifiable {
    enum ActionType: String, Codable {
        /// 上滑标记待删除
        case markForDeletion
        /// 撤销标记（本身也可被跟踪，便于进度恢复）
        case unmarkDeletion
    }

    var id: String
    var actionType: ActionType
    var assetID: String
    /// 操作发生前的浏览位置（资产标识，不是索引）
    var previousAssetID: String?
    var createdAt: Date

    init(actionType: ActionType, assetID: String, previousAssetID: String?, createdAt: Date = Date()) {
        self.id = UUID().uuidString
        self.actionType = actionType
        self.assetID = assetID
        self.previousAssetID = previousAssetID
        self.createdAt = createdAt
    }
}

/// 可撤销历史。V1 只要求撤销最近一次标记，但用栈保存以便扩展（V2 更多撤销历史）。
struct ReviewActionHistory: Codable, Equatable {
    private(set) var actions: [ReviewAction] = []

    var lastAction: ReviewAction? { actions.last }
    var isEmpty: Bool { actions.isEmpty }

    mutating func push(_ action: ReviewAction) {
        actions.append(action)
    }

    /// 弹出最近一条可撤销操作，防止同一操作被重复撤销。
    mutating func popLast() -> ReviewAction? {
        actions.popLast()
    }
}
