/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomation
import AirshipCore

final class DisplayAdapterFactoryTest: XCTestCase {

    private let factory: DisplayAdapterFactory = DisplayAdapterFactory()
    private let assets: TestCachedAssets = TestCachedAssets()

    func testAirshipAdapter() async throws {
        try await verifyAirshipAdapter(
            displayContent: .modal(.init(buttons: [], template: .headerBodyMedia))
        )

        try await verifyAirshipAdapter(
            displayContent: .banner(.init(buttons: [], template: .mediaLeft))
        )

        try await verifyAirshipAdapter(
            displayContent: .fullscreen(.init(buttons: [], template: .headerBodyMedia))
        )

        try await verifyAirshipAdapter(
            displayContent: .html(.init(url: "some url"))
        )

        let airshipLayout = """
        {
          "version":1,
          "presentation":{
             "type":"embedded",
             "embedded_id":"home_banner",
             "default_placement":{
                "size":{
                   "width":"50%",
                   "height":"50%"
                }
             }
          },
          "view":{
             "type":"container",
             "items":[]
          }
        }
        """

        try await verifyAirshipAdapter(
            displayContent: .airshipLayout(
                try! JSONDecoder().decode(AirshipLayout.self, from: airshipLayout.data(using: .utf8)!)
            )
        )
    }

    func testCustomAdapters() async throws {
        try await verifyCustomAdapter(
            forType: .modal,
            displayContent: .modal(.init(buttons: [], template: .headerBodyMedia))
        )

        try await verifyCustomAdapter(
            forType: .banner,
            displayContent: .banner(.init(buttons: [], template: .mediaLeft))
        )

        try await verifyCustomAdapter(
            forType: .fullscreen,
            displayContent: .fullscreen(.init(buttons: [], template: .headerBodyMedia))
        )

        try await verifyCustomAdapter(
            forType: .html,
            displayContent: .html(.init(url: "some url"))
        )

        try await verifyCustomAdapter(
            forType: .custom,
            displayContent: .custom(.string("custom"))
        )
    }

    func testCustomThrowsNoAdapter() async throws {
        let message = InAppMessage(
            name: "Airship layout",
            displayContent: .custom(.string("custom"))
        )

        do {
            let _ = try await factory.makeAdapter(
                args: DisplayAdapterArgs(
                    message: message, assets: assets, _actionRunner: TestInAppActionRunner()
                )
            )
            XCTFail("Wrong adapter")
        } catch {}
    }


    private func verifyAirshipAdapter(
        displayContent: InAppMessageDisplayContent,
        line: UInt = #line
    ) async throws {
        let message = InAppMessage(
            name: "",
            displayContent: displayContent
        )

        let adapter = try await factory.makeAdapter(
            args: DisplayAdapterArgs(
                message: message, assets: assets, _actionRunner: TestInAppActionRunner()
            )
        )

        guard adapter as? AirshipLayoutDisplayAdapter != nil else {
            XCTFail("Wrong adapter", line: line)
            return
        }
    }

    private func verifyCustomAdapter(
        forType type: CustomDisplayAdapterType,
        displayContent: InAppMessageDisplayContent,
        line: UInt = #line
    ) async throws {
        let message = InAppMessage(
            name: "",
            displayContent: displayContent
        )

        let assets = self.assets
        let adapter = TestCustomDisplayAdapter()
        await factory.setAdapterFactoryBlock(forType: type) { args in
            guard
                let incomingAssets = args.assets as? TestCachedAssets,
                incomingAssets === assets,
                message == args.message
            else {
                XCTFail("Invalid args", line: line)
                return nil
            }

            return adapter
        }

        let result = try await factory.makeAdapter(
            args: DisplayAdapterArgs(
                message: message, assets: assets, _actionRunner: TestInAppActionRunner()
            )
        )

        guard
            let wrappedAdapter = result as? CustomDisplayAdapterWrapper,
            let unwrapped = wrappedAdapter.adapter as? TestCustomDisplayAdapter,
            unwrapped === adapter
        else {
            XCTFail("Wrong adapter", line: line)
            return
        }
    }
}

fileprivate final class TestCustomDisplayAdapter: CustomDisplayAdapter, Sendable {
    @MainActor
    var isReady: Bool { return true }

    func waitForReady() async {

    }
    
    @MainActor
    func display(scene: UIWindowScene) async -> CustomDisplayResolution {
        return .timedOut
    }

}
