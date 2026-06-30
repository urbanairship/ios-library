/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable @_spi(AirshipInternal) import AirshipAutomation
import AirshipCore

struct AirshipLayoutDisplayAdapterTest {

    private let networkChecker: TestNetworkChecker = TestNetworkChecker()
    private let assets: TestCachedAssets = TestCachedAssets()

    @Test
    func testIsReadyNoAssets() async throws {
        let message = InAppMessage(
            name: "no assets", 
            displayContent: .banner(.init())
        )
        #expect(message.urlInfos.isEmpty)

        let adapter = try makeAdapter(message)

        await networkChecker.setConnected(false)
        let isReady = await adapter.isReady
        #expect(isReady)
    }

    @Test
    func testIsReadyImageAsset() async throws {
        let message = InAppMessage(
            name: "image assets",
            displayContent: .banner(
                .init(media: .init(url: "some-url", type: .image))
            )
        )

        let adapter = try makeAdapter(message)

        await networkChecker.setConnected(false)
        var isReady = await adapter.isReady
        #expect(!(isReady))

        self.assets.cached.append(URL(string: "some-url")!)
        isReady = await adapter.isReady
        #expect(isReady)

        self.assets.cached.removeAll()
        isReady = await adapter.isReady
        #expect(!(isReady))

        await networkChecker.setConnected(true)
        isReady = await adapter.isReady
        #expect(isReady)
    }

    @Test
    func testIsReadyVideoAsset() async throws {
        let message = InAppMessage(
            name: "video assets",
            displayContent: .banner(
                .init(media: .init(url: "some-url", type: .video))
            )
        )

        let adapter = try makeAdapter(message)

        // Caching is not checked for videos
        self.assets.cached.append(URL(string: "some-url")!)

        await networkChecker.setConnected(false)
        var isReady = await adapter.isReady
        #expect(!(isReady))

        await networkChecker.setConnected(true)
        isReady = await adapter.isReady
        #expect(isReady)
    }

    @Test
    func testIsReadyHTMLAsset() async throws {
        let message = InAppMessage(
            name: "video assets",
            displayContent: .html(
                .init(url: "some-url")
            )
        )

        let adapter = try makeAdapter(message)

        // Caching is not checked for html
        self.assets.cached.append(URL(string: "some-url")!)

        await networkChecker.setConnected(false)
        var isReady = await adapter.isReady
        #expect(!(isReady))

        await networkChecker.setConnected(true)
        isReady = await adapter.isReady
        #expect(isReady)
    }

    @Test
    func testWaitForReadyNetwork() async throws {
        let message = InAppMessage(
            name: "video assets",
            displayContent: .html(
                .init(url: "some-url")
            )
        )
        let adapter = try makeAdapter(message)

        await confirmation { isReady in
            let task = Task {
                await adapter.waitForReady()
                isReady()
            }

            Task { [networkChecker] in
                await networkChecker.setConnected(true)
            }

            await task.value
        }
    }

    private func makeAdapter(
        _ message: InAppMessage
    ) throws -> AirshipLayoutDisplayAdapter  {
        return try AirshipLayoutDisplayAdapter(
            message: message,
            priority: 0,
            assets: self.assets,
            networkChecker: self.networkChecker
        )
    }
}
