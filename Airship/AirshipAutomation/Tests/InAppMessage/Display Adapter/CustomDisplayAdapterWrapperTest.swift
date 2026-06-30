/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable @_spi(AirshipInternal) import AirshipAutomation
import AirshipCore
import UIKit


struct CustomDisplayAdapterWrapperTest {
    private let testAdapter: TestCustomDisplayAdapter = TestCustomDisplayAdapter()
    private let wrapper: CustomDisplayAdapterWrapper

    init() {
        self.wrapper = CustomDisplayAdapterWrapper(adapter: testAdapter)
    }

    @Test
    func testIsReady() async {
        await self.testAdapter.setReady(true)
        var isReady = await self.wrapper.isReady
        #expect(isReady)

        await self.testAdapter.setReady(false)
        isReady = await self.wrapper.isReady
        #expect(!(isReady))
    }

    @Test
    func testWaitForReady() async {
        await self.testAdapter.setReady(false)

        await confirmation { isReady in
            let task = Task { [wrapper] in
                await wrapper.waitForReady()
                isReady()
            }

            Task { [testAdapter] in
                await testAdapter.setReady(true)
            }

            await task.value
        }
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
