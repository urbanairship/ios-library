/* Copyright Airship and Contributors */

import Testing
import Foundation

@_spi(AirshipInternal) @testable import AirshipBasement

@MainActor
struct AppStateTrackerTest {

    private let adapter = TestAppStateAdapter()
    private let notificationCenter = NotificationCenter()
    private let tracker: AppStateTracker

    init() {
        self.tracker = AppStateTracker(
            adapter: adapter,
            notificationCenter: notificationCenter
        )
    }

    @Test
    func testDidBecomeActive() async {
        await expectNotification(AppStateTracker.didBecomeActiveNotification) {
            adapter.dispatchEvent(event: .didBecomeActive)
        }
    }

    @Test
    func testWillEnterForeground() async {
        await expectNotification(AppStateTracker.willEnterForegroundNotification) {
            adapter.dispatchEvent(event: .willEnterForeground)
        }
    }

    @Test
    func testDidEnterBackground() async {
        await expectNotification(AppStateTracker.didEnterBackgroundNotification) {
            adapter.dispatchEvent(event: .didEnterBackground)
        }
    }

    @Test
    func testWillResignActive() async {
        await expectNotification(AppStateTracker.willResignActiveNotification) {
            adapter.dispatchEvent(event: .willResignActive)
        }
    }

    @Test
    func testWillTerminate() async {
        await expectNotification(AppStateTracker.willTerminateNotification) {
            adapter.dispatchEvent(event: .willTerminate)
        }
    }

    @Test
    func testTransitionToForeground() async {
        adapter.dispatchEvent(event: .didBecomeActive)

        await expectNotification(AppStateTracker.didTransitionToForeground) {
            adapter.dispatchEvent(event: .didEnterBackground)
            adapter.dispatchEvent(event: .didBecomeActive)
        }
    }

    @Test
    func testTransitionToBackground() async {
        adapter.dispatchEvent(event: .didEnterBackground)

        await expectNotification(AppStateTracker.didTransitionToBackground) {
            adapter.dispatchEvent(event: .didBecomeActive)
            adapter.dispatchEvent(event: .didEnterBackground)
        }
    }

    /// Confirms `name` is posted to the tracker's notification center while `action` runs.
    private func expectNotification(
        _ name: Notification.Name,
        during action: () -> Void
    ) async {
        await confirmation("Received \(name.rawValue)") { received in
            let observer = notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: nil
            ) { _ in
                received()
            }
            action()
            notificationCenter.removeObserver(observer)
        }
    }
}


final class TestAppStateAdapter: AppStateTrackerAdapter {
    @MainActor
    var state: ApplicationState = .inactive
    @MainActor
    var eventHandlers: [@MainActor @Sendable (AppLifeCycleEvent) -> Void] = []

    @MainActor
    func watchAppLifeCycleEvents(
        eventHandler: @escaping @MainActor @Sendable (AppLifeCycleEvent) -> Void) {
            eventHandlers.append(eventHandler)
    }

    @MainActor
    public func dispatchEvent(event: AppLifeCycleEvent) {
        self.eventHandlers.forEach { $0(event) }
    }
}
