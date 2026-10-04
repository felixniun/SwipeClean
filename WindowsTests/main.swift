// Windows 逻辑测试入口：复刻 SwipeCleanTests 中与平台无关的关键用例。
// Windows 工具链没有 XCTest，这里用极简断言 harness。
// 在 macOS 上请使用 SwipeCleanTests（XCTest），以 XCTest 结果为准。
// 与核心源码编译为同一模块，故无需 import SwipeCleanCore。

import Foundation

var passed = 0
var failed = 0
var failures: [String] = []

func check(_ condition: Bool, _ name: String) {
    if condition {
        passed += 1
    } else {
        failed += 1
        failures.append(name)
        print("FAIL: \(name)")
    }
}

func expectEqual<T: Equatable>(_ a: T, _ b: T, _ name: String) {
    check(a == b, "\(name) (got \(a), want \(b))")
}

// MARK: - ReviewState 导航

func makeState() -> ReviewState { ReviewState(assetIDs: ["a", "b", "c", "d"]) }

var state = makeState()
expectEqual(state.goNext(), "b", "goNext moves forward")
expectEqual(state.currentIndex, 1, "goNext index")

state = makeState()
state.goNext(); state.goNext()
expectEqual(state.goPrevious(), "b", "goPrevious moves backward")

state = makeState()
check(state.goPrevious() == nil, "first: goPrevious does nothing")
expectEqual(state.currentAssetID, "a", "first: stays at first")

state = makeState()
state.goNext(); state.goNext(); state.goNext()
check(state.goNext() == nil, "last: goNext does nothing")
expectEqual(state.currentAssetID, "d", "last: stays at last")

state = makeState()
for _ in 0..<10 { _ = state.goNext() }
expectEqual(state.currentAssetID, "d", "end: no looping")

// MARK: - 上滑标记（只标记不删除）

state = makeState()
let action = state.markCurrentForDeletion()
expectEqual(action?.assetID, "a", "mark: action asset")
expectEqual(state.deletionQueue.assetIDs, ["a"], "mark: queued")
expectEqual(state.currentAssetID, "b", "mark: advances")

state = makeState()
_ = state.markCurrentForDeletion()
_ = state.goPrevious()
_ = state.markCurrentForDeletion()
expectEqual(state.deletionQueue.assetIDs.filter { $0 == "a" }.count, 1, "mark: no duplicate")
expectEqual(state.deletionCount, 1, "mark: queue count 1")

// MARK: - 撤销

state = makeState()
_ = state.markCurrentForDeletion()
expectEqual(state.undoLastMark(), "a", "undo: removes correct asset")
check(!state.deletionQueue.contains("a"), "undo: asset out of queue")

state = makeState()
_ = state.markCurrentForDeletion()
expectEqual(state.undoLastMark(), "a", "undo: first works")
check(state.undoLastMark() == nil, "undo: cannot repeat")

state = makeState()
_ = state.markCurrentForDeletion()
_ = state.undoLastMark()
expectEqual(state.currentAssetID, "a", "undo: restores position")

// MARK: - 资产失效协调

state = makeState()
_ = state.markCurrentForDeletion()
state.reconcile(withExisting: ["b", "c", "d"])
expectEqual(state.assetIDs, ["b", "c", "d"], "reconcile: prunes assets")
check(!state.deletionQueue.contains("a"), "reconcile: prunes queue")
expectEqual(state.currentAssetID, "b", "reconcile: current updated")

state = makeState()
_ = state.goNext()
state.reconcile(withExisting: ["a", "c", "d"])
expectEqual(state.currentAssetID, "c", "reconcile: finds successor")

// MARK: - 状态锁定与提交

state = makeState()
state.setMode(.committingDeletion)
check(state.goNext() == nil, "committing: navigation locked")
check(state.markCurrentForDeletion() == nil, "committing: mark locked")

state = makeState()
_ = state.markCurrentForDeletion() // a 入队，自动前进到 b
_ = state.markCurrentForDeletion() // b 入队，自动前进到 c
state.commitCompleted(successIDs: ["a"], failedIDs: ["b"])
expectEqual(state.deletionQueue.assetIDs, ["b"], "commit: only success removed")

// MARK: - 手势方向（强制约定）

