import XCTest

@testable
import AirshipCore

class UAirshipTest: XCTestCase {
    private var airshipInstance: TestAirshipInstance!
    private let deepLinkHandler: TestDeepLinkDelegateHandler = TestDeepLinkDelegateHandler()

    @MainActor
    override func setUp() {
        airshipInstance = TestAirshipInstance()
        self.airshipInstance.makeShared()
    }

    override class func tearDown() {
        TestAirshipInstance.clearShared()
    }

    func testUAirshipDeepLinks() async {
        let component = TestAirshipComponent()
        component.onDeepLink = { _ in
            XCTFail()
            return false
        }

        self.airshipInstance.components = [component]

        /// App settings
        var result = await Airship.shared.deepLink(URL(string: "uairship://app_settings")!)
        XCTAssertTrue(result)

        // App Store deeplink
        result = await Airship.shared.deepLink(URL(string: "uairship://app_store?itunesID=0123456789")!)
        XCTAssertTrue(result)
    }

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
            XCTFail()
            return false
        }

        self.airshipInstance.components = [component1, component2, component3]
        self.airshipInstance.deepLinkDelegate = deepLinkHandler

        let deepLink = URL(string: "uairship://some-deep-link")!
        let result = await Airship.shared.deepLink(deepLink)
        XCTAssertTrue(result)

        XCTAssertEqual(deepLink, component1.deepLink)
        XCTAssertEqual(deepLink, component2.deepLink)
        XCTAssertNil(component3.deepLink)
        XCTAssertNil(self.deepLinkHandler.deepLink)
    }


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
        let result = await Airship.shared.deepLink(deepLink)
        XCTAssertTrue(result)
        XCTAssertEqual(deepLink, self.deepLinkHandler.deepLink)
        XCTAssertEqual(deepLink, component1.deepLink)
        XCTAssertEqual(deepLink, component2.deepLink)
        XCTAssertEqual(deepLink, component3.deepLink)
    }

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
        let result = await Airship.shared.deepLink(deepLink)
        XCTAssertTrue(result)
        XCTAssertEqual(deepLink, component1.deepLink)
        XCTAssertEqual(deepLink, component2.deepLink)
    }


    func testDeepLink() async {
        let component = TestAirshipComponent()
        component.onDeepLink = { _ in
            XCTFail()
            return false
        }

        self.airshipInstance.components = [component]

        let deepLink = URL(string: "some-other://some-deep-link")!
        let result = await Airship.shared.deepLink(deepLink)
        XCTAssertFalse(result)
        XCTAssertNil(component.deepLink)
    }

    func testDeepLinkDelegate() async {
        let component = TestAirshipComponent()
        component.onDeepLink = { _ in
            XCTFail()
            return false
        }

        self.airshipInstance.components = [component]
        self.airshipInstance.deepLinkDelegate = deepLinkHandler

        let deepLink = URL(string: "some-other://some-deep-link")!
        let result = await Airship.shared.deepLink(deepLink)
        XCTAssertTrue(result)
        XCTAssertNil(component.deepLink)
        XCTAssertEqual(deepLink, deepLinkHandler.deepLink)
    }

    @MainActor
    func testDeepLinkHandlerReturnsTrue() async {
        let component = TestAirshipComponent()
        component.onDeepLink = { _ in
            XCTFail()
            return false
        }

        var handlerCalled = false
        self.airshipInstance.deepLinkHandler = { url in
            XCTAssertEqual(url.absoluteString, "some-other://some-deep-link")
            handlerCalled = true
        }

        self.airshipInstance.deepLinkDelegate = deepLinkHandler
        self.airshipInstance.components = [component]

        let deepLink = URL(string: "some-other://some-deep-link")!
        let result = await Airship.shared.deepLink(deepLink)
        XCTAssertTrue(result)
        XCTAssertTrue(handlerCalled)
        XCTAssertNil(component.deepLink)
        XCTAssertNil(deepLinkHandler.deepLink) // Delegate should not be called
    }

    @MainActor
    func testDeepLinkHandlerPreventsDelegate() async {
        let component = TestAirshipComponent()
        component.onDeepLink = { _ in
            XCTFail()
            return false
        }

        var handlerCalled = false
        self.airshipInstance.deepLinkHandler = { url in
            XCTAssertEqual(url.absoluteString, "some-other://some-deep-link")
            handlerCalled = true
        }

        self.airshipInstance.deepLinkDelegate = deepLinkHandler
        self.airshipInstance.components = [component]

        let deepLink = URL(string: "some-other://some-deep-link")!
        let result = await Airship.shared.deepLink(deepLink)
        XCTAssertTrue(result)
        XCTAssertTrue(handlerCalled)
        XCTAssertNil(component.deepLink)
        XCTAssertNil(deepLinkHandler.deepLink) // Delegate should NOT be called when handler is set
    }

    @MainActor
    func testDeepLinkHandlerWithNoDelegate() async {
        let component = TestAirshipComponent()
        component.onDeepLink = { _ in
            XCTFail()
            return false
        }

        var handlerCalled = false
        self.airshipInstance.deepLinkHandler = { url in
            XCTAssertEqual(url.absoluteString, "some-other://some-deep-link")
            handlerCalled = true
        }

        self.airshipInstance.components = [component]

        let deepLink = URL(string: "some-other://some-deep-link")!
        let result = await Airship.shared.deepLink(deepLink)
        XCTAssertTrue(result) // Should return true since handler is set
        XCTAssertTrue(handlerCalled)
        XCTAssertNil(component.deepLink)
    }

    @MainActor
    func testUAirshipDeepLinkHandlerIntercepts() async {
        let component = TestAirshipComponent()
        component.onDeepLink = { _ in
            return false
        }

        var handlerCalled = false
        self.airshipInstance.deepLinkHandler = { url in
            XCTAssertEqual(url.absoluteString, "uairship://some-deep-link")
            handlerCalled = true
        }

        self.airshipInstance.deepLinkDelegate = deepLinkHandler
        self.airshipInstance.components = [component]

        let deepLink = URL(string: "uairship://some-deep-link")!
        let result = await Airship.shared.deepLink(deepLink)
        XCTAssertTrue(result)
        XCTAssertTrue(handlerCalled)
        XCTAssertEqual(deepLink, component.deepLink) // Component still gets called for uairship:// URLs
        XCTAssertNil(deepLinkHandler.deepLink) // Delegate should NOT be called when handler is set
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

