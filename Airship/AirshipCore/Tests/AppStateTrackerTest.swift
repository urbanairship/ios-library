/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class AppStateTrackerTest: XCTestCase {

    private let adapter = TestAppStateAdapter()
    private let notificationCenter = NotificationCenter()
    private var tracker: AppStateTracker!

    @MainActor
    override func setUp() async throws {
        self.tracker = AppStateTracker(
            adapter: adapter,
            notificationCenter: self.notificationCenter
        )
    }

    @MainActor
    func testDidBecomeActive() async throws {
        let expectations = [
            expectNotification(name: AppStateTracker.didBecomeActiveNotification)
        ]

        adapter.dispatchEvent(event: .didBecomeActive)

        await self.fulfillment(of: expectations, timeout: 1.0)
    }

    @MainActor
    func testWillEnterForeground() async throws {
        let expectations = [
            expectNotification(name: AppStateTracker.willEnterForegroundNotification)
        ]

        adapter.dispatchEvent(event: .willEnterForeground)

        await self.fulfillment(of: expectations, timeout: 1.0)
    }

    @MainActor
    func testDidEnterBackground() async throws {
        let expectations = [
            expectNotification(name: AppStateTracker.didEnterBackgroundNotification)
        ]

        adapter.dispatchEvent(event: .didEnterBackground)

        await self.fulfillment(of: expectations, timeout: 1.0)
    }

    @MainActor
    func testWillResignActive() async throws {
        let expectations = [
            expectNotification(name: AppStateTracker.willResignActiveNotification)
        ]

        adapter.dispatchEvent(event: .willResignActive)

        await self.fulfillment(of: expectations, timeout: 1.0)
    }


    @MainActor
    func testWillTerminate() async throws {
        let expectations = [
            expectNotification(name: AppStateTracker.willTerminateNotification)
        ]

        adapter.dispatchEvent(event: .willTerminate)

        await self.fulfillment(of: expectations, timeout: 1.0)
    }


    @MainActor
    func testTransitionToForeground() async throws {
        adapter.dispatchEvent(event: .didBecomeActive)

        let expectations = [
            expectNotification(name: AppStateTracker.didTransitionToForeground)
        ]

        adapter.dispatchEvent(event: .didEnterBackground)
        adapter.dispatchEvent(event: .didBecomeActive)

        await self.fulfillment(of: expectations, timeout: 1.0)
    }

    @MainActor
    func testTransitionToBackground() async throws {
        adapter.dispatchEvent(event: .didEnterBackground)

        let expectations = [
            expectNotification(name: AppStateTracker.didTransitionToForeground)
        ]

        adapter.dispatchEvent(event: .didBecomeActive)
        adapter.dispatchEvent(event: .didEnterBackground)

        await self.fulfillment(of: expectations, timeout: 1.0)
    }

    private func expectNotification(name: Notification.Name) -> XCTestExpectation {
        let expectation = self.expectation(description: "Notification received")
        self.notificationCenter.addObserver(
            forName: name,
            object: nil,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        return expectation
    }

}


final class TestAppStateAdapter: AppStateTrackerAdapter {
    @MainActor
    var state: AirshipCore.ApplicationState = .inactive
    @MainActor
    var eventHandlers: [@MainActor @Sendable (AppLifeCycleEvent) -> Void] = []

    @MainActor
    func watchAppLifeCycleEvents(
        eventHandler: @escaping @MainActor @Sendable (AirshipCore.AppLifeCycleEvent) -> Void) {
            eventHandlers.append(eventHandler)
    }

    @MainActor
    public func dispatchEvent(event: AppLifeCycleEvent) {
        self.eventHandlers.forEach { $0(event) }
    }
}


