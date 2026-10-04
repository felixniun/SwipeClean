import Foundation
import Photos
import UIKit

/// 图像加载服务（计划书 4.3 / 7.2–7.3）。
///
/// - 使用 PHCachingImageManager 管理缓存与预取。
/// - 按需加载：只加载当前 + 相邻预取，控制目标尺寸，绝不一次性加载全部原图。
/// - 加载失败不等于照片损坏；不得因加载失败自动标记删除。
enum ImageLoadState: Equatable {
    case idle
    case loading
    case loaded(UIImage)
    case failed(reason: String)
}

final class PhotoImageService {
    private let cachingManager = PHCachingImageManager()
    /// 正在进行的图像请求，按 assetID 索引，便于切换时取消。
    private var inFlightRequests: [String: PHImageRequestID] = [:]
    private let targetSize = CGSize(width: 2048, height: 2048)

    func loadFullImage(assetID: String) async -> ImageLoadState {
        cancelRequest(for: assetID)
        guard let asset = fetchAsset(assetID) else {
            return .failed(reason: "assetNotFound")
        }
        if asset.isInLocallyAvailableLibrary {
            return await request(asset: asset, assetID: assetID, allowNetwork: false)
        }
        return await request(asset: asset, assetID: assetID, allowNetwork: true)
    }

    private func request(asset: PHAsset, assetID: String, allowNetwork: Bool) async -> ImageLoadState {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = allowNetwork
        options.resizeMode = .exact
        options.isSynchronous = false

        let size = targetSize
        return await withCheckedContinuation { continuation in
            let requestID = cachingManager.requestImage(
                for: asset, targetSize: size, contentMode: .aspectFit, options: options
            ) { [weak self] image, info in
                guard let self else { return }
                self.inFlightRequests[assetID] = nil
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                if cancelled { return }
                if let image, !isDegraded {
                    continuation.resume(returning: ImageLoadState.loaded(image))
                } else if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(returning: .failed(reason: error.localizedDescription))
                } else if !isDegraded {
                    continuation.resume(returning: .failed(reason: "unknownImageError"))
                }
            }
            inFlightRequests[assetID] = requestID
        }
    }

    /// 相邻照片预取（计划书 7.2）。
    func prefetch(assetIDs: [String]) {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
        cachingManager.startCachingImages(
            for: assets as! [PHAsset],
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: nil
        )
    }

    func stopPrefetching(assetIDs: [String]) {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
        cachingManager.stopCachingImages(
            for: assets as! [PHAsset],
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: nil
        )
    }

    /// 缩略图（复核界面网格用），按需小尺寸请求。
    func loadThumbnail(assetID: String) async -> UIImage? {
        guard let asset = fetchAsset(assetID) else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        let size = CGSize(width: 300, height: 300)
        return await withCheckedContinuation { continuation in
            var resumed = false
            cachingManager.requestImage(
                for: asset, targetSize: size, contentMode: .aspectFill, options: options
            ) { image, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !degraded, !resumed {
                    resumed = true
                    continuation.resume(returning: image)
                }
            }
        }
    }

    func cancelRequest(for assetID: String) {
        if let id = inFlightRequests[assetID] {
            cachingManager.cancelImageRequest(id)
            inFlightRequests[assetID] = nil
        }
    }

    private func fetchAsset(_ id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }
}
