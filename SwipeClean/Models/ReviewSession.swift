import Foundation

/// 一次整理会话的持久化模型（计划书 5.2）。
/// 只保存确实用于恢复或展示的字段；所有持久化模型必须带版本字段。
struct ReviewSession: Codable, Equatable {
    static let currentSchemaVersion = 1

    var sessionID: UUID
    var schemaVersion: Int
    /// 当前浏览的照片资产标识（不是索引）
    var currentAssetID: String?
    /// 排序规则标识，恢复时校验排序是否一致
    var sortOrder: String
    var lastUpdatedAt: Date
    var lastReviewedAssetID: String?
    var completedReviewCount: Int

    init(sortOrder: String = SortOrders.newestFirst) {
        self.sessionID = UUID()
        self.schemaVersion = Self.currentSchemaVersion
        self.currentAssetID = nil
        self.sortOrder = sortOrder
        self.lastUpdatedAt = Date()
        self.lastReviewedAssetID = nil
        self.completedReviewCount = 0
    }
}

/// 排序规则。默认从新到旧（计划书 7.1）；工程初始化时固定，避免各处不一致。
enum SortOrders {
    static let newestFirst = "creationDate_desc"
    static let oldestFirst = "creationDate_asc"

    /// 没有拍摄时间的资产采用稳定次级排序：先按 mediaType，再按 localIdentifier 保证稳定。
    static func compare(_ a: PhotoItem, _ b: PhotoItem, newestFirst: Bool = true) -> Bool {
        switch (a.creationDate, b.creationDate) {
        case let (l?, r?):
            return newestFirst ? l > r : l < r
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        case (nil, nil):
            if a.mediaType.rawValue != b.mediaType.rawValue {
                return a.mediaType.rawValue < b.mediaType.rawValue
            }
            return a.localIdentifier < b.localIdentifier
        }
    }
}
