import XCTest
@testable import SwipeClean

/// 持久化与恢复（计划书 13.1 / 10.4–10.5）。
final class SessionPersistenceTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSaveAndLoad_roundTrip() throws {
        let store = LocalSessionStore(directory: tempDir)
        var session = ReviewSession()
        session.currentAssetID = "b"
        session.completedReviewCount = 3
        var queue = DeletionQueue()
        _ = queue.add("a", actionID: "act-1")
        let snapshot = SessionSnapshot(
            session: session, deletionQueue: queue,
            lastUndoableAction: ReviewAction(actionType: .markForDeletion, assetID: "a",
                                             previousAssetID: "a"),
            lastUpdatedAt: Date()
        )
        try store.save(snapshot)

        let loaded = try store.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.session.currentAssetID, "b")
        XCTAssertEqual(loaded?.session.completedReviewCount, 3)
        XCTAssertEqual(loaded?.deletionQueue.assetIDs, ["a"])
    }

    func testLoad_missingFile_returnsNil() throws {
        let store = LocalSessionStore(directory: tempDir)
        XCTAssertNil(try store.load())
    }

    func testLoad_corruptedData_throwsCorrupted() throws {
        let store = LocalSessionStore(directory: tempDir)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try Data("not json at all".utf8)
            .write(to: tempDir.appendingPathComponent("review-session.json"))
        XCTAssertThrowsError(try store.load()) { error in
            guard case SessionStoreError.corruptedData = error else {
                return XCTFail("损坏数据应抛 corruptedData，实际: \(error)")
            }
        }
    }

    func testFutureVersion_throwsCorrupted() throws {
        let store = LocalSessionStore(directory: tempDir)
        var session = ReviewSession()
        session.schemaVersion = 999
        let snapshot = SessionSnapshot(session: session, deletionQueue: DeletionQueue(),
                                       lastUndoableAction: nil, lastUpdatedAt: Date())
        _ = snapshot
        // 直接写一个带未知版本号的 JSON，绕过 store 的编码
        let dict: [String: Any] = [
            "version": 999,
            "session": ["sessionID": UUID().uuidString, "schemaVersion": 999,
                        "sortOrder": "creationDate_desc", "lastUpdatedAt": "2026-01-01T00:00:00Z",
                        "completedReviewCount": 0],
            "deletionQueue": ["queueVersion": 1, "assetIDs": []],
            "lastUpdatedAt": "2026-01-01T00:00:00Z"
        ]
        let data = try JSONSerialization.data(withJSONObject: dict)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try data.write(to: tempDir.appendingPathComponent("review-session.json"))
        XCTAssertThrowsError(try store.load())
    }

    // MARK: - 恢复协调（计划书 10.4）

    func testRecovery_filtersInvalidQueueAssets() throws {
        // 队列里的 "gone" 已不存在，恢复时应被剔除
        let store = LocalSessionStore(directory: tempDir)
        var queue = DeletionQueue()
        _ = queue.add("still-there", actionID: "act-1")
        _ = queue.add("gone", actionID: "act-2")
        var session = ReviewSession()
        session.currentAssetID = "still-there"
        try store.save(SessionSnapshot(session: session, deletionQueue: queue,
                                       lastUndoableAction: nil, lastUpdatedAt: Date()))

        let recovery = SessionRecovery(store: store)
        let visible = ["still-there", "x", "y"]
        guard case .recovered(let state) = try recovery.recover(currentVisibleAssetIDs: visible) else {
            return XCTFail("应成功恢复")
        }
        XCTAssertEqual(state.deletionQueue.assetIDs, ["still-there"])
        XCTAssertEqual(state.currentAssetID, "still-there")
    }

    func testRecovery_currentAssetDeleted_fallsBackToFirst() throws {
        let store = LocalSessionStore(directory: tempDir)
        var session = ReviewSession()
        session.currentAssetID = "deleted-asset"
        try store.save(SessionSnapshot(session: session, deletionQueue: DeletionQueue(),
                                       lastUndoableAction: nil, lastUpdatedAt: Date()))
        let recovery = SessionRecovery(store: store)
        guard case .recovered(let state) = try recovery.recover(currentVisibleAssetIDs: ["x", "y"]) else {
            return XCTFail("应成功恢复")
        }
        XCTAssertEqual(state.currentAssetID, "x", "当前资产失效时恢复到合理后继位置")
    }

    func testRecovery_noFile_freshStart() throws {
        let recovery = SessionRecovery(store: LocalSessionStore(directory: tempDir))
        if case .freshStart = try recovery.recover(currentVisibleAssetIDs: ["x"]) {} else {
            XCTFail("无历史会话应为 freshStart")
        }
    }
}
