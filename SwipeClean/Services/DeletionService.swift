import Foundation
import Photos

/// 安全删除服务（计划书 4.3 / 8.3–8.6）。
///
/// 职责：接收“已确认”的资产标识 → 重新校验资产与授权 → 发起 PhotoKit 变更请求 →
/// 返回实际结果。绝不假定请求发出即删除成功；不经文件系统删除。
final class DeletionService {
    enum DeletionError: Error, Equatable {
        case permissionDenied
        case nothingToDelete
    }

    struct Result: Equatable {
        var deletedIDs: [String]
        var failedIDs: [String]
    }

    /// 删除前校验：返回仍然有效、可提交删除的资产子集（计划书 8.3）。
    func validate(assetIDs: [String]) async -> Set<String> {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
        var found = Set<String>()
        result.enumerateObjects { asset, _, _ in
            found.insert(asset.localIdentifier)
        }
        return found
    }

    func checkPermission() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw DeletionError.permissionDenied
        }
    }

    /// 通过 PhotoKit 变更请求执行批量删除。
    /// PhotoKit 会弹系统确认框；结果以 completionHandler 的实际回调为准。
    func delete(assetIDs: [String]) async throws -> Result {
        try await checkPermission()
        guard !assetIDs.isEmpty else { throw DeletionError.nothingToDelete }

        let valid = await validate(assetIDs: assetIDs)
        let toDelete = assetIDs.filter { valid.contains($0) }
        guard !toDelete.isEmpty else {
            return Result(deletedIDs: [], failedIDs: assetIDs)
        }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: toDelete, options: nil)
        var deleted: [String] = []
        var failed: [String] = []

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }

        // 提交后重新校验：仍存在视为失败，不凭请求成功假设删除结果（计划书 8.4）
        let remaining = await validate(assetIDs: toDelete)
        for id in toDelete {
            if remaining.contains(id) {
                failed.append(id)
            } else {
                deleted.append(id)
            }
        }
        return Result(deletedIDs: deleted, failedIDs: failed)
    }
}
