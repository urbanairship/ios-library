/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomation
import AirshipCore


final class CustomDisplayAdapterWrapperTest: XCTestCase {
    private let testAdapter: TestCustomDisplayAdapter = TestCustomDisplayAdapter()
    private var wrapper: CustomDisplayAdapterWrapper!

    override func setUp() async throws {
        self.wrapper = CustomDisplayAdapterWrapper(adapter: testAdapter)
    }

    func testIsReady() async {
        await self.testAdapter.setReady(true)
        var isReady = await self.wrapper.isReady
        XCTAssertTrue(isReady)

        await self.testAdapter.setReady(false)
        isReady = await self.wrapper.isReady
        XCTAssertFalse(isReady)
    }

    func testWaitForReady() async {
        await self.testAdapter.setReady(false)

        let waitingReady = expectation(description: "waiting is ready")
        let isReady = expectation(description: "is ready")
        Task { [wrapper] in
            waitingReady.fulfill()
            await wrapper!.waitForReady()
            isReady.fulfill()
        }

        await self.fulfillment(of: [waitingReady])
        Task { [testAdapter] in
            await testAdapter.setReady(true)
        }

        await self.fulfillment(of: [isReady])
    }
}


fileprivate final class TestCustomDisplayAdapter: CustomDisplayAdapter {

    private let _isReady: AirshipMainActorValue<Bool> = AirshipMainActorValue(false)

    @MainActor
    func setReady(_ ready: Bool) {
        _isReady.set(ready)
    }

    @MainActor
    var isReady: Bool { return _isReady.value }

    @MainActor
    func waitForReady() async {
        for await isReady  in _isReady.updates {
            if (isReady) {
                return
            }
        }
    }

    func display(scene: UIWindowScene) async -> CustomDisplayResolution {
        // Cant test this due ot the scene
        return .userDismissed
    }
}
