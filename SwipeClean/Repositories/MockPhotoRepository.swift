import Foundation

/// 模拟照片数据源（阶段 2–4 使用）。仅用于开发与测试，不得把模拟数据测试说成真实照片库验证。
final class MockPhotoRepository: PhotoRepository {
    private var items: [PhotoItem]
    var onLibraryChange: (() -> Void)?

    init(count: Int = 20) {
        let now = Date()
        items = (0..<count).map { i in
            PhotoItem(
                localIdentifier: "mock-\(i)",
                mediaType: .image,
                creationDate: now.addingTimeInterval(Double(-i) * 3600),
                pixelWidth: i % 3 == 0 ? 3024 : 4032,
                pixelHeight: i % 3 == 0 ? 4032 : 3024
            )
        }
    }

    func fetchAssetIDs() async throws -> [String] {
        items
            .sorted { SortOrders.compare($0, $1) }
            .map(\.localIdentifier)
    }

    func fetchPhotoItem(assetID: String) async throws -> PhotoItem? {
        items.first { $0.localIdentifier == assetID }
    }

    func assetsExist(ids: [String]) async -> Set<String> {
        Set(ids).intersection(items.map(\.localIdentifier))
    }

    /// 模拟外部删除照片（测试照片库变化协调）。
    func simulateExternalDeletion(assetID: String) {
        items.removeAll { $0.localIdentifier == assetID }
        onLibraryChange?()
    }
}
