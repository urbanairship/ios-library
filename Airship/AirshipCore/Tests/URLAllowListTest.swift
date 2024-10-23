/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

class UAURLAllowListTest: XCTestCase {

    private var allowList: URLAllowList!
    private let scopes: [URLAllowListScope] = [.javaScriptInterface, .openURL, .all]

    override func setUp() {
        super.setUp()
        allowList = URLAllowList()
    }

    func testEmptyURLAllowList() {
        for scope in scopes {
            XCTAssertFalse(allowList.isAllowed(URL(string: "urbanairship.com")!, scope: scope))
            XCTAssertFalse(allowList.isAllowed(URL(string: "www.urbanairship.com")!, scope: scope))
            XCTAssertFalse(allowList.isAllowed(URL(string: "http://www.urbanairship.com")!, scope: scope))
            XCTAssertFalse(allowList.isAllowed(URL(string: "https://www.urbanairship.com")!, scope: scope))
            XCTAssertFalse(allowList.isAllowed(URL(string: "file:///*")!, scope: scope))
        }
    }

    @MainActor
    func testDefaultURLAllowList() {
        var config = AirshipConfig()
        config.inProduction = false
        config.developmentAppKey = "test-app-key"
        config.developmentAppSecret = "test-app-secret"
        config.urlAllowList = []

        let runtimeConfig = RuntimeConfig(config: config, dataStore: PreferenceDataStore(appKey: UUID().uuidString))

        let allowList = URLAllowList.allowListWithConfig(runtimeConfig)

        for scope in scopes {
            XCTAssertTrue(allowList.isAllowed(URL(string: "https://device-api.urbanairship.com/api/user/")!, scope: scope))
            XCTAssertTrue(allowList.isAllowed(URL(string: "https://dl.urbanairship.com/aaa/message_id")!, scope: scope))
            XCTAssertTrue(allowList.isAllowed(URL(string: "https://device-api.asnapieu.com/api/user/")!, scope: scope))
            XCTAssertTrue(allowList.isAllowed(URL(string: "https://dl.asnapieu.com/aaa/message_id")!, scope: scope))
        }

        XCTAssertFalse(allowList.isAllowed(URL(string: "https://*.youtube.com")!, scope: .openURL))
        XCTAssertFalse(allowList.isAllowed(URL(string: "https://*.youtube.com")!, scope: .javaScriptInterface))
        XCTAssertFalse(allowList.isAllowed(URL(string: "https://*.youtube.com")!, scope: .all))

        XCTAssertTrue(allowList.isAllowed(URL(string: "sms:+18675309?body=Hi%20you")!, scope: .openURL))
        XCTAssertTrue(allowList.isAllowed(URL(string: "sms:8675309")!, scope: .openURL))

        XCTAssertTrue(allowList.isAllowed(URL(string: "tel:+18675309")!, scope: .openURL))
        XCTAssertTrue(allowList.isAllowed(URL(string: "tel:867-5309")!, scope: .openURL))

        XCTAssertTrue(allowList.isAllowed(URL(string: "mailto:name@example.com?subject=The%20subject%20of%20the%20mail")!, scope: .openURL))
        XCTAssertTrue(allowList.isAllowed(URL(string: "mailto:name@example.com")!, scope: .openURL))

        XCTAssertTrue(allowList.isAllowed(URL(string: UIApplication.openSettingsURLString)!, scope: .openURL))
        XCTAssertTrue(allowList.isAllowed(URL(string: "app-settings:")!, scope: .openURL))

        XCTAssertFalse(allowList.isAllowed(URL(string: "https://some-random-url.com")!, scope: .openURL))
    }

