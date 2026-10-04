import Foundation

/// 待删除队列（计划书 5.3）。资产标识唯一：同一张照片重复标记不产生多个待删除项。
struct DeletionQueue: Codable, Equatable {
    var queueVersion: Int = 1
    /// 有序资产标识（按标记顺序）
    private(set) var assetIDs: [String] = []
    /// assetID -> 标记时间 / 触发的 actionID
    private(set) var markedAt: [String: Date] = [:]
    private(set) var actionIDs: [String: String] = [:]

    var count: Int { assetIDs.count }
    var isEmpty: Bool { assetIDs.isEmpty }

    /// 加入队列。已存在时返回 false，不产生重复项。
    @discardableResult
    mutating func add(_ assetID: String, at date: Date = Date(), actionID: String) -> Bool {
        guard !assetIDs.contains(assetID) else { return false }
        assetIDs.append(assetID)
        markedAt[assetID] = date
        actionIDs[assetID] = actionID
        return true
    }

    /// 移出队列（撤销 / 复核时取消标记）。返回是否确实移除了。
    @discardableResult
    mutating func remove(_ assetID: String) -> Bool {
        guard let idx = assetIDs.firstIndex(of: assetID) else { return false }
        assetIDs.remove(at: idx)
        markedAt[assetID] = nil
        actionIDs[assetID] = nil
        return true
    }

    /// 资产失效 / 已被外部删除时批量清除，返回被清除的标识。
    @discardableResult
    mutating func retainValid(existing: Set<String>) -> [String] {
        let removed = assetIDs.filter { !existing.contains($0) }
        for id in removed { remove(id) }
        return removed
    }

    mutating func removeAll() {
        assetIDs = []
        markedAt = [:]
        actionIDs = [:]
    }

    func contains(_ assetID: String) -> Bool {
        assetIDs.contains(assetID)
    }
}
