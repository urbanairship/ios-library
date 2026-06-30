/* Copyright Airship and Contributors */

import Testing
import Foundation
import UIKit

@testable
import AirshipCore

@MainActor
@Suite
struct AirshipURLAllowListTest {

    private let allowList: DefaultAirshipURLAllowList = DefaultAirshipURLAllowList()
    private let scopes: [URLAllowListScope] = [.javaScriptInterface, .openURL, .all]

    @Test
    func testDefaultURLAllowList() {
        var airshipConfig = AirshipConfig()
        airshipConfig.urlAllowListScopeOpenURL = []

        let allowList = DefaultAirshipURLAllowList(airshipConfig: airshipConfig)

        for scope in scopes {
            #expect(allowList.isAllowed(URL(string: "https://device-api.urbanairship.com/api/user/")!, scope: scope))
            #expect(allowList.isAllowed(URL(string: "https://dl.urbanairship.com/aaa/message_id")!, scope: scope))
            #expect(allowList.isAllowed(URL(string: "https://device-api.asnapieu.com/api/user/")!, scope: scope))
            #expect(allowList.isAllowed(URL(string: "https://dl.asnapieu.com/aaa/message_id")!, scope: scope))
        }

        #expect(!(allowList.isAllowed(URL(string: "https://*.youtube.com")!, scope: .openURL)))
        #expect(!(allowList.isAllowed(URL(string: "https://*.youtube.com")!, scope: .javaScriptInterface)))
        #expect(!(allowList.isAllowed(URL(string: "https://*.youtube.com")!, scope: .all)))

        #expect(allowList.isAllowed(URL(string: "sms:+18675309?body=Hi%20you")!, scope: .openURL))
        #expect(allowList.isAllowed(URL(string: "sms:8675309")!, scope: .openURL))

        #expect(allowList.isAllowed(URL(string: "tel:+18675309")!, scope: .openURL))
        #expect(allowList.isAllowed(URL(string: "tel:867-5309")!, scope: .openURL))

        #expect(allowList.isAllowed(URL(string: "mailto:name@example.com?subject=The%20subject%20of%20the%20mail")!, scope: .openURL))
        #expect(allowList.isAllowed(URL(string: "mailto:name@example.com")!, scope: .openURL))

        #expect(allowList.isAllowed(URL(string: UIApplication.openSettingsURLString)!, scope: .openURL))
        #expect(allowList.isAllowed(URL(string: "app-settings:")!, scope: .openURL))

        #expect(!(allowList.isAllowed(URL(string: "https://some-random-url.com")!, scope: .openURL)))
    }

    @Test
    @MainActor
    func testDefaultURLAllowListNoOpenScopeSet() {
        let allowList = DefaultAirshipURLAllowList(airshipConfig: .init())

        for scope in scopes {
            #expect(allowList.isAllowed(URL(string: "https://device-api.urbanairship.com/api/user/")!, scope: scope))
            #expect(allowList.isAllowed(URL(string: "https://dl.urbanairship.com/aaa/message_id")!, scope: scope))
            #expect(allowList.isAllowed(URL(string: "https://device-api.asnapieu.com/api/user/")!, scope: scope))
            #expect(allowList.isAllowed(URL(string: "https://dl.asnapieu.com/aaa/message_id")!, scope: scope))
        }

        #expect(allowList.isAllowed(URL(string: "https://*.youtube.com")!, scope: .openURL))
        #expect(!(allowList.isAllowed(URL(string: "https://*.youtube.com")!, scope: .javaScriptInterface)))
        #expect(!(allowList.isAllowed(URL(string: "https://*.youtube.com")!, scope: .all)))

        #expect(allowList.isAllowed(URL(string: "sms:+18675309?body=Hi%20you")!, scope: .openURL))
        #expect(allowList.isAllowed(URL(string: "sms:8675309")!, scope: .openURL))

        #expect(allowList.isAllowed(URL(string: "tel:+18675309")!, scope: .openURL))
        #expect(allowList.isAllowed(URL(string: "tel:867-5309")!, scope: .openURL))

        #expect(allowList.isAllowed(URL(string: "mailto:name@example.com?subject=The%20subject%20of%20the%20mail")!, scope: .openURL))
        #expect(allowList.isAllowed(URL(string: "mailto:name@example.com")!, scope: .openURL))

        #expect(allowList.isAllowed(URL(string: UIApplication.openSettingsURLString)!, scope: .openURL))
        #expect(allowList.isAllowed(URL(string: "app-settings:")!, scope: .openURL))

        #expect(allowList.isAllowed(URL(string: "https://some-random-url.com")!, scope: .openURL))
    }