    @MainActor
    func testDefaultURLAllowListNoOpenScopeSet() {
        var config = AirshipConfig()
        config.inProduction = false
        config.developmentAppKey = "test-app-key"
        config.developmentAppSecret = "test-app-secret"

        let runtimeConfig = RuntimeConfig(config: config, dataStore: PreferenceDataStore(appKey: UUID().uuidString))

        let allowList = URLAllowList.allowListWithConfig(runtimeConfig)

        for scope in scopes {
            XCTAssertTrue(allowList.isAllowed(URL(string: "https://device-api.urbanairship.com/api/user/")!, scope: scope))
            XCTAssertTrue(allowList.isAllowed(URL(string: "https://dl.urbanairship.com/aaa/message_id")!, scope: scope))
            XCTAssertTrue(allowList.isAllowed(URL(string: "https://device-api.asnapieu.com/api/user/")!, scope: scope))
            XCTAssertTrue(allowList.isAllowed(URL(string: "https://dl.asnapieu.com/aaa/message_id")!, scope: scope))
        }

        XCTAssertTrue(allowList.isAllowed(URL(string: "https://*.youtube.com")!, scope: .openURL))
        XCTAssertFalse(allowList.isAllowed(URL(string: "https://*.youtube.com")!, scope: .javaScriptInterface))
        XCTAssertFalse(allowList.isAllowed(URL(string: "https://*.youtube.com")!, scope: .all))

        XCTAssertTrue(allowList.isAllowed(URL(string: "sms:+18675309?body=Hi%20you")!, scope: .openURL))
        XCTAssertTrue(allowList.isAllowed(URL(string: "sms:8675309")!, scope: .openURL))

        XCTAssertTrue(allowList.isAllowed(URL(string: "tel:+18675309")!, scope: .openURL))
        XCTAssertTrue(allowList.isAllowed(URL(string: "tel:867-5309")!, scope: .openURL))

        XCTAssertTrue(allowList.isAllowed(URL(string: "mailto:name@example.com?subject=The%20subject%20of%20the%20mail")!, scope: .openURL))
        XCTAssertTrue(allowList.isAllowed(URL(string: "mailto:name@example.com")!, scope: .openURL))

        XCTAssertTrue(allowList.isAllowed(URL(string: UIApplication.openSettingsURLString)!, scope: .openURL))
        XCTAssertTrue(allowList.isAllowed(URL(string: "app-settings:")!, scope: .openURL))

        XCTAssertTrue(allowList.isAllowed(URL(string: "https://some-random-url.com")!, scope: .openURL))
    }

    func testInvalidPatterns() {
        // Not a URL
        XCTAssertFalse(allowList.addEntry("not a url"))

        // Missing schemes
        XCTAssertFalse(allowList.addEntry("www.urbanairship.com"))
        XCTAssertFalse(allowList.addEntry("://www.urbanairship.com"))

        // White space in scheme
        XCTAssertFalse(allowList.addEntry(" file://*"))

        // Invalid hosts
        XCTAssertFalse(allowList.addEntry("*://what*"))
        XCTAssertFalse(allowList.addEntry("*://*what"))
    }

