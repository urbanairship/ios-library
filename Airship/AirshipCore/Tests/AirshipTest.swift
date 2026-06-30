import Testing
import Foundation

@testable
import AirshipCore

@MainActor
@Suite
struct UAirshipTest {
    private var airshipInstance: TestAirshipInstance!
    private let deepLinkHandler: TestDeepLinkDelegateHandler = TestDeepLinkDelegateHandler()

    init() {
        airshipInstance = TestAirshipInstance()
        self.airshipInstance.makeShared()
    }

    @Test
    @MainActor
    func testUAirshipDeepLinks() async {
        let component = TestAirshipComponent()
        component.onDeepLink = { _ in
            Issue.record()
            return false
        }
        
        let testOpener = (self.airshipInstance.urlOpener as! TestURLOpener)

        self.airshipInstance.components = [component]

        /// App settings
        var result = await Airship.processDeepLink(URL(string: "uairship://app_settings")!)
        #expect(result)
        #expect(testOpener.lastOpenSettingsCalled)
        
        testOpener.reset()

        // App Store deeplink
        result = await Airship.processDeepLink(URL(string: "uairship://app_store?itunesID=0123456789")!)
        #expect(result)
        #expect(testOpener.lastURL?.absoluteString == "itms-apps://itunes.apple.com/app/0123456789")
    }

    @Test
    func testUAirshipComponentsDeepLinks() async {
        let component1 = TestAirshipComponent()
        component1.onDeepLink = { _ in
            return false
        }

        let component2 = TestAirshipComponent()
        component2.onDeepLink = { _ in
            return true
        }

        let component3 = TestAirshipComponent()
        component3.onDeepLink = { _ in
            Issue.record()
            return false
        }

        self.airshipInstance.components = [component1, component2, component3]
        self.airshipInstance.deepLinkDelegate = deepLinkHandler

        let deepLink = URL(string: "uairship://some-deep-link")!
        let result = await Airship.processDeepLink(deepLink)
        #expect(result)

        #expect(deepLink == component1.deepLink)
        #expect(deepLink == component2.deepLink)
        #expect(component3.deepLink == nil)
        #expect(self.deepLinkHandler.deepLink == nil)
    }


    @Test
    func testUAirshipComponentsDeepLinksFallbackDelegate() async {
        let component1 = TestAirshipComponent()
        component1.onDeepLink = { _ in
            return false
        }

        let component2 = TestAirshipComponent()
        component2.onDeepLink = { _ in
            return false
        }

        let component3 = TestAirshipComponent()
        component3.onDeepLink = { _ in
            return false
        }

        self.airshipInstance.components = [component1, component2, component3]
        self.airshipInstance.deepLinkDelegate = deepLinkHandler

        let deepLink = URL(string: "uairship://some-deep-link")!
        let result = await Airship.processDeepLink(deepLink)
        #expect(result)
        #expect(deepLink == self.deepLinkHandler.deepLink)
        #expect(deepLink == component1.deepLink)
        #expect(deepLink == component2.deepLink)
        #expect(deepLink == component3.deepLink)
    }

    @Test
    func testUAirshipComponentsDeepLinksAlwaysReturnsTrue() async {
        let component1 = TestAirshipComponent()
        component1.onDeepLink = { _ in
            return false
        }

        let component2 = TestAirshipComponent()
        component2.onDeepLink = { _ in
            return false
        }

        self.airshipInstance.components = [component1, component2]

        let deepLink = URL(string: "uairship://some-deep-link")!
        let result = await Airship.processDeepLink(deepLink)
        #expect(result)
        #expect(deepLink == component1.deepLink)
        #expect(deepLink == component2.deepLink)
    }


    @Test
    func testDeepLink() async {
        let component = TestAirshipComponent()
        component.onDeepLink = { _ in
            Issue.record()
            return false
        }

        self.airshipInstance.components = [component]

        let deepLink = URL(string: "some-other://some-deep-link")!
        let result = await Airship.processDeepLink(deepLink)
        #expect(!result)
        #expect(component.deepLink == nil)
    }