    @Test
    func testInvalidPatterns() {
        // Not a URL
        #expect(!(allowList.addEntry("not a url")))

        // Missing schemes
        #expect(!(allowList.addEntry("www.urbanairship.com")))
        #expect(!(allowList.addEntry("://www.urbanairship.com")))

        // White space in scheme
        #expect(!(allowList.addEntry(" file://*")))

        // Invalid hosts
        #expect(!(allowList.addEntry("*://what*")))
        #expect(!(allowList.addEntry("*://*what")))
    }

    @Test
    func testSchemeWildcard() {
        allowList.addEntry("*://www.urbanairship.com")

        #expect(allowList.addEntry("*://www.urbanairship.com"))
        #expect(allowList.addEntry("cool*story://rad"))

        // Reject
        #expect(!(allowList.isAllowed(URL(string: ""))))
        #expect(!(allowList.isAllowed(URL(string: "urbanairship.com")!)))
        #expect(!(allowList.isAllowed(URL(string: "www.urbanairship.com")!)))
        #expect(!(allowList.isAllowed(URL(string: "cool://rad")!)))

        // Accept
        #expect(allowList.isAllowed(URL(string: "https://www.urbanairship.com")!))
        #expect(allowList.isAllowed(URL(string: "http://www.urbanairship.com")!))
        #expect(allowList.isAllowed(URL(string: "file://www.urbanairship.com")!))
        #expect(allowList.isAllowed(URL(string: "valid://www.urbanairship.com")!))
        #expect(allowList.isAllowed(URL(string: "cool----story://rad")!))
        #expect(allowList.isAllowed(URL(string: "coolstory://rad")!))
    }

    @Test
    func testScheme() {
        allowList.addEntry("https://www.urbanairship.com")
        allowList.addEntry("file:///asset.html")

        // Reject
        #expect(!(allowList.isAllowed(URL(string: "http://www.urbanairship.com")!)))

        // Accept
        #expect(allowList.isAllowed(URL(string: "https://www.urbanairship.com")!))
        #expect(allowList.isAllowed(URL(string: "file:///asset.html")!))
    }

    @Test
    func testHost() {
        #expect(allowList.addEntry("http://www.urbanairship.com"))
        #expect(allowList.addEntry("http://oh.hi.marc"))

        // Reject
        #expect(!(allowList.isAllowed(URL(string: "http://oh.bye.marc")!)))
        #expect(!(allowList.isAllowed(URL(string: "http://www.urbanairship.com.hackers.io")!)))
        #expect(!(allowList.isAllowed(URL(string: "http://omg.www.urbanairship.com.hackers.io")!)))

        // Accept
        #expect(allowList.isAllowed(URL(string: "http://www.urbanairship.com")!))
        #expect(allowList.isAllowed(URL(string: "http://oh.hi.marc")!))
    }

    @Test
    func testHostWildcard() {
        #expect(allowList.addEntry("http://*"))
        #expect(allowList.addEntry("https://*.coolstory"))

        // * is only available at the beginning
        #expect(!(allowList.addEntry("https://*.coolstory.*")))

        // Reject
        #expect(!(allowList.isAllowed(URL(string: ""))))
        #expect(!(allowList.isAllowed(URL(string: "https://cool")!)))
        #expect(!(allowList.isAllowed(URL(string: "https://story")!)))

        // Accept
        #expect(allowList.isAllowed(URL(string: "http://what.urbanairship.com")!))
        #expect(allowList.isAllowed(URL(string: "http:///android-asset/test.html")!))
        #expect(allowList.isAllowed(URL(string: "http://www.anything.com")!))
        #expect(allowList.isAllowed(URL(string: "https://coolstory")!))
        #expect(allowList.isAllowed(URL(string: "https://what.coolstory")!))
        #expect(allowList.isAllowed(URL(string: "https://what.what.coolstory")!))
    }

