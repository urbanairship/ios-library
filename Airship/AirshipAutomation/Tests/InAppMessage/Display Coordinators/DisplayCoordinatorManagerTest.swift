/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable @_spi(AirshipInternal) import AirshipAutomation
import AirshipCore
@_spi(AirshipInternal) import AirshipBasement
@_spi(AirshipInternal) import AirshipScenes

@MainActor
struct DisplayCoordinatorManagerTest {

    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let manager: DisplayCoordinatorManager

    init() {
        manager = DisplayCoordinatorManager(dataStore: dataStore)
    }

    @Test
    func testDefaultAdapter() throws {
        let message = InAppMessage(name: "", displayContent: .custom(.string("")))
        let adapter = manager.displayCoordinator(message: message)
        #expect(adapter as? DefaultDisplayCoordinator != nil)
    }

    @Test
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
        #expect(adapter as? EmbeddedDisplayCoordinator != nil)
    }

    @Test
    func testStandardBehavior() throws {
        let message = InAppMessage(
            name: "",
            displayContent: .custom(.string("")),
            displayBehavior: .standard
        )

        let adapter = manager.displayCoordinator(message: message)
        #expect(adapter as? DefaultDisplayCoordinator != nil)
    }

    @Test
    func testImmediateBehavior() throws {
        let message = InAppMessage(
            name: "",
            displayContent: .custom(.string("")),
            displayBehavior: .immediate
        )

        let adapter = manager.displayCoordinator(message: message)
        #expect(adapter as? ImmediateDisplayCoordinator != nil)
    }

    @Test
    func testImmediateDisplayBlocksDefault() throws {
        let stateTracker = TestAppStateTracker()
        stateTracker.currentState = .active

        let activityTracker = DisplayActivityTracker()
        let immediate = ImmediateDisplayCoordinator(
            activityTracker: activityTracker,
            appStateTracker: stateTracker
        )
        let standard = DefaultDisplayCoordinator(
            displayInterval: 0.0,
            activityTracker: activityTracker,
            appStateTracker: stateTracker
        )

        let manager = DisplayCoordinatorManager(
            dataStore: dataStore,
            immediateCoordinator: immediate,
            defaultCoordinator: standard
        )
        _ = manager

        let message = InAppMessage(
            name: "",
            displayContent: .custom(.string("")),
            displayBehavior: .immediate
        )

        #expect(standard.isReady)

        immediate.messageWillDisplay(message)
        #expect(immediate.isReady)
        #expect(!standard.isReady)

        immediate.messageFinishedDisplaying(message)
        #expect(standard.isReady)
    }

    @Test
    func testEmbeddedDisplayDoesNotBlockDefault() throws {
        let stateTracker = TestAppStateTracker()
        stateTracker.currentState = .active

        let activityTracker = DisplayActivityTracker()
        let embedded = EmbeddedDisplayCoordinator(appStateTracker: stateTracker)
        let standard = DefaultDisplayCoordinator(
            displayInterval: 0.0,
            activityTracker: activityTracker,
            appStateTracker: stateTracker
        )

        let manager = DisplayCoordinatorManager(
            dataStore: dataStore,
            defaultCoordinator: standard,
            embeddedCoordinator: embedded
        )
        _ = manager

        let message = InAppMessage(
            name: "",
            displayContent: .custom(.string(""))
        )

        embedded.messageWillDisplay(message)
        #expect(standard.isReady)
    }

}
