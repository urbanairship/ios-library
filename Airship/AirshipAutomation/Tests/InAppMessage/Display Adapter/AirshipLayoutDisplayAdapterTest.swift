/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomation
import AirshipCore

final class AirshipLayoutDisplayAdapterTest: XCTestCase {

    private let networkChecker: TestNetworkChecker = TestNetworkChecker()
    private let assets: TestCachedAssets = TestCachedAssets()

    func testIsReadyNoAssets() async throws {
        let message = InAppMessage(
            name: "no assets", 
            displayContent: .banner(.init())
        )
        XCTAssertTrue(message.urlInfos.isEmpty)

        let adapter = try makeAdapter(message)

        await networkChecker.setConnected(false)
        let isReady = await adapter.isReady
        XCTAssertTrue(isReady)
    }

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
        XCTAssertFalse(isReady)

        self.assets.cached.append(URL(string: "some-url")!)
        isReady = await adapter.isReady
        XCTAssertTrue(isReady)

        self.assets.cached.removeAll()
        isReady = await adapter.isReady
        XCTAssertFalse(isReady)

        await networkChecker.setConnected(true)
        isReady = await adapter.isReady
        XCTAssertTrue(isReady)
    }

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
        XCTAssertFalse(isReady)

        await networkChecker.setConnected(true)
        isReady = await adapter.isReady
        XCTAssertTrue(isReady)
    }

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
        XCTAssertFalse(isReady)

        await networkChecker.setConnected(true)
        isReady = await adapter.isReady
        XCTAssertTrue(isReady)
    }

    func testWaitForReadyNetwork() async throws {
        let message = InAppMessage(
            name: "video assets",
            displayContent: .html(
                .init(url: "some-url")
            )
        )
        let adapter = try makeAdapter(message)

        let waitingReady = expectation(description: "waiting is ready")
        let isReady = expectation(description: "is ready")

        Task {
            waitingReady.fulfill()
            await adapter.waitForReady()
            isReady.fulfill()
        }

        await self.fulfillment(of: [waitingReady])
        Task { [networkChecker] in
            await networkChecker.setConnected(true)
        }

        await self.fulfillment(of: [isReady])
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
