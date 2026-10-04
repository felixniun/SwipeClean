import XCTest
@testable import SwipeClean

/// 导航方向与边界（计划书 13.1 / 阶段 2 验收）。
/// 强制约定：左滑=下一张由 GestureDecision 覆盖，这里测 ReviewState 的导航语义。
final class ReviewStateTests: XCTestCase {
    func makeState() -> ReviewState {
        ReviewState(assetIDs: ["a", "b", "c", "d"])
    }

    func testGoNext_movesForward() {
        var state = makeState()
        XCTAssertEqual(state.goNext(), "b")
        XCTAssertEqual(state.currentIndex, 1)
    }

    func testGoPrevious_movesBackward() {
        var state = makeState()
        state.goNext(); state.goNext()
        XCTAssertEqual(state.goPrevious(), "b")
    }

    func testBoundary_firstPreviousDoesNothing() {
        var state = makeState()
        XCTAssertNil(state.goPrevious())
        XCTAssertEqual(state.currentAssetID, "a")
    }

    func testBoundary_lastNextDoesNothing() {
        var state = makeState()
        state.goNext(); state.goNext(); state.goNext()
        XCTAssertNil(state.goNext())
        XCTAssertEqual(state.currentAssetID, "d")
    }

    func testRepeatedNavigationAtEnd_doesNotLoop() {
        var state = makeState()
        for _ in 0..<10 { _ = state.goNext() }
        XCTAssertEqual(state.currentAssetID, "d")
    }

    // MARK: - 上滑标记（只标记，不删除）

    func testMarkCurrent_addsToQueueAndAdvances() {
        var state = makeState()
        let action = state.markCurrentForDeletion()
        XCTAssertEqual(action?.assetID, "a")
        XCTAssertEqual(state.deletionQueue.assetIDs, ["a"])
        XCTAssertEqual(state.currentAssetID, "b")
    }

    func testMarkCurrent_duplicateMark_noDuplicateQueueEntry() {
        var state = makeState()
        _ = state.markCurrentForDeletion()
        // 回到 a 再标记一次
        _ = state.goPrevious()
        _ = state.markCurrentForDeletion()
        XCTAssertEqual(state.deletionQueue.assetIDs.filter { $0 == "a" }.count, 1)
        XCTAssertEqual(state.deletionCount, 1)
    }

    // MARK: - 撤销

    func testUndoLastMark_removesCorrectAsset() {
        var state = makeState()
        _ = state.markCurrentForDeletion() // a 入队
        XCTAssertEqual(state.undoLastMark(), "a")
        XCTAssertFalse(state.deletionQueue.contains("a"))
        XCTAssertEqual(state.deletionCount, 0)
    }

    func testUndoLastMark_cannotBeRepeated() {
        var state = makeState()
        _ = state.markCurrentForDeletion()
        XCTAssertEqual(state.undoLastMark(), "a")
        XCTAssertNil(state.undoLastMark())
        XCTAssertFalse(state.deletionQueue.contains("a"))
    }

    func testUndo_restoresPosition_whenAssetStillVisible() {
        var state = makeState()
        _ = state.markCurrentForDeletion() // a，前进到 b
        _ = state.undoLastMark()
        XCTAssertEqual(state.currentAssetID, "a")
    }

    // MARK: - 资产失效协调

    func testReconcile_removesInvalidAssetsAndQueueEntries() {
        var state = makeState()
        _ = state.markCurrentForDeletion() // a 入队
        state.reconcile(withExisting: ["b", "c", "d"])
        XCTAssertEqual(state.assetIDs, ["b", "c", "d"])
        XCTAssertFalse(state.deletionQueue.contains("a"))
        XCTAssertEqual(state.currentAssetID, "b")
    }

    func testReconcile_currentAssetDeleted_findsSuccessor() {
        var state = makeState()
        _ = state.goNext() // b
        state.reconcile(withExisting: ["a", "c", "d"])
        XCTAssertEqual(state.currentAssetID, "c")
    }

    // MARK: - 状态锁定

    func testNavigationLocked_whileCommittingDeletion() {
        var state = makeState()
        state.setMode(.committingDeletion)
        XCTAssertNil(state.goNext())
        XCTAssertNil(state.goPrevious())
        XCTAssertNil(state.markCurrentForDeletion())
    }

    func testCommitCompleted_removesOnlySuccessfulAssets() {
        var state = makeState()
        _ = state.markCurrentForDeletion() // a 入队，自动前进到 b
        _ = state.markCurrentForDeletion() // b 入队，自动前进到 c
        state.commitCompleted(successIDs: ["a"], failedIDs: ["b"])
        XCTAssertEqual(state.deletionQueue.assetIDs, ["b"])
        if case let .completed(success, failed) = state.commitState {
            XCTAssertEqual(success, ["a"])
            XCTAssertEqual(failed, ["b"])
        } else {
            XCTFail("应为 completed 状态")
        }
    }
}