    func testSchemeWildcard() {
        allowList.addEntry("*://www.urbanairship.com")

        XCTAssertTrue(allowList.addEntry("*://www.urbanairship.com"))
        XCTAssertTrue(allowList.addEntry("cool*story://rad"))

        // Reject
        XCTAssertFalse(allowList.isAllowed(URL(string: "")))
        XCTAssertFalse(allowList.isAllowed(URL(string: "urbanairship.com")!))
        XCTAssertFalse(allowList.isAllowed(URL(string: "www.urbanairship.com")!))
        XCTAssertFalse(allowList.isAllowed(URL(string: "cool://rad")!))

        // Accept
        XCTAssertTrue(allowList.isAllowed(URL(string: "https://www.urbanairship.com")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "http://www.urbanairship.com")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "file://www.urbanairship.com")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "valid://www.urbanairship.com")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "cool----story://rad")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "coolstory://rad")!))
    }

    func testScheme() {
        allowList.addEntry("https://www.urbanairship.com")
        allowList.addEntry("file:///asset.html")

        // Reject
        XCTAssertFalse(allowList.isAllowed(URL(string: "http://www.urbanairship.com")!))

        // Accept
        XCTAssertTrue(allowList.isAllowed(URL(string: "https://www.urbanairship.com")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "file:///asset.html")!))
    }

    func testHost() {
        XCTAssertTrue(allowList.addEntry("http://www.urbanairship.com"))
        XCTAssertTrue(allowList.addEntry("http://oh.hi.marc"))

        // Reject
        XCTAssertFalse(allowList.isAllowed(URL(string: "http://oh.bye.marc")!))
        XCTAssertFalse(allowList.isAllowed(URL(string: "http://www.urbanairship.com.hackers.io")!))
        XCTAssertFalse(allowList.isAllowed(URL(string: "http://omg.www.urbanairship.com.hackers.io")!))

        // Accept
        XCTAssertTrue(allowList.isAllowed(URL(string: "http://www.urbanairship.com")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "http://oh.hi.marc")!))
    }

    func testHostWildcard() {
        XCTAssertTrue(allowList.addEntry("http://*"))
        XCTAssertTrue(allowList.addEntry("https://*.coolstory"))

        // * is only available at the beginning
        XCTAssertFalse(allowList.addEntry("https://*.coolstory.*"))

        // Reject
        XCTAssertFalse(allowList.isAllowed(URL(string: "")))
        XCTAssertFalse(allowList.isAllowed(URL(string: "https://cool")!))
        XCTAssertFalse(allowList.isAllowed(URL(string: "https://story")!))

        // Accept
        XCTAssertTrue(allowList.isAllowed(URL(string: "http://what.urbanairship.com")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "http:///android-asset/test.html")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "http://www.anything.com")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "https://coolstory")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "https://what.coolstory")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "https://what.what.coolstory")!))
    }

    func testHostWildcardSubdomain() {
        XCTAssertTrue(allowList.addEntry("http://*.urbanairship.com"))

        // Accept
        XCTAssertTrue(allowList.isAllowed(URL(string: "http://what.urbanairship.com")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "http://hi.urbanairship.com")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "http://urbanairship.com")!))

        // Reject
        XCTAssertFalse(allowList.isAllowed(URL(string: "http://lololurbanairship.com")!))
    }

    func testWildcardMatcher() {
        XCTAssertTrue(allowList.addEntry("*"))

        XCTAssertTrue(allowList.isAllowed(URL(string: "file:///what/oh/hi")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "https://hi.urbanairship.com/path")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "http://urbanairship.com")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "cool.story://urbanairship.com")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "sms:+18664504185?body=Hi")!))
    }

    func testFilePaths() {
        XCTAssertTrue(allowList.addEntry("file:///foo/index.html"))

        // Reject
        XCTAssertFalse(allowList.isAllowed(URL(string: "file:///foo/test.html")!))
        XCTAssertFalse(allowList.isAllowed(URL(string: "file:///foo/bar/index.html")!))

        // Accept
        XCTAssertTrue(allowList.isAllowed(URL(string: "file:///foo/index.html")!))
    }

    func testFilePathsWildCard() {
        XCTAssertTrue(allowList.addEntry("file:///foo/bar.html"))
        XCTAssertTrue(allowList.addEntry("file:///foo/*"))

        // Reject
        XCTAssertFalse(allowList.isAllowed(URL(string: "file:///foooooooo/bar.html")!))

        // Accept
        XCTAssertTrue(allowList.isAllowed(URL(string: "file:///foo/test.html")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "file:///foo/bar/index.html")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "file:///foo/bar.html")!))
    }

    func testURLPaths() {
        allowList.addEntry("*://*.urbanairship.com/accept.html")
        allowList.addEntry("*://*.urbanairship.com/anythingHTML/*.html")
        allowList.addEntry("https://urbanairship.com/what/index.html")
        allowList.addEntry("wild://cool/*")

        // Reject
        XCTAssertFalse(allowList.isAllowed(URL(string: "https://what.urbanairship.com/reject.html")!))
        XCTAssertFalse(allowList.isAllowed(URL(string: "https://what.urbanairship.com/anythingHTML/image.png")!))
        XCTAssertFalse(allowList.isAllowed(URL(string: "https://what.urbanairship.com/anythingHTML/image.png")!))
        XCTAssertFalse(allowList.isAllowed(URL(string: "wile:///whatever")!))
        XCTAssertFalse(allowList.isAllowed(URL(string: "wile:///cool")!))

        // Accept
        XCTAssertTrue(allowList.isAllowed(URL(string: "https://what.urbanairship.com/anythingHTML/index.html")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "https://what.urbanairship.com/anythingHTML/test.html")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "https://what.urbanairship.com/anythingHTML/foo/bar/index.html")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "https://urbanairship.com/what/index.html")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "wild://cool")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "wild://cool/")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "wild://cool/path")!))
    }

    func testScope() {
        allowList.addEntry("*://*.urbanairship.com/accept-js.html", scope: .javaScriptInterface)
        allowList.addEntry("*://*.urbanairship.com/accept-url.html", scope: .openURL)
        allowList.addEntry("*://*.urbanairship.com/accept-all.html", scope: .all)

        XCTAssertTrue(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-js.html")!, scope: .javaScriptInterface))
        XCTAssertFalse(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-js.html")!, scope: .openURL))
        XCTAssertFalse(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-js.html")!, scope: .all))

        XCTAssertTrue(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-url.html")!, scope: .openURL))
        XCTAssertFalse(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-url.html")!, scope: .javaScriptInterface))
        XCTAssertFalse(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-url.html")!, scope: .all))

        XCTAssertTrue(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-all.html")!, scope: .all))
        XCTAssertTrue(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-all.html")!, scope: .javaScriptInterface))
        XCTAssertTrue(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-all.html")!, scope: .openURL))
    }

    func testDisableOpenURLScopeAllowList() {
        XCTAssertFalse(allowList.isAllowed(URL(string: "https://someurl.com")!, scope: .openURL))

        allowList.addEntry("*", scope: .openURL)

        XCTAssertTrue(allowList.isAllowed(URL(string: "https://someurl.com")!, scope: .openURL))
        XCTAssertFalse(allowList.isAllowed(URL(string: "https://someurl.com")!, scope: .javaScriptInterface))
        XCTAssertFalse(allowList.isAllowed(URL(string: "https://someurl.com")!, scope: .all))
    }

    func testAddAllScopesSeparately() {
        allowList.addEntry("*://*.urbanairship.com/all.html", scope: .openURL)
        allowList.addEntry("*://*.urbanairship.com/all.html", scope: .javaScriptInterface)

        XCTAssertTrue(allowList.isAllowed(URL(string: "https://urbanairship.com/all.html")!, scope: .all))
    }

    func testAllScopeMatchesInnerScopes() {
        allowList.addEntry("*://*.urbanairship.com/all.html", scope: .all)

        XCTAssertTrue(allowList.isAllowed(URL(string: "https://urbanairship.com/all.html")!, scope: .javaScriptInterface))
        XCTAssertTrue(allowList.isAllowed(URL(string: "https://urbanairship.com/all.html")!, scope: .openURL))
    }

    func testDeepLinks() {
        // Test any path and undefined host
        XCTAssertTrue(allowList.addEntry("com.urbanairship.one:/*"))
        XCTAssertTrue(allowList.isAllowed(URL(string: "com.urbanairship.one://cool")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "com.urbanairship.one:cool")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "com.urbanairship.one:/cool")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "com.urbanairship.one:///cool")!))

        // Test any host and undefined path
        XCTAssertTrue(allowList.addEntry("com.urbanairship.two://*"))
        XCTAssertTrue(allowList.isAllowed(URL(string: "com.urbanairship.two:cool")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "com.urbanairship.two://cool")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "com.urbanairship.two:/cool")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "com.urbanairship.two:///cool")!))

        // Test any host and any path
        XCTAssertTrue(allowList.addEntry("com.urbanairship.three://*/*"))
        XCTAssertTrue(allowList.isAllowed(URL(string: "com.urbanairship.three:cool")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "com.urbanairship.three://cool")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "com.urbanairship.three:/cool")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "com.urbanairship.three:///cool")!))

        // Test specific host and path
        XCTAssertTrue(allowList.addEntry("com.urbanairship.four://*.cool/whatever/*"))
        XCTAssertFalse(allowList.isAllowed(URL(string: "com.urbanairship.four:cool")!))
        XCTAssertFalse(allowList.isAllowed(URL(string: "com.urbanairship.four://cool")!))
        XCTAssertFalse(allowList.isAllowed(URL(string: "com.urbanairship.four:/cool")!))
        XCTAssertFalse(allowList.isAllowed(URL(string: "com.urbanairship.four:///cool")!))

        XCTAssertTrue(allowList.isAllowed(URL(string: "com.urbanairship.four://whatever.cool/whatever/")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "com.urbanairship.four://cool/whatever/indeed")!))
    }


    func testRootPath() {
        XCTAssertTrue(allowList.addEntry("com.urbanairship.five:/"))

        XCTAssertTrue(allowList.isAllowed(URL(string: "com.urbanairship.five:/")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "com.urbanairship.five:///")!))

        XCTAssertFalse(allowList.isAllowed(URL(string: "com.urbanairship.five:/cool")!))
    }

    func testDelegate() {
        // set up a simple URL allow list
        allowList.addEntry("https://*.urbanairship.com")
        allowList.addEntry("https://*.youtube.com", scope: .openURL)

        // Matching URL to be checked
        let matchingURLToReject = URL(string: "https://www.youtube.com/watch?v=sYd_-pAfbBw")!
        let matchingURLToAccept = URL(string: "https://device-api.urbanairship.com/api/user")!
        let nonMatchingURL = URL(string: "https://maps.google.com")!

        let scope: URLAllowListScope = .openURL

        // Allow listing when delegate is off
        XCTAssertTrue(allowList.isAllowed(matchingURLToReject, scope: scope))
        XCTAssertTrue(allowList.isAllowed(matchingURLToAccept, scope: scope))
        XCTAssertFalse(allowList.isAllowed(nonMatchingURL, scope: scope))

        // Enable URL allow list delegate
        let delegate = TestDelegate()
        delegate.onAllow = { url, scope in
            if (url == matchingURLToAccept) {
                return true
            }

            if (url == matchingURLToReject) {
                return false
            }

            XCTFail()
            return false
        }

        allowList.delegate = delegate

        // rejected URL should now fail URL allow list test, others should be unchanged
        XCTAssertFalse(allowList.isAllowed(matchingURLToReject, scope: scope))
        XCTAssertTrue(allowList.isAllowed(matchingURLToAccept, scope: scope))
        XCTAssertFalse(allowList.isAllowed(nonMatchingURL, scope: scope))

        // Disable URL allow list delegate
        allowList.delegate = nil

        // Should go back to original state when delegate was off
        XCTAssertTrue(allowList.isAllowed(matchingURLToReject, scope: scope))
        XCTAssertTrue(allowList.isAllowed(matchingURLToAccept, scope: scope))
        XCTAssertFalse(allowList.isAllowed(nonMatchingURL, scope: scope))
    }

    func testSMSPath() {
        XCTAssertTrue(allowList.addEntry("sms:86753*9*"))

        XCTAssertFalse(allowList.isAllowed(URL(string: "sms:86753")!))
        XCTAssertFalse(allowList.isAllowed(URL(string: "sms:867530")!))

        XCTAssertTrue(allowList.isAllowed(URL(string: "sms:86753191")!))
        XCTAssertTrue(allowList.isAllowed(URL(string: "sms:8675309")!))
    }
}

fileprivate class TestDelegate: URLAllowListDelegate {
    var allowURLCalled = false

    var onAllow: ((URL, URLAllowListScope) -> Bool)?

    func allowURL(_ url: URL, scope: URLAllowListScope) -> Bool {
        allowURLCalled = true
        return onAllow!(url, scope)
    }
}