    @Test
    func testHostWildcardSubdomain() {
        #expect(allowList.addEntry("http://*.urbanairship.com"))

        // Accept
        #expect(allowList.isAllowed(URL(string: "http://what.urbanairship.com")!))
        #expect(allowList.isAllowed(URL(string: "http://hi.urbanairship.com")!))
        #expect(allowList.isAllowed(URL(string: "http://urbanairship.com")!))

        // Reject
        #expect(!(allowList.isAllowed(URL(string: "http://lololurbanairship.com")!)))
    }

    @Test
    func testWildcardMatcher() {
        #expect(allowList.addEntry("*"))

        #expect(allowList.isAllowed(URL(string: "file:///what/oh/hi")!))
        #expect(allowList.isAllowed(URL(string: "https://hi.urbanairship.com/path")!))
        #expect(allowList.isAllowed(URL(string: "http://urbanairship.com")!))
        #expect(allowList.isAllowed(URL(string: "cool.story://urbanairship.com")!))
        #expect(allowList.isAllowed(URL(string: "sms:+18664504185?body=Hi")!))
    }

    @Test
    func testFilePaths() {
        #expect(allowList.addEntry("file:///foo/index.html"))

        // Reject
        #expect(!(allowList.isAllowed(URL(string: "file:///foo/test.html")!)))
        #expect(!(allowList.isAllowed(URL(string: "file:///foo/bar/index.html")!)))

        // Accept
        #expect(allowList.isAllowed(URL(string: "file:///foo/index.html")!))
    }

    @Test
    func testFilePathsWildCard() {
        #expect(allowList.addEntry("file:///foo/bar.html"))
        #expect(allowList.addEntry("file:///foo/*"))

        // Reject
        #expect(!(allowList.isAllowed(URL(string: "file:///foooooooo/bar.html")!)))

        // Accept
        #expect(allowList.isAllowed(URL(string: "file:///foo/test.html")!))
        #expect(allowList.isAllowed(URL(string: "file:///foo/bar/index.html")!))
        #expect(allowList.isAllowed(URL(string: "file:///foo/bar.html")!))
    }

    @Test
    func testURLPaths() {
        allowList.addEntry("*://*.urbanairship.com/accept.html")
        allowList.addEntry("*://*.urbanairship.com/anythingHTML/*.html")
        allowList.addEntry("https://urbanairship.com/what/index.html")
        allowList.addEntry("wild://cool/*")

        // Reject
        #expect(!(allowList.isAllowed(URL(string: "https://what.urbanairship.com/reject.html")!)))
        #expect(!(allowList.isAllowed(URL(string: "https://what.urbanairship.com/anythingHTML/image.png")!)))
        #expect(!(allowList.isAllowed(URL(string: "https://what.urbanairship.com/anythingHTML/image.png")!)))
        #expect(!(allowList.isAllowed(URL(string: "wile:///whatever")!)))
        #expect(!(allowList.isAllowed(URL(string: "wile:///cool")!)))

        // Accept
        #expect(allowList.isAllowed(URL(string: "https://what.urbanairship.com/anythingHTML/index.html")!))
        #expect(allowList.isAllowed(URL(string: "https://what.urbanairship.com/anythingHTML/test.html")!))
        #expect(allowList.isAllowed(URL(string: "https://what.urbanairship.com/anythingHTML/foo/bar/index.html")!))
        #expect(allowList.isAllowed(URL(string: "https://urbanairship.com/what/index.html")!))
        #expect(allowList.isAllowed(URL(string: "wild://cool")!))
        #expect(allowList.isAllowed(URL(string: "wild://cool/")!))
        #expect(allowList.isAllowed(URL(string: "wild://cool/path")!))
    }

