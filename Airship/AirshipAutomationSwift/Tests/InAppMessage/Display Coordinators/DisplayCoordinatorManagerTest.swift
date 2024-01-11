/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomationSwift
import AirshipCore

final class DisplayCoordinatorManagerTest: XCTestCase {

    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private var manager: DisplayCoordinatorManager!
    
    @MainActor
    override func setUp() async throws {
        manager = DisplayCoordinatorManager(dataStore: dataStore)
    }

    func testDefaultAdapter() throws {
        let message = InAppMessage(name: "", displayContent: .custom(.string("")))
        let adapter = manager.displayCoordinator(message: message)
        XCTAssertNotNil(adapter as? DefaultDisplayCoordinator)
    }

    func testDefaultAdapterEmbedded() throws {
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

        let message = InAppMessage(
            name: "",
            displayContent: .airshipLayout(
                try! JSONDecoder().decode(AirshipLayout.self, from: airshipLayout.data(using: .utf8)!)
            )
        )
        let adapter = manager.displayCoordinator(message: message)
        XCTAssertNotNil(adapter as? ImmediateDisplayCoordinator)
    }

    func testStandardBehavior() throws {
        let message = InAppMessage(
            name: "",
            displayContent: .custom(.string("")),
            displayBehavior: .standard
        )

        let adapter = manager.displayCoordinator(message: message)
        XCTAssertNotNil(adapter as? DefaultDisplayCoordinator)
    }

    func testImmediateBehavior() throws {
        let message = InAppMessage(
            name: "",
            displayContent: .custom(.string("")),
            displayBehavior: .immediate
        )

        let adapter = manager.displayCoordinator(message: message)
        XCTAssertNotNil(adapter as? ImmediateDisplayCoordinator)
    }

}
