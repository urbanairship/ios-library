/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipCore

@Suite("Deep Link Handler Tests")
struct DeepLinkHandlerTest {

    // MARK: - Test Helpers

    actor TestDeepLinkDelegate: DeepLinkDelegate {
        private(set) var receivedDeepLink: URL?

        func receivedDeepLink(_ deepLink: URL) async {
            self.receivedDeepLink = deepLink
        }

        func reset() {
            self.receivedDeepLink = nil
        }
    }

    final class TestComponent: AirshipComponent, @unchecked Sendable {
        var onDeepLink: ((URL) -> Bool)?
        private(set) var deepLink: URL?

        func deepLink(_ deepLink: URL) -> Bool {
            self.deepLink = deepLink
            return onDeepLink?(deepLink) ?? false
        }

        func reset() {
            self.deepLink = nil
        }
    }

    // MARK: - Tests

    @Test("Handler set - delegate not called")
    @MainActor
    func testHandlerPreventsDelegate() async throws {
        let airshipInstance = TestAirshipInstance()
        airshipInstance.makeShared()
        defer { TestAirshipInstance.clearShared() }

        let delegate = TestDeepLinkDelegate()
        let component = TestComponent()
        component.onDeepLink = { _ in
            Issue.record("Component should not be called for non-uairship URLs")
            return false
        }

        var handlerCalled = false
        let testURL = URL(string: "myapp://deep-link/test")!

        airshipInstance.deepLinkHandler = { url in
            #expect(url == testURL)
            handlerCalled = true
        }

        airshipInstance.deepLinkDelegate = delegate
        airshipInstance.components = [component]

        let result = await Airship.shared.deepLink(testURL)

        #expect(result == true)
        #expect(handlerCalled == true)
        #expect(component.deepLink == nil)
        await #expect(delegate.receivedDeepLink == nil)
    }

    @Test("No handler - uses delegate")
    @MainActor
    func testNoHandlerUsesDelegate() async throws {
        let airshipInstance = TestAirshipInstance()
        airshipInstance.makeShared()
        defer { TestAirshipInstance.clearShared() }

        let delegate = TestDeepLinkDelegate()
        let testURL = URL(string: "myapp://deep-link/direct")!

        airshipInstance.deepLinkDelegate = delegate
        airshipInstance.components = []

        let result = await Airship.shared.deepLink(testURL)

        #expect(result == true)
        await #expect(delegate.receivedDeepLink == testURL)
    }

    @Test("Handler without delegate")
    @MainActor
    func testHandlerWithoutDelegate() async throws {
        let airshipInstance = TestAirshipInstance()
        airshipInstance.makeShared()
        defer { TestAirshipInstance.clearShared() }

        var handlerCalled = false
        let testURL = URL(string: "myapp://deep-link/no-delegate")!

        airshipInstance.deepLinkHandler = { url in
            #expect(url == testURL)
            handlerCalled = true
        }

        airshipInstance.components = []

        let result = await Airship.shared.deepLink(testURL)

        #expect(result == true)
        #expect(handlerCalled == true)
    }

    @Test("No handler and no delegate")
    @MainActor
    func testNoHandlerNoDelegate() async throws {
        let airshipInstance = TestAirshipInstance()
        airshipInstance.makeShared()
        defer { TestAirshipInstance.clearShared() }

        let testURL = URL(string: "myapp://deep-link/unhandled")!
        airshipInstance.components = []

        let result = await Airship.shared.deepLink(testURL)

        #expect(result == false)
    }

    @Test("UAirship scheme - handler intercepts")
    @MainActor
    func testUAirshipSchemeHandler() async throws {
        let airshipInstance = TestAirshipInstance()
        airshipInstance.makeShared()
        defer { TestAirshipInstance.clearShared() }

        let delegate = TestDeepLinkDelegate()
        let component = TestComponent()
        component.onDeepLink = { _ in false }

        var handlerCalled = false
        let testURL = URL(string: "uairship://custom-action")!

        airshipInstance.deepLinkHandler = { url in
            #expect(url == testURL)
            handlerCalled = true
        }

        airshipInstance.deepLinkDelegate = delegate
        airshipInstance.components = [component]

        let result = await Airship.shared.deepLink(testURL)

        #expect(result == true)
        #expect(handlerCalled == true)
        #expect(component.deepLink == testURL)
        await #expect(delegate.receivedDeepLink == nil) // Handler prevents delegate
    }

    @Test(
        "Different URL schemes",
        arguments: [
            "https://example.com/deep",
            "myapp://home",
            "custom://action/test",
            "uairship://test"
        ]
    )
    @MainActor
    func testDifferentURLSchemes(urlString: String) async throws {
        let airshipInstance = TestAirshipInstance()
        airshipInstance.makeShared()
        defer { TestAirshipInstance.clearShared() }

        let testURL = URL(string: urlString)!
        var handlerCalled = false

        airshipInstance.deepLinkHandler = { url in
            #expect(url == testURL)
            handlerCalled = true
        }

        airshipInstance.components = []

        let result = await Airship.shared.deepLink(testURL)

        // Handler always returns true when set
        let isUAirshipScheme = testURL.scheme == "uairship"
        #expect(result == true)
        #expect(handlerCalled == true || isUAirshipScheme)
    }

    @Test("Handler priority over delegate")
    @MainActor
    func testHandlerPriorityOverDelegate() async throws {
        let airshipInstance = TestAirshipInstance()
        airshipInstance.makeShared()
        defer { TestAirshipInstance.clearShared() }

        let delegate = TestDeepLinkDelegate()
        var handlerCalled = false
        let testURL = URL(string: "myapp://test/priority")!

        // Both handler and delegate are set
        airshipInstance.deepLinkHandler = { url in
            #expect(url == testURL)
            handlerCalled = true
        }

        airshipInstance.deepLinkDelegate = delegate
        airshipInstance.components = []

        let result = await Airship.shared.deepLink(testURL)

        // Handler takes priority, delegate not called
        #expect(result == true)
        #expect(handlerCalled == true)
        await #expect(delegate.receivedDeepLink == nil)
    }

    @Test("Thread safety - concurrent deep link handling")
    @MainActor
    func testConcurrentDeepLinkHandling() async throws {
        let airshipInstance = TestAirshipInstance()
        airshipInstance.makeShared()
        defer { TestAirshipInstance.clearShared() }

        var processedURLs: Set<String> = []
        let lock = NSLock()

        airshipInstance.deepLinkHandler = { url in
            lock.lock()
            processedURLs.insert(url.absoluteString)
            lock.unlock()
            // Simulate some processing time
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        airshipInstance.components = []

        // Create multiple URLs to process concurrently
        let urls = (1...10).map { URL(string: "myapp://test/\($0)")! }

        // Process all URLs concurrently
        await withTaskGroup(of: Bool.self) { group in
            for url in urls {
                group.addTask {
                    await Airship.shared.deepLink(url)
                }
            }

            for await result in group {
                #expect(result == true)
            }
        }

        // Verify all URLs were processed
        lock.lock()
        let finalCount = processedURLs.count
        lock.unlock()

        #expect(finalCount == urls.count)
    }
}
