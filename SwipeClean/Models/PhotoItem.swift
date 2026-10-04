import Foundation

/// 照片资产的轻量模型。`localIdentifier` 是连接 PhotoKit 资产与本地整理状态的唯一标识，
/// 严禁用数组索引识别资产（计划书 5.1 / 最终执行原则 4）。
struct PhotoItem: Identifiable, Hashable, Codable {
    let localIdentifier: String
    let mediaType: PhotoMediaType
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int

    var id: String { localIdentifier }
    var aspectRatio: Double {
        guard pixelHeight != 0 else { return 1 }
        return Double(pixelWidth) / Double(pixelHeight)
    }
}

/// V1 只处理静态图片；视频与 Live Photo 是否纳入 V1 待定（计划书 7.4）。
enum PhotoMediaType: String, Codable, Hashable {
    case image
    case video
    case livePhoto
}