    @Test
    func testDeepLinkDelegate() async {
        let component = TestAirshipComponent()
        component.onDeepLink = { _ in
            Issue.record()
            return false
        }

        self.airshipInstance.components = [component]
        self.airshipInstance.deepLinkDelegate = deepLinkHandler

        let deepLink = URL(string: "some-other://some-deep-link")!
        let result = await Airship.processDeepLink(deepLink)
        #expect(result)
        #expect(component.deepLink == nil)
        #expect(deepLink == deepLinkHandler.deepLink)
    }

    @Test
    @MainActor
    func testDeepLinkHandlerReturnsTrue() async {
        let component = TestAirshipComponent()
        component.onDeepLink = { _ in
            Issue.record()
            return false
        }

        var handlerCalled = false
        self.airshipInstance.onDeepLink = { url in
            #expect(url.absoluteString == "some-other://some-deep-link")
            handlerCalled = true
        }

        self.airshipInstance.deepLinkDelegate = deepLinkHandler
        self.airshipInstance.components = [component]

        let deepLink = URL(string: "some-other://some-deep-link")!
        let result = await Airship.processDeepLink(deepLink)
        #expect(result)
        #expect(handlerCalled)
        #expect(component.deepLink == nil)
        #expect(deepLinkHandler.deepLink == nil) // Delegate should not be called
    }

    @Test
    @MainActor
    func testDeepLinkHandlerPreventsDelegate() async {
        let component = TestAirshipComponent()
        component.onDeepLink = { _ in
            Issue.record()
            return false
        }

        var handlerCalled = false
        self.airshipInstance.onDeepLink = { url in
            #expect(url.absoluteString == "some-other://some-deep-link")
            handlerCalled = true
        }

        self.airshipInstance.deepLinkDelegate = deepLinkHandler
        self.airshipInstance.components = [component]

        let deepLink = URL(string: "some-other://some-deep-link")!
        let result = await Airship.processDeepLink(deepLink)
        #expect(result)
        #expect(handlerCalled)
        #expect(component.deepLink == nil)
        #expect(deepLinkHandler.deepLink == nil) // Delegate should NOT be called when handler is set
    }

    @Test
    @MainActor
    func testDeepLinkHandlerWithNoDelegate() async {
        let component = TestAirshipComponent()
        component.onDeepLink = { _ in
            Issue.record()
            return false
        }

        var handlerCalled = false
        self.airshipInstance.onDeepLink = { url in
            #expect(url.absoluteString == "some-other://some-deep-link")
            handlerCalled = true
        }

        self.airshipInstance.components = [component]

        let deepLink = URL(string: "some-other://some-deep-link")!
        let result = await Airship.processDeepLink(deepLink)
        #expect(result) // Should return true since handler is set
        #expect(handlerCalled)
        #expect(component.deepLink == nil)
    }

    @Test
    @MainActor
    func testUAirshipDeepLinkHandlerIntercepts() async {
        let component = TestAirshipComponent()
        component.onDeepLink = { _ in
            return false
        }

        var handlerCalled = false
        self.airshipInstance.onDeepLink = { url in
            #expect(url.absoluteString == "uairship://some-deep-link")
            handlerCalled = true
        }

        self.airshipInstance.deepLinkDelegate = deepLinkHandler
        self.airshipInstance.components = [component]

        let deepLink = URL(string: "uairship://some-deep-link")!
        let result = await Airship.processDeepLink(deepLink)
        #expect(result)
        #expect(handlerCalled)
        #expect(deepLink == component.deepLink) // Component still gets called for uairship:// URLs
        #expect(deepLinkHandler.deepLink == nil) // Delegate should NOT be called when handler is set
    }
}


fileprivate class TestAirshipComponent: AirshipComponent, @unchecked Sendable {
    var onDeepLink: ((URL) -> Bool)?
    var deepLink: URL? = nil

    func deepLink(_ deepLink: URL) -> Bool {
        self.deepLink = deepLink
        guard let onDeepLink = onDeepLink else { return false }
        return onDeepLink(deepLink)
    }
}

fileprivate class TestDeepLinkDelegateHandler: DeepLinkDelegate, @unchecked Sendable {
    var deepLink: URL? = nil

    func receivedDeepLink(_ deepLink: URL) async {
        self.deepLink = deepLink
    }
}