var coord = GestureCoordinator()
expectEqual(coord.decideEndGesture(translation: CGSize(width: -120, height: 5)), .next, "left swipe = next")
expectEqual(coord.decideEndGesture(translation: CGSize(width: 120, height: 5)), .previous, "right swipe = previous")
expectEqual(coord.decideEndGesture(translation: CGSize(width: 5, height: -140)), .markForDeletion, "up swipe = mark (not delete)")
expectEqual(coord.decideEndGesture(translation: CGSize(width: 5, height: 140)), .none, "down swipe = nothing")
expectEqual(coord.decideEndGesture(translation: CGSize(width: -30, height: 2)), .none, "small horizontal ignored")
expectEqual(coord.decideEndGesture(translation: CGSize(width: 2, height: -60)), .none, "small upward ignored")
expectEqual(coord.decideEndGesture(translation: CGSize(width: 60, height: -60)), .none, "diagonal ambiguous ignored")

coord.zoomScale = 2
expectEqual(coord.decideEndGesture(translation: CGSize(width: -150, height: 0)), .none, "zoomed pan: no switch")
expectEqual(coord.decideEndGesture(translation: CGSize(width: 0, height: -200)), .none, "zoomed pan: no mark")

coord = GestureCoordinator()
coord.isAnimating = true
expectEqual(coord.decideEndGesture(translation: CGSize(width: -120, height: 0)), .none, "animating locked")

coord = GestureCoordinator()
coord.isCommittingDeletion = true
expectEqual(coord.decideEndGesture(translation: CGSize(width: 0, height: -200)), .none, "committing locked")

coord = GestureCoordinator()
expectEqual(coord.decideEndGesture(translation: CGSize(width: -79, height: 0)), .none, "h threshold below")
expectEqual(coord.decideEndGesture(translation: CGSize(width: -80, height: 0)), .next, "h threshold at")
expectEqual(coord.decideEndGesture(translation: CGSize(width: 0, height: -99)), .none, "v threshold below")
expectEqual(coord.decideEndGesture(translation: CGSize(width: 0, height: -100)), .markForDeletion, "v threshold at")

// MARK: - DeletionQueue

var queue = DeletionQueue()
check(queue.add("a", actionID: "act-1"), "queue: add a")
check(queue.add("b", actionID: "act-2"), "queue: add b")
expectEqual(queue.count, 2, "queue: count")

queue = DeletionQueue()
_ = queue.add("a", actionID: "act-1")
check(!queue.add("a", actionID: "act-2"), "queue: duplicate rejected")
expectEqual(queue.actionIDs["a"], "act-1", "queue: first actionID kept")

queue = DeletionQueue()
_ = queue.add("a", actionID: "act-1")
check(queue.remove("a"), "queue: remove works")
check(!queue.remove("a"), "queue: remove twice fails")

queue = DeletionQueue()
_ = queue.add("a", actionID: "act-1")
_ = queue.add("b", actionID: "act-2")
expectEqual(queue.retainValid(existing: Set(["a", "c"])), ["b"], "queue: retainValid reports")
expectEqual(queue.assetIDs, ["a"], "queue: retainValid prunes")

// MARK: - 持久化

let tempDir = NSTemporaryDirectory() + "/swipeclean-tests-\(UUID().uuidString)"
let dirURL = URL(fileURLWithPath: tempDir, isDirectory: true)
try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
let store = LocalSessionStore(directory: dirURL)

do {
    var session = ReviewSession()
    session.currentAssetID = "b"
    session.completedReviewCount = 3
    var q = DeletionQueue()
    _ = q.add("a", actionID: "act-1")
    try store.save(SessionSnapshot(
        session: session, deletionQueue: q,
        lastUndoableAction: ReviewAction(actionType: .markForDeletion, assetID: "a", previousAssetID: "a"),
        lastUpdatedAt: Date()))
    let loaded = try store.load()
    check(loaded != nil, "persistence: roundtrip loads")
    expectEqual(loaded?.session.currentAssetID, "b", "persistence: currentAssetID")
    expectEqual(loaded?.session.completedReviewCount, 3, "persistence: completedCount")
    expectEqual(loaded?.deletionQueue.assetIDs, ["a"], "persistence: queue")
} catch {
    check(false, "persistence: roundtrip threw \(error)")
}

// 损坏数据
do {
    try Data("not json at all".utf8).write(to: dirURL.appendingPathComponent("review-session.json"))
    do {
        _ = try store.load()
        check(false, "persistence: corrupted should throw")
    } catch {
        check(true, "persistence: corrupted throws")
    }
} catch {
    check(false, "persistence: corrupted setup failed")
}

