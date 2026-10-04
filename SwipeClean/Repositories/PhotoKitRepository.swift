import Foundation
import Photos

/// PhotoKit 实现（阶段 5）。仅 macOS/iOS 可编译。
///
/// - 默认排序：拍摄时间从新到旧；无拍摄时间的资产用稳定次级排序。
/// - 只查询图片类型；视频 / Live Photo 是否纳入 V1 待定。
/// - 不一次性请求原图；图像请求由 PhotoImageService 负责。
final class PhotoKitRepository: PhotoRepository {
    var onLibraryChange: (() -> Void)?

    private var changeObserver: NSObjectProtocol?

    init() {
        changeObserver = PHPhotoLibrary.shared().register(self)
    }

    deinit {
        if let observer = changeObserver {
            PHPhotoLibrary.shared().unregisterChangeObserver(observer)
        }
    }

    func fetchAssetIDs() async throws -> [String] {
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false),
            // 无拍摄时间资产的稳定次级排序
            NSSortDescriptor(key: "localIdentifier", ascending: true)
        ]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let result = PHAsset.fetchAssets(with: options)
        var ids: [String] = []
        ids.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            ids.append(asset.localIdentifier)
        }
        return ids
    }

    func fetchPhotoItem(assetID: String) async throws -> PhotoItem? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = result.firstObject else { return nil }
        let mediaType: PhotoMediaType
        switch asset.mediaSubtypes.contains(.photoLive) {
        case true: mediaType = .livePhoto
        case false: mediaType = .image
        }
        return PhotoItem(
            localIdentifier: asset.localIdentifier,
            mediaType: mediaType,
            creationDate: asset.creationDate,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight
        )
    }

    func assetsExist(ids: [String]) async -> Set<String> {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var found = Set<String>()
        result.enumerateObjects { asset, _, _ in
            found.insert(asset.localIdentifier)
        }
        return found
    }
}

extension PhotoKitRepository: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [weak self] in
            self?.onLibraryChange?()
        }
    }
}
