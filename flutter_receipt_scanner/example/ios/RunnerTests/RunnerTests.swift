import Flutter
@testable import flutter_receipt_scanner_ios
import UIKit
import XCTest

class RunnerTests: XCTestCase {
    func testGeneratedNullDetectionPreservesOptionalPattern() {
        XCTAssertTrue(MessagesPigeonInternal.isNullish(nil))
        XCTAssertTrue(MessagesPigeonInternal.isNullish(NSNull()))
        XCTAssertFalse(MessagesPigeonInternal.isNullish(1))
    }

    func testNativeCallbackProtocolReturnsCapabilitiesOnMainThread() {
        let completed = expectation(description: "native capability callback")
        let api: ReceiptScannerApi = ReceiptScannerApiImpl()
        api.getOcrCapabilities { result in
            XCTAssertTrue(Thread.isMainThread)
            switch result {
            case let .success(capabilities):
                XCTAssertNotNil(capabilities.supportedLanguages)
                XCTAssertNil(capabilities.models)
            case let .failure(error):
                XCTFail("Capability query failed: \(error)")
            }
            completed.fulfill()
        }
        wait(for: [completed], timeout: 10)
    }

    func testNativeBatchCountsFailuresAndOverflowOnce() {
        var processed: [Int] = []
        let batch = PageBatch<Int>.process([0, 1, 2, 3], maxPages: 3) { page in
            processed.append(page)
            return page == 1 ? nil : page
        }
        XCTAssertEqual(processed, [0, 1, 2])
        XCTAssertEqual(batch.images, [0, 2])
        XCTAssertEqual(batch.discardedPageCount, 2)
    }

    func testOmissionDiagnosticSurvivesNativeWireRoundTrip() {
        let wire = ScanResultWire(status: .cancelled, images: [], rejectedImages: [], discardedPageCount: 2)
        let decoded = ScanResultWire.fromList(wire.toList())
        XCTAssertEqual(decoded?.status, .cancelled)
        XCTAssertEqual(decoded?.discardedPageCount, 2)
        XCTAssertEqual(decoded?.images.count, 0)
    }
}