// 未知版本
do {
    let dict: [String: Any] = [
        "version": 999,
        "session": ["sessionID": UUID().uuidString, "schemaVersion": 999,
                    "sortOrder": "creationDate_desc", "lastUpdatedAt": "2026-01-01T00:00:00Z",
                    "completedReviewCount": 0],
        "deletionQueue": ["queueVersion": 1, "assetIDs": []],
        "lastUpdatedAt": "2026-01-01T00:00:00Z"
    ]
    try JSONSerialization.data(withJSONObject: dict)
        .write(to: dirURL.appendingPathComponent("review-session.json"))
    do {
        _ = try store.load()
        check(false, "persistence: future version should throw")
    } catch {
        check(true, "persistence: future version throws")
    }
} catch {
    check(false, "persistence: future version setup failed")
}

// 恢复协调
do {
    var q = DeletionQueue()
    _ = q.add("still-there", actionID: "act-1")
    _ = q.add("gone", actionID: "act-2")
    var session = ReviewSession()
    session.currentAssetID = "still-there"
    try store.save(SessionSnapshot(session: session, deletionQueue: q,
                                   lastUndoableAction: nil, lastUpdatedAt: Date()))
    let recovery = SessionRecovery(store: store)
    guard case .recovered(let recovered) = try recovery.recover(currentVisibleAssetIDs: ["still-there", "x", "y"]) else {
        check(false, "recovery: should recover")
        recoveredNever()
    }
    expectEqual(recovered.deletionQueue.assetIDs, ["still-there"], "recovery: invalid queue pruned")
    expectEqual(recovered.currentAssetID, "still-there", "recovery: current restored")
} catch {
    check(false, "recovery: threw \(error)")
}

do {
    var session = ReviewSession()
    session.currentAssetID = "deleted-asset"
    try store.save(SessionSnapshot(session: session, deletionQueue: DeletionQueue(),
                                   lastUndoableAction: nil, lastUpdatedAt: Date()))
    let recovery = SessionRecovery(store: store)
    guard case .recovered(let recovered) = try recovery.recover(currentVisibleAssetIDs: ["x", "y"]) else {
        check(false, "recovery2: should recover")
        recoveredNever()
    }
    expectEqual(recovered.currentAssetID, "x", "recovery2: falls back to first")
} catch {
    check(false, "recovery2: threw \(error)")
}

do {
    let recovery = SessionRecovery(store: LocalSessionStore(directory: URL(fileURLWithPath: NSTemporaryDirectory() + "/swipeclean-empty-\(UUID().uuidString)")))
    if case .freshStart = try recovery.recover(currentVisibleAssetIDs: ["x"]) {
        check(true, "recovery3: freshStart")
    } else {
        check(false, "recovery3: expected freshStart")
    }
} catch {
    check(false, "recovery3: threw \(error)")
}

// MARK: - Mock 仓库（异步逻辑）

Task {
    let repo = MockPhotoRepository(count: 5)
    let ids = try? await repo.fetchAssetIDs()
    expectEqual(ids, ["mock-0", "mock-1", "mock-2", "mock-3", "mock-4"], "mock: sorted newest first")

    let item = try? await repo.fetchPhotoItem(assetID: "mock-2")
    expectEqual(item?.localIdentifier, "mock-2", "mock: found")
    let missing = try? await repo.fetchPhotoItem(assetID: "missing")
    check(missing == nil, "mock: not found returns nil")

    let existing = await repo.assetsExist(ids: ["mock-0", "missing-1", "mock-3"])
    expectEqual(existing, Set(["mock-0", "mock-3"]), "mock: assetsExist intersection")

    let a = PhotoItem(localIdentifier: "b", mediaType: .image, creationDate: nil, pixelWidth: 100, pixelHeight: 100)
    let b = PhotoItem(localIdentifier: "a", mediaType: .image, creationDate: nil, pixelWidth: 100, pixelHeight: 100)
    check(SortOrders.compare(b, a), "sort: stable secondary order")
    check(!SortOrders.compare(a, b), "sort: stable secondary order (reverse)")

    print("\n===== 结果: \(passed) 通过, \(failed) 失败 =====")
    if failed > 0 {
        for f in failures { print(" - \(f)") }
        exit(1)
    }
    exit(0)
}

func recoveredNever() -> Never { exit(2) }

// 阻塞主线程等待异步部分（测试进程）
RunLoop.main.run(until: Date().addingTimeInterval(10))
print("\n===== 结果: \(passed) 通过, \(failed) 失败（异步部分超时）=====")
exit(failed > 0 ? 1 : 0)
