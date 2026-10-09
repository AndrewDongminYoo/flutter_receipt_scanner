@testable import PageBatch
import XCTest

final class PageBatchTests: XCTestCase {
    func testMiddleFailurePreservesOrderAndReportsMissingPage() {
        let batch = PageBatch<Int>.process([0, 1, 2], maxPages: 3) { $0 == 1 ? nil : $0 }
        XCTAssertEqual(batch.images, [0, 2])
        XCTAssertEqual(batch.discardedPageCount, 1)
    }

    func testCapAndFailureCountEachPageOnceAndDoNotProcessOverflow() {
        var attempted: [Int] = []
        let batch = PageBatch<Int>.process([0, 1, 2, 3, 4], maxPages: 2) {
            attempted.append($0)
            return $0 == 1 ? nil : $0
        }
        XCTAssertEqual(attempted, [0, 1])
        XCTAssertEqual(batch.images, [0])
        XCTAssertEqual(batch.discardedPageCount, 4)
    }

    func testPrelimitedCameraInputCountsCapAndFailureOnce() {
        let batch = PageBatch<Int>.process([0, 1], maxPages: 2, selectedPageCount: 5) { $0 == 1 ? nil : $0 }
        XCTAssertEqual(batch.images, [0])
        XCTAssertEqual(batch.discardedPageCount, 4)
    }

    func testAllFailuresAreCounted() {
        let batch = PageBatch<Int>.process([0, 1, 2], maxPages: 3) { _ in nil }
        XCTAssertTrue(batch.images.isEmpty)
        XCTAssertEqual(batch.discardedPageCount, 3)
    }

    func testSuccessfulBatchHasNoMissingPages() {
        let batch = PageBatch<Int>.process([0, 1, 2], maxPages: 3) { $0 }
        XCTAssertEqual(batch.images, [0, 1, 2])
        XCTAssertEqual(batch.discardedPageCount, 0)
    }

    func testEmptyPickerCancellationHasNoMissingPages() {
        let batch = PageBatch<Int>(images: [], selectedPageCount: 0)
        XCTAssertEqual(batch.discardedPageCount, 0)
    }

    func testGalleryEditorSkipsAndFailuresAreCountedAsOmissions() {
        let batch = PageBatch<Int>(images: [0, 2], selectedPageCount: 3)
        XCTAssertEqual(batch.images, [0, 2])
        XCTAssertEqual(batch.discardedPageCount, 1)
        XCTAssertEqual(PageBatch<Int>(images: [], selectedPageCount: 3).discardedPageCount, 3)
    }
}
