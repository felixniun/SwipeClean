import XCTest
@testable import SwipeClean

/// 待删除队列（计划书 13.1 / 阶段 4 验收）。
final class DeletionQueueTests: XCTestCase {
    func testAdd_andCount() {
        var queue = DeletionQueue()
        XCTAssertTrue(queue.add("a", actionID: "act-1"))
        XCTAssertTrue(queue.add("b", actionID: "act-2"))
        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(queue.assetIDs, ["a", "b"])
    }

    func testDuplicateAdd_isRejected() {
        var queue = DeletionQueue()
        XCTAssertTrue(queue.add("a", actionID: "act-1"))
        XCTAssertFalse(queue.add("a", actionID: "act-2"), "重复标记不得产生多个待删除项")
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.actionIDs["a"], "act-1", "保留首次标记的 actionID")
    }

    func testRemove_returnsWhetherRemoved() {
        var queue = DeletionQueue()
        _ = queue.add("a", actionID: "act-1")
        XCTAssertTrue(queue.remove("a"))
        XCTAssertFalse(queue.remove("a"), "同一操作不得被重复撤销")
        XCTAssertEqual(queue.count, 0)
    }

    func testRetainValid_removesMissingAndReports() {
        var queue = DeletionQueue()
        _ = queue.add("a", actionID: "act-1")
        _ = queue.add("b", actionID: "act-2")
        let removed = queue.retainValid(existing: ["a", "c"])
        XCTAssertEqual(removed, ["b"])
        XCTAssertEqual(queue.assetIDs, ["a"])
    }

    func testContains_andEmpty() {
        var queue = DeletionQueue()
        XCTAssertFalse(queue.contains("a"))
        _ = queue.add("a", actionID: "act-1")
        XCTAssertTrue(queue.contains("a"))
        queue.removeAll()
        XCTAssertTrue(queue.isEmpty)
    }
}
