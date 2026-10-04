import Foundation

/// 统一照片数据接口（计划书 4.3）。真实实现走 PhotoKit，测试实现用模拟数据。
protocol PhotoRepository {
    /// 获取可见照片资产标识（按会话排序规则）。
    func fetchAssetIDs() async throws -> [String]
    /// 获取资产元数据。
    func fetchPhotoItem(assetID: String) async throws -> PhotoItem?
    /// 查询资产是否仍存在（删除前校验 / 恢复时校验）。
    func assetsExist(ids: [String]) async -> Set<String>
    /// 观察照片库变化。
    var onLibraryChange: (() -> Void)? { get set }
}
