import Foundation

/// 会话持久化协议（计划书 4.3 / 10.1）。V1 用 Codable + 沙盒文件，不引入 Core Data。
protocol ReviewSessionStore {
    func save(_ snapshot: SessionSnapshot) throws
    func load() throws -> SessionSnapshot?
    func clear() throws
}

/// 持久化快照：仅保存恢复所需的最小状态（计划书 10.2）。
struct SessionSnapshot: Codable, Equatable {
    static let currentVersion = 1

    var version: Int = SessionSnapshot.currentVersion
    var session: ReviewSession
    var deletionQueue: DeletionQueue
    /// 最近一次可撤销操作（V1 只保留一条）
    var lastUndoableAction: ReviewAction?
    var lastUpdatedAt: Date
}

/// 写入失败的错误类型（计划书 5.5.5）。
enum SessionStoreError: Error {
    case directoryUnavailable
    case encodingFailed(Error)
    case writeFailed(Error)
    case corruptedData
}

/// 本地文件实现：JSON 编码写入应用沙盒 Documents 目录。
final class LocalSessionStore: ReviewSessionStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("review-session.json")
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func save(_ snapshot: SessionSnapshot) throws {
        do {
            let data = try encoder.encode(snapshot)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            // 原子写入：减少中断导致的损坏（计划书 10.5）
            try data.write(to: fileURL, options: .atomic)
        } catch let error as EncodingError {
            throw SessionStoreError.encodingFailed(error)
        } catch {
            throw SessionStoreError.writeFailed(error)
        }
    }

    func load() throws -> SessionSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try decoder.decode(SessionSnapshot.self, from: data)
            // 版本校验（计划书 10.4.2）：不认识的数据版本按损坏处理
            guard snapshot.version == SessionSnapshot.currentVersion else {
                throw SessionStoreError.corruptedData
            }
            return snapshot
        } catch let error as SessionStoreError {
            throw error
        } catch is DecodingError {
            throw SessionStoreError.corruptedData
        } catch {
            throw SessionStoreError.writeFailed(error)
        }
    }

    func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