    @Test
    func testScope() {
        allowList.addEntry("*://*.urbanairship.com/accept-js.html", scope: .javaScriptInterface)
        allowList.addEntry("*://*.urbanairship.com/accept-url.html", scope: .openURL)
        allowList.addEntry("*://*.urbanairship.com/accept-all.html", scope: .all)

        #expect(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-js.html")!, scope: .javaScriptInterface))
        #expect(!(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-js.html")!, scope: .openURL)))
        #expect(!(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-js.html")!, scope: .all)))

        #expect(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-url.html")!, scope: .openURL))
        #expect(!(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-url.html")!, scope: .javaScriptInterface)))
        #expect(!(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-url.html")!, scope: .all)))

        #expect(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-all.html")!, scope: .all))
        #expect(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-all.html")!, scope: .javaScriptInterface))
        #expect(allowList.isAllowed(URL(string: "https://urbanairship.com/accept-all.html")!, scope: .openURL))
    }

    @Test
    func testDisableOpenURLScopeAllowList() {
        #expect(!(allowList.isAllowed(URL(string: "https://someurl.com")!, scope: .openURL)))

        allowList.addEntry("*", scope: .openURL)

        #expect(allowList.isAllowed(URL(string: "https://someurl.com")!, scope: .openURL))
        #expect(!(allowList.isAllowed(URL(string: "https://someurl.com")!, scope: .javaScriptInterface)))
        #expect(!(allowList.isAllowed(URL(string: "https://someurl.com")!, scope: .all)))
    }

    @Test
    func testAddAllScopesSeparately() {
        allowList.addEntry("*://*.urbanairship.com/all.html", scope: .openURL)
        allowList.addEntry("*://*.urbanairship.com/all.html", scope: .javaScriptInterface)

        #expect(allowList.isAllowed(URL(string: "https://urbanairship.com/all.html")!, scope: .all))
    }

    @Test
    func testAllScopeMatchesInnerScopes() {
        allowList.addEntry("*://*.urbanairship.com/all.html", scope: .all)

        #expect(allowList.isAllowed(URL(string: "https://urbanairship.com/all.html")!, scope: .javaScriptInterface))
        #expect(allowList.isAllowed(URL(string: "https://urbanairship.com/all.html")!, scope: .openURL))
    }

    @Test
    func testDeepLinks() {
        // Test any path and undefined host
        #expect(allowList.addEntry("com.urbanairship.one:/*"))
        #expect(allowList.isAllowed(URL(string: "com.urbanairship.one://cool")!))
        #expect(allowList.isAllowed(URL(string: "com.urbanairship.one:cool")!))
        #expect(allowList.isAllowed(URL(string: "com.urbanairship.one:/cool")!))
        #expect(allowList.isAllowed(URL(string: "com.urbanairship.one:///cool")!))

        // Test any host and undefined path
        #expect(allowList.addEntry("com.urbanairship.two://*"))
        #expect(allowList.isAllowed(URL(string: "com.urbanairship.two:cool")!))
        #expect(allowList.isAllowed(URL(string: "com.urbanairship.two://cool")!))
        #expect(allowList.isAllowed(URL(string: "com.urbanairship.two:/cool")!))
        #expect(allowList.isAllowed(URL(string: "com.urbanairship.two:///cool")!))

        // Test any host and any path
        #expect(allowList.addEntry("com.urbanairship.three://*/*"))
        #expect(allowList.isAllowed(URL(string: "com.urbanairship.three:cool")!))
        #expect(allowList.isAllowed(URL(string: "com.urbanairship.three://cool")!))
        #expect(allowList.isAllowed(URL(string: "com.urbanairship.three:/cool")!))
        #expect(allowList.isAllowed(URL(string: "com.urbanairship.three:///cool")!))

        // Test specific host and path
        #expect(allowList.addEntry("com.urbanairship.four://*.cool/whatever/*"))
        #expect(!(allowList.isAllowed(URL(string: "com.urbanairship.four:cool")!)))
        #expect(!(allowList.isAllowed(URL(string: "com.urbanairship.four://cool")!)))
        #expect(!(allowList.isAllowed(URL(string: "com.urbanairship.four:/cool")!)))
        #expect(!(allowList.isAllowed(URL(string: "com.urbanairship.four:///cool")!)))

        #expect(allowList.isAllowed(URL(string: "com.urbanairship.four://whatever.cool/whatever/")!))
        #expect(allowList.isAllowed(URL(string: "com.urbanairship.four://cool/whatever/indeed")!))
    }


