import XCTest

@testable
import AirshipCore

class UAirshipTest: XCTestCase {
    private let airshipInstance: TestAirshipInstance = TestAirshipInstance()
    private let deepLinkHandler: TestDeepLinkDelegateHandler = TestDeepLinkDelegateHandler()

    override func setUp() {
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
}


fileprivate class TestAirshipComponent: AirshipComponent {
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

