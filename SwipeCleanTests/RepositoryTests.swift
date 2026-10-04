import XCTest
@testable import SwipeClean

/// 模拟仓库行为（计划书 13.1 RepositoryTests）。
/// 注意：这是模拟数据测试，不代表真实照片库验证（计划书 15.3.7）。
final class RepositoryTests: XCTestCase {
    func testFetchAssetIDs_sortedNewestFirst() async throws {
        let repo = MockPhotoRepository(count: 5)
        let ids = try await repo.fetchAssetIDs()
        XCTAssertEqual(ids, ["mock-0", "mock-1", "mock-2", "mock-3", "mock-4"])
    }

    func testFetchPhotoItem_found() async throws {
        let repo = MockPhotoRepository()
        let item = try await repo.fetchPhotoItem(assetID: "mock-2")
        XCTAssertEqual(item?.localIdentifier, "mock-2")
    }

    func testFetchPhotoItem_notFound() async throws {
        let repo = MockPhotoRepository()
        let item = try await repo.fetchPhotoItem(assetID: "missing")
        XCTAssertNil(item)
    }

    func testAssetsExist_intersection() async {
        let repo = MockPhotoRepository()
        let existing = await repo.assetsExist(ids: ["mock-0", "missing-1", "mock-3"])
        XCTAssertEqual(existing, ["mock-0", "mock-3"])
    }

    func testExternalDeletion_notifiesObserver() async {
        let repo = MockPhotoRepository()
        let expectation = expectation(description: "library change notified")
        repo.onLibraryChange = { expectation.fulfill() }
        await MainActor.run {
            repo.simulateExternalDeletion(assetID: "mock-1")
        }
        await fulfillment(of: [expectation], timeout: 2)
        let existing = await repo.assetsExist(ids: ["mock-1"])
        XCTAssertTrue(existing.isEmpty)
    }

    func testSortOrders_noCreationDate_stableSecondaryOrder() {
        let a = PhotoItem(localIdentifier: "b", mediaType: .image, creationDate: nil,
                          pixelWidth: 100, pixelHeight: 100)
        let b = PhotoItem(localIdentifier: "a", mediaType: .image, creationDate: nil,
                          pixelWidth: 100, pixelHeight: 100)
        XCTAssertTrue(SortOrders.compare(b, a), "无拍摄时间时按 localIdentifier 稳定排序")
        XCTAssertFalse(SortOrders.compare(a, b))
    }
}