    @Test
    func testRootPath() {
        #expect(allowList.addEntry("com.urbanairship.five:/"))

        #expect(allowList.isAllowed(URL(string: "com.urbanairship.five:/")!))
        #expect(allowList.isAllowed(URL(string: "com.urbanairship.five:///")!))

        #expect(!(allowList.isAllowed(URL(string: "com.urbanairship.five:/cool")!)))
    }

    @Test
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
        #expect(allowList.isAllowed(matchingURLToReject, scope: scope))
        #expect(allowList.isAllowed(matchingURLToAccept, scope: scope))
        #expect(!(allowList.isAllowed(nonMatchingURL, scope: scope)))

        // Enable URL allow list delegate
        let delegate = TestDelegate()
        delegate.onAllow = { url, scope in
            if (url == matchingURLToAccept) {
                return true
            }

            if (url == matchingURLToReject) {
                return false
            }

            Issue.record()
            return false
        }

        allowList.delegate = delegate

        // rejected URL should now fail URL allow list test, others should be unchanged
        #expect(!(allowList.isAllowed(matchingURLToReject, scope: scope)))
        #expect(allowList.isAllowed(matchingURLToAccept, scope: scope))
        #expect(!(allowList.isAllowed(nonMatchingURL, scope: scope)))

        // Disable URL allow list delegate
        allowList.delegate = nil

        // Should go back to original state when delegate was off
        #expect(allowList.isAllowed(matchingURLToReject, scope: scope))
        #expect(allowList.isAllowed(matchingURLToAccept, scope: scope))
        #expect(!(allowList.isAllowed(nonMatchingURL, scope: scope)))
    }

    @Test
    func testOnAllowBlock() {
        // set up a simple URL allow list
        allowList.addEntry("https://*.urbanairship.com")
        allowList.addEntry("https://*.youtube.com", scope: .openURL)

        // Matching URL to be checked
        let matchingURLToReject = URL(string: "https://www.youtube.com/watch?v=sYd_-pAfbBw")!
        let matchingURLToAccept = URL(string: "https://device-api.urbanairship.com/api/user")!
        let nonMatchingURL = URL(string: "https://maps.google.com")!

        let scope: URLAllowListScope = .openURL

        // Allow listing when delegate is off
        #expect(allowList.isAllowed(matchingURLToReject, scope: scope))
        #expect(allowList.isAllowed(matchingURLToAccept, scope: scope))
        #expect(!(allowList.isAllowed(nonMatchingURL, scope: scope)))

        // Delegate should be ignored
        let delegate = TestDelegate()
        delegate.onAllow = { url, scope in
            Issue.record()
            return false
        }

        allowList.delegate = delegate

        allowList.onAllowURL = { url, scope in
            if (url == matchingURLToAccept) {
                return true
            }

            if (url == matchingURLToReject) {
                return false
            }

            Issue.record()
            return false
        }


        // rejected URL should now fail URL allow list test, others should be unchanged
        #expect(!(allowList.isAllowed(matchingURLToReject, scope: scope)))
        #expect(allowList.isAllowed(matchingURLToAccept, scope: scope))
        #expect(!(allowList.isAllowed(nonMatchingURL, scope: scope)))

        // Disable URL allow list delegate
        allowList.delegate = nil
        allowList.onAllowURL = nil

        // Should go back to original state when delegate was off
        #expect(allowList.isAllowed(matchingURLToReject, scope: scope))
        #expect(allowList.isAllowed(matchingURLToAccept, scope: scope))
        #expect(!(allowList.isAllowed(nonMatchingURL, scope: scope)))
    }

    @Test
    func testSMSPath() {
        #expect(allowList.addEntry("sms:86753*9*"))

        #expect(!(allowList.isAllowed(URL(string: "sms:86753")!)))
        #expect(!(allowList.isAllowed(URL(string: "sms:867530")!)))

        #expect(allowList.isAllowed(URL(string: "sms:86753191")!))
        #expect(allowList.isAllowed(URL(string: "sms:8675309")!))
    }
}

fileprivate final class TestDelegate: URLAllowListDelegate, @unchecked Sendable {
    var allowURLCalled = false

    var onAllow: ((URL, URLAllowListScope) -> Bool)?

    func allowURL(_ url: URL, scope: URLAllowListScope) -> Bool {
        allowURLCalled = true
        return onAllow!(url, scope)
    }
}
