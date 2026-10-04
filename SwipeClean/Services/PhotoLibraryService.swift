import Foundation
import Photos

/// 照片授权服务（计划书 9.1–9.3）。
enum PhotoPermissionState: Equatable {
    case notDetermined
    case authorized
    case limited
    case deniedOrRestricted
}

final class PhotoLibraryService {
    func currentState() -> PhotoPermissionState {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied, .restricted: return .deniedOrRestricted
        @unknown default: return .deniedOrRestricted
        }
    }

    func requestAccess() async -> PhotoPermissionState {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        switch status {
        case .authorized: return .authorized
        case .limited: return .limited
        case .notDetermined, .denied, .restricted: return .deniedOrRestricted
        @unknown default: return .deniedOrRestricted
        }
    }
}
