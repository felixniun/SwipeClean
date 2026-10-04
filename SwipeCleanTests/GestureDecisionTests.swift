import XCTest
@testable import SwipeClean

/// 手势方向识别（计划书 13.1 / 阶段 3 验收）。
/// 强制约定：左滑=下一张、右滑=上一张、上滑=标记，任何情况下不得互换。
final class GestureDecisionTests: XCTestCase {
    var coordinator = GestureCoordinator()

    // MARK: - 正常浏览（未放大）

    func testLeftSwipe_isNext() {
        let d = coordinator.decideEndGesture(translation: CGSize(width: -120, height: 5))
        XCTAssertEqual(d, .next, "左滑必须是下一张")
    }

    func testRightSwipe_isPrevious() {
        let d = coordinator.decideEndGesture(translation: CGSize(width: 120, height: 5))
        XCTAssertEqual(d, .previous, "右滑必须是上一张")
    }

    func testUpSwipe_isMarkForDeletion_notDelete() {
        let d = coordinator.decideEndGesture(translation: CGSize(width: 5, height: -140))
        XCTAssertEqual(d, .markForDeletion, "上滑只标记待删除，不触发真实删除")
    }

    func testDownSwipe_doesNothing() {
        let d = coordinator.decideEndGesture(translation: CGSize(width: 5, height: -(-140)))
        XCTAssertEqual(d, .none, "下滑不应触发任何操作")
    }

    func testSmallMovements_doNotTrigger() {
        XCTAssertEqual(coordinator.decideEndGesture(translation: CGSize(width: -30, height: 2)), .none)
        XCTAssertEqual(coordinator.decideEndGesture(translation: CGSize(width: 2, height: -60)), .none,
                       "轻微上移不得误触发标记")
    }

    func testDiagonalDrag_intentUnclear_cancels() {
        XCTAssertEqual(coordinator.decideEndGesture(translation: CGSize(width: 60, height: -60)), .none,
                       "斜向拖动意图不明时应取消识别，不猜测删除")
    }

    // MARK: - 放大状态（计划书 6.5）

    func testZoomedPan_horizontal_doesNotSwitch() {
        var c = coordinator
        c.zoomScale = 2
        XCTAssertEqual(c.decideEndGesture(translation: CGSize(width: -150, height: 0)), .none)
    }

    func testZoomedPan_upward_doesNotMark() {
        var c = coordinator
        c.zoomScale = 2
        XCTAssertEqual(c.decideEndGesture(translation: CGSize(width: 0, height: -200)), .none,
                       "放大状态下向上拖动不得标记删除（关键安全测试）")
    }

    // MARK: - 动画与提交锁定

    func testAnimationLock_blocksAllGestures() {
        var c = coordinator
        c.isAnimating = true
        XCTAssertEqual(c.decideEndGesture(translation: CGSize(width: -120, height: 0)), .none)
    }

    func testCommittingDeletion_blocksAllGestures() {
        var c = coordinator
        c.isCommittingDeletion = true
        XCTAssertEqual(c.decideEndGesture(translation: CGSize(width: 0, height: -200)), .none)
    }

    // MARK: - 阈值边界

    func testThresholdBoundary_horizontal() {
        XCTAssertEqual(coordinator.decideEndGesture(translation: CGSize(width: -79, height: 0)), .none)
        XCTAssertEqual(coordinator.decideEndGesture(translation: CGSize(width: -80, height: 0)), .next)
    }

    func testThresholdBoundary_vertical() {
        XCTAssertEqual(coordinator.decideEndGesture(translation: CGSize(width: 0, height: -99)), .none)
        XCTAssertEqual(coordinator.decideEndGesture(translation: CGSize(width: 0, height: -100)), .markForDeletion)
    }
}
